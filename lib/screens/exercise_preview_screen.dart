import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'exercise_runner_screen.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../utils/exercise_category_utils.dart';
import '../widgets/app_ui.dart';

class ExercisePreviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> exercises;
  final int restSeconds;
  final int programId;
  final int weekNumber;
  final int dayNumber;

  const ExercisePreviewScreen({
    super.key,
    required this.exercises,
    required this.programId,
    required this.weekNumber,
    required this.dayNumber,
    this.restSeconds = 60,
  });

  @override
  State<ExercisePreviewScreen> createState() => _ExercisePreviewScreenState();
}

class _ExercisePreviewScreenState extends State<ExercisePreviewScreen> {
  bool isStarting = false;
  int countdown = 5;
  Timer? countdownTimer;
  bool _isDragging = false;

  late List<Map<String, dynamic>> _exercises;

  final ScrollController _scrollController = ScrollController();

  static const _categoryOrder = ['warm-up', 'main', 'cool-down'];

  static const _categoryLabels = {
    'warm-up': 'Warm-Up',
    'main': 'Main Workout',
    'cool-down': 'Cool-Down',
  };

  String get _storageKey =>
      'exercise_order_${widget.programId}_${widget.weekNumber}_${widget.dayNumber}';

  @override
  void initState() {
    super.initState();
    _exercises = List.from(widget.exercises);
    _loadOrder();
  }

  String _getCategory(Map<String, dynamic> ex) {
    final cat = ex['category_name'] as String?;
    if (cat != null) return cat.toLowerCase();

    final catId = ex['category_id'] as int?;
    if (catId == 1) return 'warm-up';
    if (catId == 2) return 'main';
    if (catId == 3) return 'cool-down';

    final sets = ex['sets'] as int? ?? 1;
    final durationType = (ex['duration_type'] as String? ?? '').toLowerCase();
    if (sets == 1 && durationType == 'seconds') return 'warm-up';

    return 'main';
  }

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = _exercises.map((e) => e['id'].toString()).toList();
    await prefs.setStringList(_storageKey, ids);
  }

  Future<void> _loadOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIds = prefs.getStringList(_storageKey);

    if (savedIds == null) return;

    final map = {
      for (var ex in widget.exercises) ex['id'].toString(): ex
    };

    final reordered = <Map<String, dynamic>>[];

    for (var id in savedIds) {
      if (map.containsKey(id)) reordered.add(map[id]!);
    }

    for (var ex in widget.exercises) {
      if (!reordered.contains(ex)) reordered.add(ex);
    }

    setState(() => _exercises = reordered);
  }

  void _autoScrollWhileDragging(PointerEvent event) {
    if (!_isDragging) return; // ✅ only when dragging

    const edgeThreshold = 60; // smaller zone
    const scrollAmount = 20.0;

    final position = _scrollController.position;
    final dy = event.position.dy;

    // top edge
    if (dy < edgeThreshold && position.pixels > 0) {
      _scrollController.animateTo(
        position.pixels - scrollAmount,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }

    // bottom edge
    else if (dy > position.viewportDimension - edgeThreshold &&
        position.pixels < position.maxScrollExtent) {
      _scrollController.animateTo(
        position.pixels + scrollAmount,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  void startExerciseCountdown() {
    setState(() => isStarting = true);
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown <= 1) {
        timer.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ExerciseRunnerScreen(
              exercises: _exercises,
              restSeconds: AppSettings.restTimerSeconds.value,
              programId: widget.programId,
              weekNumber: widget.weekNumber,
              dayNumber: widget.dayNumber,
            ),
          ),
        );
      } else {
        setState(() => countdown--);
      }
    });
  }

  Widget _buildExerciseTile(Map<String, dynamic> ex, int index) {
    final minQ = ex['min_quantity'] as int? ?? 0;
    final maxQ = ex['max_quantity'] as int? ?? minQ;
    final sets = ex['sets'] as int? ?? 1;
    final durationType =
    (ex['duration_type'] as String? ?? 'reps').toLowerCase();

    final isTimeUnit =
        durationType.contains('second') || durationType.contains('time_max');
    final String quantityLabel;
    if (durationType == 'until failure') {
      quantityLabel = '$sets sets × until failure';
    } else if (durationType.contains('time_max')) {
      // Count-up/open-ended holds have no real target — just the timer,
      // no min-max range.
      quantityLabel = '$sets sets × as long as possible';
    } else if (minQ == maxQ) {
      final unit = isTimeUnit ? 'sec' : 'reps';
      quantityLabel = '$sets sets × $minQ $unit';
    } else {
      final unit = isTimeUnit ? 'sec' : 'reps';
      quantityLabel = '$sets sets × $minQ–$maxQ $unit';
    }

    final c = AppColors.of(context);
    return Card(
      key: ValueKey(ex['id']),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

        leading: ex['media_url'] != null &&
            ex['media_url'].toString().isNotEmpty
            ? ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: ex['media_url'],
            width: 56,
            height: 56,
            fit: BoxFit.cover,
          ),
        )
            : const AppIconBadge(Icons.fitness_center, size: 56),

        title: Text(ex['name'] ?? 'Exercise',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: (ex['tempo'] != null && (ex['tempo'] as String).isNotEmpty)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(quantityLabel),
                  Text(
                    'Tempo: ${ex['tempo']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              )
            : Text(quantityLabel),

        trailing: GestureDetector(
          onLongPressStart: (_) {
            _isDragging = true;
          },
          onLongPressEnd: (_) {
            _isDragging = false;
          },
          child: ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_handle, color: c.muted),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(String category) {
    final exercises = _exercises
        .where((ex) => _getCategory(ex) == category)
        .toList();

    if (exercises.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: ExerciseCategoryUtils.getColor(category),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(_categoryLabels[category]!, style: appDisplay(context, 22)),
            ],
          ),
        ),

        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),

          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final t = Curves.easeOutCubic.transform(animation.value);

                return Transform.scale(
                  scale: 1.0 + (0.07 * t),
                  child: Material(
                    elevation: 12 * t,
                    borderRadius: BorderRadius.circular(12),
                    child: child,
                  ),
                );
              },
              child: child,
            );
          },

          itemCount: exercises.length,
          itemBuilder: (context, index) {
            final ex = exercises[index];
            return _buildExerciseTile(ex, index);
          },

          onReorder: (oldIndex, newIndex) {
            HapticFeedback.mediumImpact();

            setState(() {
              if (newIndex > oldIndex) newIndex--;

              final movedItem = exercises.removeAt(oldIndex);
              exercises.insert(newIndex, movedItem);

              final others = _exercises
                  .where((ex) => _getCategory(ex) != category)
                  .toList();

              _exercises = [
                ..._categoryOrder.expand((cat) {
                  if (cat == category) return exercises;
                  return others.where((ex) => _getCategory(ex) == cat);
                })
              ];
            });

            _saveOrder();
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isStarting) {
      return Scaffold(
        appBar: AppBar(title: const Text("Get ready")),
        body: Center(
          child: Container(
            width: 200,
            height: 200,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.of(context).accent,
              shape: BoxShape.circle,
            ),
            child: Text(
              "$countdown",
              style: appDisplay(context, 110,
                  color: AppColors.of(context).onAccent),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Today's exercises")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Hold and drag to reorder within each section",
              style: TextStyle(color: AppColors.of(context).muted),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: Listener(
                onPointerMove: _autoScrollWhileDragging,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    children: _categoryOrder
                        .map((cat) => _buildCategorySection(cat))
                        .toList(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56)),
                onPressed: startExerciseCountdown,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text("Start workout"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}