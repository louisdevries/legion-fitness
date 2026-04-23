import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'exercise_runner_screen.dart';

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
    'warm-up': '🔥 Warm-Up',
    'main': '💪 Main Workout',
    'cool-down': '🧘 Cool-Down',
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
              restSeconds: widget.restSeconds,
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

    final String quantityLabel;
    if (durationType == 'until failure') {
      quantityLabel = '$sets sets × until failure';
    } else if (minQ == maxQ) {
      final unit = durationType.contains('second') ? 'sec' : 'reps';
      quantityLabel = '$sets sets × $minQ $unit';
    } else {
      final unit = durationType.contains('second') ? 'sec' : 'reps';
      quantityLabel = '$sets sets × $minQ–$maxQ $unit';
    }

    return Card(
      key: ValueKey(ex['id']),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

        leading: ex['media_url'] != null &&
            ex['media_url'].toString().isNotEmpty
            ? ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: ex['media_url'],
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          ),
        )
            : const SizedBox(
          width: 60,
          height: 60,
          child: Icon(Icons.fitness_center, size: 30),
        ),

        title: Text(ex['name'] ?? 'Exercise'),
        subtitle: Text(quantityLabel),

        trailing: GestureDetector(
          onLongPressStart: (_) {
            _isDragging = true;
          },
          onLongPressEnd: (_) {
            _isDragging = false;
          },
          child: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle, color: Colors.grey),
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
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            _categoryLabels[category]!,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
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
        appBar: AppBar(title: const Text("Get Ready")),
        body: Center(
          child: Text(
            "$countdown",
            style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Today's Exercises")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Drag to reorder within each section",
              style: TextStyle(color: Colors.grey),
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
              child: ElevatedButton(
                onPressed: startExerciseCountdown,
                child: const Text("Start Exercise"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}