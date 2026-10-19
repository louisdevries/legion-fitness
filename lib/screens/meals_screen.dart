import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:legion_fitness/main.dart';
import '../models/food.dart';
import '../models/meal_log.dart';
import '../services/food_service.dart';
import '../services/nutrition_targets_service.dart';
import 'barcode_scan_screen.dart';
import 'custom_food_screen.dart';
import 'nutrition_targets_screen.dart';

const _mealLabels = {
  'breakfast': 'Breakfast',
  'lunch': 'Lunch',
  'dinner': 'Dinner',
  'snack': 'Snacks',
};

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class MealsScreen extends StatefulWidget {
  const MealsScreen({super.key});

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  DateTime _day = _today();
  List<MealLog> _logs = [];
  NutritionTargets? _targets;
  bool _isLoading = true;
  bool _offline = false;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _isToday => _day == _today();

  @override
  void initState() {
    super.initState();
    if (Supabase.instance.client.auth.currentUser != null) {
      _load();
      _loadTargets();
    }
  }

  /// Shows what's on the device straight away, then pulls from Supabase.
  Future<void> _load() async {
    final day = _day;
    await _readLocal(day);

    bool online;
    try {
      online = await FoodService.refreshDay(day);
    } catch (e) {
      debugPrint('Meal refresh failed: $e');
      online = true; // reached the server; it just errored
    }
    if (!mounted || day != _day) return;
    setState(() => _offline = !online);
    await _readLocal(day);
  }

  Future<void> _readLocal(DateTime day) async {
    final logs = await FoodService.getMealsForDay(day);
    if (!mounted || day != _day) return;
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  Future<void> _loadTargets() async {
    final targets = await NutritionTargetsService.getTargets();
    if (mounted) setState(() => _targets = targets);
  }

  Future<void> _editTargets() async {
    final targets = await Navigator.push<NutritionTargets>(
      context,
      MaterialPageRoute(
        builder: (_) => NutritionTargetsScreen(current: _targets),
      ),
    );
    if (targets != null && mounted) setState(() => _targets = targets);
  }

  void _changeDay(int delta) {
    final next = _day.add(Duration(days: delta));
    if (next.isAfter(_today())) return;
    setState(() {
      _day = next;
      _isLoading = true;
    });
    _load();
  }

  String get _dayLabel {
    if (_isToday) return 'Today';
    if (_day == _today().subtract(const Duration(days: 1))) return 'Yesterday';
    return '${_day.day} ${_monthNames[_day.month - 1]} ${_day.year}';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.danger),
    );
  }

  // ── Add / edit flow ─────────────────────────────────────────────

  Future<void> _addFood(String mealType) async {
    final choice = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddFoodSheet(),
    );
    if (!mounted || choice == null) return;

    Food? food;
    if (choice is Food) {
      food = choice;
    } else if (choice == _AddAction.scan) {
      food = await _scanFood();
    } else if (choice == _AddAction.custom) {
      food = await Navigator.push<Food>(
        context,
        MaterialPageRoute(builder: (_) => const CustomFoodScreen()),
      );
    }
    if (!mounted || food == null) return;

    // Online search results need a row in our foods table.
    if (food.id == null && (food.isFromOpenFoodFacts || food.isFromUsda)) {
      AppSettings.showLoading();
      try {
        food = await FoodService.ensureCached(food);
      } catch (e) {
        if (mounted) _showError('Could not add food: $e');
        return;
      } finally {
        AppSettings.hideLoading();
      }
      if (!mounted) return;
    }

    final result = await showDialog<_AmountResult>(
      context: context,
      builder: (_) => _AmountDialog(food: food!, mealType: mealType),
    );
    if (!mounted || result == null) return;

    // Past days get a midday timestamp so they land on the right date.
    final loggedAt = _isToday
        ? DateTime.now()
        : DateTime(_day.year, _day.month, _day.day, 12);

    await FoodService.logMeal(
      food: food,
      mealType: result.mealType,
      grams: result.grams,
      loggedAt: loggedAt,
    );
    await _readLocal(_day);
  }

  Future<void> _editLog(MealLog log) async {
    final result = await showDialog<_AmountResult>(
      context: context,
      builder: (_) => _AmountDialog(
        food: log.food,
        mealType: log.mealType,
        initialGrams: log.grams,
        editing: true,
      ),
    );
    if (!mounted || result == null) return;

    if (result.delete) {
      await _deleteLog(log);
    } else {
      await FoodService.updateMealLog(
        id: log.id,
        grams: result.grams,
        mealType: result.mealType,
      );
      await _readLocal(_day);
    }
  }

  Future<Food?> _scanFood() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (!mounted || code == null) return null;

    AppSettings.showLoading();
    Food? food;
    try {
      food = await FoodService.lookupBarcode(code);
    } catch (e) {
      debugPrint('Barcode lookup failed: $e');
    } finally {
      AppSettings.hideLoading();
    }
    if (!mounted) return null;
    if (food != null) return food;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Product not found — enter it from the label.'),
      ),
    );
    return Navigator.push<Food>(
      context,
      MaterialPageRoute(builder: (_) => CustomFoodScreen(barcode: code)),
    );
  }

  Future<void> _deleteLog(MealLog log) async {
    setState(() => _logs.remove(log));
    await FoodService.deleteMealLog(log.id);
  }

  // ── UI ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final signedIn = Supabase.instance.client.auth.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meals'),
        centerTitle: true,
        actions: [
          if (signedIn)
            IconButton(
              icon: const Icon(Icons.track_changes),
              tooltip: 'Daily targets',
              onPressed: _editTargets,
            ),
        ],
      ),
      body: !signedIn
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Sign up or log in to track your meals 🍽️',
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait([_load(), _loadTargets()]);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _buildDayBar(),
                  if (_offline) _buildOfflineBanner(),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    _buildSummaryCard(),
                    for (final type in MealLog.mealTypes) ...[
                      const SizedBox(height: 16),
                      _buildMealCard(type),
                    ],
                  ],
                  const SizedBox(height: 24),
                  _buildAttribution(),
                ],
              ),
            ),
    );
  }

  Widget _buildDayBar() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _changeDay(-1),
        ),
        Expanded(
          child: Text(
            _dayLabel,
            textAlign: TextAlign.center,
            style: appDisplay(context, 24),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _isToday ? null : () => _changeDay(1),
        ),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Text(
            'Offline — changes will sync when you reconnect',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(ThemeData theme) => BoxDecoration(
        color: AppColors.of(context).card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.of(context).cardBorder),
      );

  Widget _buildSummaryCard() {
    final theme = Theme.of(context);
    final targets = _targets;
    double kcal = 0, protein = 0, carbs = 0, fat = 0;
    for (final log in _logs) {
      kcal += log.kcal;
      protein += log.protein;
      carbs += log.carbs;
      fat += log.fat;
    }

    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    Widget macro(String label, double grams, int? target) => Expanded(
          child: Column(
            children: [
              Text(
                target == null
                    ? '${grams.round()} g'
                    : '${grams.round()} / $target g',
                style: appDisplay(context, 20),
              ),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 12, color: muted)),
              if (target != null && target > 0) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: AppProgressBar(grams / target, height: 4),
                ),
              ],
            ],
          ),
        );

    final String kcalCaption;
    if (targets == null) {
      kcalCaption = 'kcal eaten';
    } else {
      final left = targets.kcal - kcal.round();
      kcalCaption = left >= 0
          ? 'of ${targets.kcal} kcal · $left left'
          : 'of ${targets.kcal} kcal · ${-left} over';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(theme),
      child: Column(
        children: [
          Text(
            '${kcal.round()}',
            style: appDisplay(
              context,
              52,
              color: targets != null && kcal > targets.kcal
                  ? theme.colorScheme.error
                  : null,
            ),
          ),
          Text(kcalCaption, style: TextStyle(color: muted)),
          if (targets != null) ...[
            const SizedBox(height: 12),
            AppProgressBar(
              kcal / targets.kcal,
              height: 8,
              color: kcal > targets.kcal ? theme.colorScheme.error : null,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              macro('Protein', protein, targets?.proteinG),
              macro('Carbs', carbs, targets?.carbsG),
              macro('Fat', fat, targets?.fatG),
            ],
          ),
          if (targets == null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.track_changes, size: 18),
              label: const Text('Set daily targets'),
              onPressed: _editTargets,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMealCard(String type) {
    final theme = Theme.of(context);
    final logs = _logs.where((l) => l.mealType == type).toList();
    final kcal = logs.fold<double>(0, (sum, l) => sum + l.kcal);

    return Container(
      decoration: _cardDecoration(theme),
      child: Column(
        children: [
          ListTile(
            title: Text(_mealLabels[type]!, style: appDisplay(context, 22)),
            subtitle: logs.isEmpty ? null : Text('${kcal.round()} kcal'),
            trailing: IconButton(
              icon: Icon(Icons.add_circle,
                  color: AppColors.of(context).accentText, size: 30),
              tooltip: 'Add food',
              onPressed: () => _addFood(type),
            ),
          ),
          for (final log in logs)
            Dismissible(
              key: ValueKey(log.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                color: AppTheme.danger,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) => _deleteLog(log),
              child: ListTile(
                dense: true,
                onTap: () => _editLog(log),
                title: Text(log.food.name),
                subtitle: Text([
                  if (log.food.brand != null) log.food.brand!,
                  '${_formatGrams(log.grams)} g',
                ].join(' · ')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!log.synced) ...[
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text('${log.kcal.round()} kcal'),
                  ],
                ),
              ),
            ),
          if (logs.isNotEmpty) const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildAttribution() {
    final theme = Theme.of(context);
    return Text(
      'Product data from Open Food Facts (openfoodfacts.org), '
      'available under the Open Database License. Generic food data from '
      'USDA FoodData Central.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}

String _formatGrams(double g) =>
    g == g.roundToDouble() ? g.toInt().toString() : g.toStringAsFixed(1);

// ── Add food sheet ────────────────────────────────────────────────

enum _AddAction { scan, custom }

/// Pops with a [Food] picked from search/recent, or an [_AddAction].
class _AddFoodSheet extends StatefulWidget {
  const _AddFoodSheet();

  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Food> _recent = [];
  List<Food>? _results;
  bool _loading = true;

  // Online search (USDA + Open Food Facts) — only on an explicit tap, since
  // OFF allows ~10 searches/min.
  String? _onlineQuery;
  bool _onlineLoading = false;
  List<Food>? _usdaResults;
  List<Food>? _offResults;
  String? _usdaError;
  String? _offError;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    try {
      final recent = await FoodService.getRecentFoods();
      if (!mounted) return;
      setState(() {
        _recent = recent;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    setState(() {
      // A new query invalidates the previous online results.
      if (text.trim() != _onlineQuery) {
        _onlineQuery = null;
        _usdaResults = _offResults = null;
        _usdaError = _offError = null;
      }
      if (text.trim().isEmpty) _results = null;
    });
    if (text.trim().isEmpty) return;

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await FoodService.searchFoods(text);
        if (mounted && _search.text == text) {
          setState(() => _results = results);
        }
      } catch (_) {
        if (mounted) setState(() => _results = []);
      }
    });
  }

  Future<void> _searchOnline() async {
    final query = _search.text.trim();
    if (query.isEmpty || _onlineLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _onlineLoading = true;
      _onlineQuery = query;
      _usdaResults = _offResults = null;
      _usdaError = _offError = null;
    });

    const failed = 'Search failed. Check your connection and try again.';
    List<Food>? usda, off;
    String? usdaError, offError;
    await Future.wait([
      if (FoodService.isUsdaConfigured)
        () async {
          try {
            usda = await FoodService.searchUsda(query);
          } catch (_) {
            usdaError = failed;
          }
        }(),
      () async {
        try {
          off = await FoodService.searchOpenFoodFacts(query);
        } catch (_) {
          offError = failed;
        }
      }(),
    ]);

    if (!mounted || _search.text.trim() != query) return;
    setState(() {
      _onlineLoading = false;
      _usdaResults = usda;
      _offResults = off;
      _usdaError = usdaError;
      _offError = offError;
    });
  }

  List<Widget> _onlineSection(
    String title,
    String subtitle,
    List<Food>? results,
    String? error,
    Color muted,
    ThemeData theme,
  ) {
    return [
      const SizedBox(height: 16),
      Text(title, style: theme.textTheme.titleSmall),
      Text(subtitle, style: TextStyle(fontSize: 12, color: muted)),
      const SizedBox(height: 4),
      if (error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(error, style: TextStyle(color: theme.colorScheme.error)),
        )
      else if (results != null && results.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'No matches with nutrition data.',
            style: TextStyle(color: muted),
          ),
        )
      else if (results != null)
        for (final food in results) _foodTile(food),
    ];
  }

  Widget _foodTile(Food food) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(food.name),
        subtitle: food.brand == null ? null : Text(food.brand!),
        trailing: Text('${food.kcal100g.round()} kcal/100 g'),
        onTap: () => Navigator.pop(context, food),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final foods = _results ?? _recent;
    final searching = _search.text.trim().isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            16, 12, 16, 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan'),
                    onPressed: () => Navigator.pop(context, _AddAction.scan),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Enter manually'),
                    onPressed: () => Navigator.pop(context, _AddAction.custom),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchOnline(),
              decoration: const InputDecoration(
                hintText: 'Search foods',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              searching ? 'Your foods' : 'Recent',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            if (_loading || (searching && _results == null))
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (foods.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  searching
                      ? 'No saved foods match.'
                      : 'Foods you log will show up here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
              )
            else
              for (final food in foods) _foodTile(food),

            if (searching) ...[
              const SizedBox(height: 16),
              if (_onlineLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_onlineQuery == null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.public),
                  label: Text('Search online for "${_search.text.trim()}"'),
                  onPressed: _searchOnline,
                )
              else ...[
                if (FoodService.isUsdaConfigured)
                  ..._onlineSection(
                    'Generic foods',
                    'USDA FoodData Central',
                    _usdaResults,
                    _usdaError,
                    muted,
                    theme,
                  ),
                ..._onlineSection(
                  'Packaged products',
                  'Open Food Facts',
                  _offResults,
                  _offError,
                  muted,
                  theme,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ── Amount dialog ─────────────────────────────────────────────────

class _AmountResult {
  final double grams;
  final String mealType;
  final bool delete;
  const _AmountResult(this.grams, this.mealType, {this.delete = false});
}

class _AmountDialog extends StatefulWidget {
  final Food food;
  final String mealType;
  final double? initialGrams;
  final bool editing;

  const _AmountDialog({
    required this.food,
    required this.mealType,
    this.initialGrams,
    this.editing = false,
  });

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _grams;
  late String _mealType = widget.mealType;

  @override
  void initState() {
    super.initState();
    _grams = TextEditingController(
      text: _formatGrams(widget.initialGrams ?? widget.food.servingG ?? 100),
    );
  }

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  double? get _value {
    final g = double.tryParse(_grams.text.trim().replaceAll(',', '.'));
    return (g == null || g <= 0) ? null : g;
  }

  void _setGrams(double g) => setState(() => _grams.text = _formatGrams(g));

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final grams = _value;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return AlertDialog(
      title: Text(food.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (food.brand != null) Text(food.brand!),
            const SizedBox(height: 12),
            TextField(
              controller: _grams,
              autofocus: !widget.editing,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Amount',
                suffixText: 'g',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (food.servingG != null)
                  ActionChip(
                    label: Text(
                      '${food.servingLabel ?? '1 serving'} '
                      '(${_formatGrams(food.servingG!)} g)',
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _setGrams(food.servingG!),
                  ),
                ActionChip(
                  label: const Text('100 g'),
                  onPressed: () => _setGrams(100),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _mealType,
              decoration: const InputDecoration(
                labelText: 'Meal',
              ),
              items: [
                for (final type in MealLog.mealTypes)
                  DropdownMenuItem(value: type, child: Text(_mealLabels[type]!)),
              ],
              onChanged: (v) => setState(() => _mealType = v!),
            ),
            const SizedBox(height: 12),
            Text(
              grams == null ? '— kcal' : '${food.kcalFor(grams).round()} kcal',
              style: appDisplay(context, 28),
            ),
            if (food.isFromOpenFoodFacts || food.isFromUsda) ...[
              const SizedBox(height: 8),
              Text(
                food.isFromUsda
                    ? 'Data from USDA FoodData Central'
                    : 'Data from Open Food Facts',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.editing)
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              _AmountResult(0, _mealType, delete: true),
            ),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: grams == null
              ? null
              : () => Navigator.pop(context, _AmountResult(grams, _mealType)),
          child: Text(widget.editing ? 'Save' : 'Log'),
        ),
      ],
    );
  }
}
