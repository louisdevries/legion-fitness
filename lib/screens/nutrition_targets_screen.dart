import 'package:flutter/material.dart';
import '../services/nutrition_targets_service.dart';
import 'health_profile_screen.dart';

/// Set daily calorie and macro targets, by hand or calculated from the
/// health profile. Pops with the saved [NutritionTargets].
class NutritionTargetsScreen extends StatefulWidget {
  final NutritionTargets? current;
  const NutritionTargetsScreen({super.key, this.current});

  @override
  State<NutritionTargetsScreen> createState() => _NutritionTargetsScreenState();
}

class _NutritionTargetsScreenState extends State<NutritionTargetsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _kcal = TextEditingController(text: widget.current?.kcal.toString());
  late final _protein =
      TextEditingController(text: widget.current?.proteinG?.toString());
  late final _carbs =
      TextEditingController(text: widget.current?.carbsG?.toString());
  late final _fat = TextEditingController(text: widget.current?.fatG?.toString());

  BodyStats? _stats;
  bool _statsLoading = true;
  Sex? _sex;
  ActivityLevel _activity = ActivityLevel.moderate;
  Goal _goal = Goal.maintain;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    for (final c in [_kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    BodyStats? stats;
    try {
      stats = await NutritionTargetsService.getBodyStats();
    } catch (_) {
      // Offline — the calculator just stays unavailable.
    }
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _statsLoading = false;
    });
  }

  void _calculate() {
    final targets = NutritionTargetsService.calculate(
      stats: _stats!,
      sex: _sex!,
      activity: _activity,
      goal: _goal,
    );
    setState(() {
      _kcal.text = targets.kcal.toString();
      _protein.text = targets.proteinG.toString();
      _carbs.text = targets.carbsG.toString();
      _fat.text = targets.fatG.toString();
    });
  }

  int? _parse(String text) => int.tryParse(text.trim());

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final targets = NutritionTargets(
      kcal: _parse(_kcal.text)!,
      proteinG: _parse(_protein.text),
      carbsG: _parse(_carbs.text),
      fatG: _parse(_fat.text),
    );
    try {
      await NutritionTargetsService.saveTargets(targets);
      if (!mounted) return;
      Navigator.pop(context, targets);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save targets: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _numberField(
    TextEditingController c,
    String label,
    String suffix, {
    bool required = false,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return required ? 'Required' : null;
        final n = _parse(v);
        if (n == null) return 'Whole number';
        if (required ? n <= 0 : n < 0) return 'Too low';
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Targets'), centerTitle: true),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _numberField(_kcal, 'Calories', 'kcal', required: true),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _numberField(_protein, 'Protein', 'g')),
                const SizedBox(width: 12),
                Expanded(child: _numberField(_carbs, 'Carbs', 'g')),
                const SizedBox(width: 12),
                Expanded(child: _numberField(_fat, 'Fat', 'g')),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Targets'),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            Text('Calculate for me', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Uses your health profile and latest weight. An estimate — '
              'adjust it based on how your weight actually changes.',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            _buildCalculator(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculator(ThemeData theme) {
    if (_statsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = _stats;
    if (stats == null) {
      return const Text('Connect to the internet to use the calculator.');
    }

    if (!stats.isComplete) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add your date of birth, height and weight to your health '
            'profile first.',
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HealthProfileScreen()),
              );
              _loadStats();
            },
            child: const Text('Open Health Profile'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${stats.age} years · ${stats.heightCm!.round()} cm · '
          '${stats.weightKg!.toStringAsFixed(1)} kg',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Sex (for the BMR formula)'),
        const SizedBox(height: 8),
        SegmentedButton<Sex>(
          segments: const [
            ButtonSegment(value: Sex.male, label: Text('Male')),
            ButtonSegment(value: Sex.female, label: Text('Female')),
          ],
          selected: {?_sex},
          emptySelectionAllowed: true,
          onSelectionChanged: (s) =>
              setState(() => _sex = s.isEmpty ? null : s.first),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<ActivityLevel>(
          initialValue: _activity,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Activity level',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final a in ActivityLevel.values)
              DropdownMenuItem(
                value: a,
                child: Text('${a.label} — ${a.description}',
                    overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (a) => setState(() => _activity = a!),
        ),
        const SizedBox(height: 16),
        SegmentedButton<Goal>(
          segments: [
            for (final g in Goal.values)
              ButtonSegment(value: g, label: Text(g.label)),
          ],
          selected: {_goal},
          onSelectionChanged: (s) => setState(() => _goal = s.first),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.calculate),
          label: const Text('Calculate'),
          onPressed: _sex == null ? null : _calculate,
        ),
      ],
    );
  }
}
