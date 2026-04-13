import 'dart:async';
import 'package:flutter/material.dart';
import 'exercise_runner_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

  // =====================================================
  // Category detection based on duration_type + sets
  // Warm-ups:  1 set, no specific sets value / category_id
  // We rely on the category_id field if present, otherwise
  // fall back to name-based heuristics.
  // =====================================================
  String _getCategory(Map<String, dynamic> ex) {
    // If the service already joins category name, use it directly
    final cat = ex['category_name'] as String?;
    if (cat != null) return cat.toLowerCase();

    // Fall back to category_id if present
    final catId = ex['category_id'] as int?;
    if (catId == 1) return 'warm-up';
    if (catId == 2) return 'main';
    if (catId == 3) return 'cool-down';

    // Last resort: heuristic — 1 set with no coaching cues tends to be
    // warm-up/cooldown; use sets count as a rough signal
    final sets = ex['sets'] as int? ?? 1;
    final durationType = (ex['duration_type'] as String? ?? '').toLowerCase();
    if (sets == 1 && durationType == 'seconds') return 'warm-up';

    return 'main';
  }

  static const _categoryOrder = ['warm-up', 'main', 'cool-down'];

  static const _categoryLabels = {
    'warm-up': '🔥 Warm-Up',
    'main': '💪 Main Workout',
    'cool-down': '🧘 Cool-Down',
  };

  /// Builds a list of section headers + exercise items in order.
  /// Returns a flat list where each entry is either:
  ///   { 'type': 'header', 'label': String }
  ///   { 'type': 'exercise', 'data': Map }
  List<Map<String, dynamic>> _buildSections() {
    // Group exercises by category
    final Map<String, List<Map<String, dynamic>>> grouped = {
      'warm-up': [],
      'main': [],
      'cool-down': [],
    };

    for (final ex in widget.exercises) {
      final cat = _getCategory(ex);
      if (grouped.containsKey(cat)) {
        grouped[cat]!.add(ex);
      } else {
        grouped['main']!.add(ex);
      }
    }

    final List<Map<String, dynamic>> sections = [];

    for (final category in _categoryOrder) {
      final exercises = grouped[category]!;
      if (exercises.isEmpty) continue;

      sections.add({
        'type': 'header',
        'label': _categoryLabels[category]!,
      });

      for (final ex in exercises) {
        sections.add({'type': 'exercise', 'data': ex});
      }
    }

    return sections;
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
              exercises: widget.exercises,
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

  @override
  void dispose() {
    countdownTimer?.cancel();
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

    final sections = _buildSections();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Today's Exercises")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: sections.length,
                itemBuilder: (context, index) {
                  final section = sections[index];

                  // ── Section header ──
                  if (section['type'] == 'header') {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(
                        section['label'] as String,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    );
                  }

                  // ── Exercise card ──
                  final ex = section['data'] as Map<String, dynamic>;
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
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
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
                    ),
                  );
                },
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