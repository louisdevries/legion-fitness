import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import '../services/progress_service.dart';

class ExerciseRunnerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> exercises;
  final int restSeconds;
  final int programId;
  final int weekNumber;
  final int dayNumber;

  const ExerciseRunnerScreen({
    super.key,
    required this.exercises,
    required this.programId,
    required this.weekNumber,
    required this.dayNumber,
    this.restSeconds = 60,
  });

  @override
  State<ExerciseRunnerScreen> createState() => _ExerciseRunnerScreenState();
}

class _ExerciseRunnerScreenState extends State<ExerciseRunnerScreen> {
  int currentIndex = 0;
  int currentSet = 1;

  Timer? exerciseTimer;
  int remainingSeconds = 0;
  int totalSeconds = 1;

  bool isPaused = false;
  bool isResting = false;
  bool mediaReady = false;
  bool showCategoryHeader = false;
  bool usingAlternative = false;

  int lastSelectedReps = 1;
  int lastSelectedSeconds = 0;

  late final AudioPlayer tickPlayer;
  late final AudioPlayer dingPlayer;

  late List<Map<String, dynamic>> exercises;

  Map<String, dynamic> get currentExercise => exercises[currentIndex];
  Map<String, dynamic>? get currentAlternative => currentExercise['alternative'] as Map<String, dynamic>?;

  int get totalSets => currentExercise['sets'] as int? ?? 1;

  bool get isLastSet => currentSet >= totalSets;
  bool get isLastExercise => currentIndex >= exercises.length - 1;

  @override
  void initState() {
    super.initState();

    exercises = widget.exercises.map((e) {
      return {
        ...e,
        'exercise_id': e['exercise_id'] ?? e['id'],
        'program_id': widget.programId,
        'week_number': widget.weekNumber,
        'day_number': widget.dayNumber,
      };
    }).toList();

    tickPlayer = AudioPlayer();
    dingPlayer = AudioPlayer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowCategoryHeader();
    });
  }

  // ------------------ CATEGORY HEADER ------------------

  void _checkAndShowCategoryHeader() {
    final currentCategory = currentExercise['category'] as String? ?? 'main';

    // Check if this is the first exercise in this category
    bool isFirstInCategory = true;
    if (currentIndex > 0) {
      final previousCategory = exercises[currentIndex - 1]['category'] as String? ?? 'main';
      isFirstInCategory = currentCategory != previousCategory;
    }

    if (isFirstInCategory) {
      setState(() => showCategoryHeader = true);

      // Show category header dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: Text(_getCategoryTitle(currentCategory)),
          content: Text(_getCategoryDescription(currentCategory)),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => showCategoryHeader = false);
                startCurrentExercise();
              },
              child: const Text("Start"),
            ),
          ],
        ),
      );
    } else {
      startCurrentExercise();
    }
  }

  String _getCategoryTitle(String category) {
    switch (category.toLowerCase()) {
      case 'warmup':
        return '🔥 Warm-up';
      case 'cooldown':
        return '❄️ Cool-down';
      case 'main':
      default:
        return '💪 Main Workout';
    }
  }

  String _getCategoryDescription(String category) {
    switch (category.toLowerCase()) {
      case 'warmup':
        return 'Prepare your body for the workout ahead';
      case 'cooldown':
        return 'Wind down and stretch to aid recovery';
      case 'main':
      default:
        return 'Time to work! Give it your all';
    }
  }

  // ------------------ HELPERS ------------------

  int getMinQuantity() {
    final ex = usingAlternative && currentAlternative != null ? currentAlternative! : currentExercise;
    return ex['min_quantity'] as int? ?? 0;
  }

  int getMaxQuantity() {
    final ex = usingAlternative && currentAlternative != null ? currentAlternative! : currentExercise;
    return ex['max_quantity'] as int? ?? getMinQuantity();
  }

  int getQuantity() {
    final minQ = getMinQuantity();
    final maxQ = getMaxQuantity();
    return max(1, ((minQ + maxQ) / 2).round());
  }

  String getQuantityDisplay() {
    final minQ = getMinQuantity();
    final maxQ = getMaxQuantity();

    if (minQ == maxQ) {
      return '$minQ';
    } else {
      return '$minQ-$maxQ';
    }
  }

  bool isTimedExercise() {
    final ex = usingAlternative && currentAlternative != null ? currentAlternative! : currentExercise;
    final t = (ex['duration_type'] ?? '').toString().toLowerCase();
    return t.contains('sec');
  }

  String getCurrentExerciseName() {
    final ex = usingAlternative && currentAlternative != null ? currentAlternative! : currentExercise;
    return ex['name'] as String? ?? 'Exercise';
  }

  String? getCurrentMediaUrl() {
    final ex = usingAlternative && currentAlternative != null ? currentAlternative! : currentExercise;
    return ex['media_url'] as String?;
  }

  String getCurrentCoachingCues() {
    final ex = usingAlternative && currentAlternative != null ? currentAlternative! : currentExercise;
    return ex['coaching_cues'] as String? ?? '';
  }

  // ------------------ EXERCISE START ------------------

  Future<void> startCurrentExercise() async {
    exerciseTimer?.cancel();
    isResting = false;
    isPaused = false;
    mediaReady = false;
    if (mounted) setState(() {});

    final url = getCurrentMediaUrl();
    if (url != null && url.isNotEmpty) {
      try {
        await precacheImage(CachedNetworkImageProvider(url), context);
      } catch (_) {}
    }

    mediaReady = true;

    if (isTimedExercise()) {
      lastSelectedSeconds = getQuantity();
      totalSeconds = lastSelectedSeconds;
      remainingSeconds = lastSelectedSeconds;
    } else {
      lastSelectedReps = getQuantity();
      totalSeconds = 0;
      remainingSeconds = 0;
    }

    if (mounted) setState(() {});

    if (isTimedExercise()) {
      exerciseTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (!mounted) {
          t.cancel();
          return;
        }

        if (isPaused) return;

        if (remainingSeconds <= 1) {
          t.cancel();
          await dingPlayer.play(AssetSource('sounds/ding.wav'));
          await completeExerciseSet(logSet: true);
        } else {
          if (mounted) setState(() => remainingSeconds--);
          if (remainingSeconds <= 5) {
            await tickPlayer.play(AssetSource('sounds/tick.wav'));
          }
        }
      });
    }
  }

  // ------------------ LOGGING ------------------

  Future<void> logSetToDatabase() async {
    final ex = currentExercise;

    await ProgressService.logExercise(
      programId: ex['program_id'],
      exerciseId: ex['exercise_id'],
      weekNumber: ex['week_number'],
      dayNumber: ex['day_number'],
      repsCompleted: isTimedExercise() ? lastSelectedSeconds : lastSelectedReps,
      weightUsedKg: ex['weight_used_kg'] != null
          ? (ex['weight_used_kg'] as num).toDouble()
          : null,
    );
  }

  // ------------------ COMPLETE SET ------------------

  Future<void> completeExerciseSet({required bool logSet}) async {
    exerciseTimer?.cancel();

    if (logSet) {
      if (!isTimedExercise()) {
        int selectedReps = lastSelectedReps;
        await showModalBottomSheet(
          context: context,
          isDismissible: false,
          builder: (_) => SizedBox(
            height: 320,
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Text("How many reps did you do?",
                    style: TextStyle(fontSize: 18)),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 40,
                    scrollController: FixedExtentScrollController(
                      initialItem: selectedReps - 1,
                    ),
                    onSelectedItemChanged: (v) => selectedReps = v + 1,
                    children: List.generate(
                      50,
                          (i) => Center(child: Text("${i + 1}")),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Confirm"),
                ),
              ],
            ),
          ),
        );
        lastSelectedReps = selectedReps;
      } else {
        lastSelectedSeconds = totalSeconds;
      }

      await logSetToDatabase();
    }

    if (!isLastSet) {
      startRest(nextExerciseIndex: currentIndex, nextSet: currentSet + 1);
    } else if (!isLastExercise) {
      // Reset to main exercise for next exercise
      usingAlternative = false;
      startRest(nextExerciseIndex: currentIndex + 1, nextSet: 1);
    } else {
      await showWorkoutComplete();
    }
  }

  // ------------------ REST ------------------

  void startRest({required int nextExerciseIndex, required int nextSet}) {
    exerciseTimer?.cancel();
    isResting = true;
    remainingSeconds = widget.restSeconds;
    totalSeconds = widget.restSeconds;
    if (mounted) setState(() {});

    exerciseTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }

      if (remainingSeconds <= 1) {
        t.cancel();
        _proceedToNextExercise(nextExerciseIndex, nextSet);
      } else {
        if (mounted) setState(() => remainingSeconds--);
      }
    });
  }

  void skipRest() {
    exerciseTimer?.cancel();
    final nextIndex = currentIndex;
    final nextSet = currentSet;

    // Determine what's next
    if (!isLastSet) {
      _proceedToNextExercise(currentIndex, currentSet + 1);
    } else if (!isLastExercise) {
      _proceedToNextExercise(currentIndex + 1, 1);
    }
  }

  void _proceedToNextExercise(int nextExerciseIndex, int nextSet) {
    currentIndex = nextExerciseIndex;
    currentSet = nextSet;

    // Reset to main exercise for new exercise
    if (nextSet == 1) {
      usingAlternative = false;
    }

    // Check if we need to show category header
    if (nextSet == 1) {
      _checkAndShowCategoryHeader();
    } else {
      startCurrentExercise();
    }
  }

  // ------------------ SWITCH TO ALTERNATIVE ------------------

  void switchToAlternative() {
    if (currentAlternative == null) return;

    setState(() {
      usingAlternative = !usingAlternative;
    });

    // Restart the current set with the alternative exercise
    startCurrentExercise();
  }

  // ------------------ TIMER ADJUST ------------------

  void adjustTimer(int delta) {
    setState(() {
      totalSeconds = max(5, totalSeconds + delta);
      remainingSeconds = min(remainingSeconds + delta, totalSeconds);
      lastSelectedSeconds = totalSeconds;
    });
  }

  // ------------------ COMPLETE ------------------

  Future<void> showWorkoutComplete() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Workout Complete 💪"),
        content: const Text("Great job! Your workout has been logged."),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Finish"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    exerciseTimer?.cancel();
    tickPlayer.dispose();
    dingPlayer.dispose();
    super.dispose();
  }

  // ------------------ UI ------------------

  @override
  Widget build(BuildContext context) {
    final isTimed = isTimedExercise();
    final exerciseName = getCurrentExerciseName();
    final coachingCues = getCurrentCoachingCues();
    final hasAlternative = currentAlternative != null;

    final progress = totalSeconds == 0
        ? 0.0
        : (remainingSeconds / totalSeconds).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(isResting ? "Rest" : exerciseName),
        backgroundColor: isResting ? Colors.green : null,
        actions: [
          if (!isResting && hasAlternative)
            IconButton(
              icon: Icon(usingAlternative ? Icons.swap_horiz : Icons.sync_alt),
              tooltip: usingAlternative ? 'Switch to main' : 'Try easier version',
              onPressed: switchToAlternative,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Category badge
            if (!isResting)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getCategoryColor(currentExercise['category'] as String? ?? 'main'),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getCategoryTitle(currentExercise['category'] as String? ?? 'main'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Set $currentSet / $totalSets",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (usingAlternative)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Easier Version",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // MEDIA
            !isResting
                ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: mediaReady && getCurrentMediaUrl() != null
                  ? CachedNetworkImage(
                imageUrl: getCurrentMediaUrl()!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              )
                  : const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              ),
            )
                : const Text(
              "REST",
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            // Coaching Cues
            if (!isResting && coachingCues.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        coachingCues,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // TIMER / REPS RING
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 14,
                        valueColor: AlwaysStoppedAnimation(Colors.grey.shade300),
                      ),
                    ),
                    if (isTimed || isResting)
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 14,
                        ),
                      ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isTimed || isResting
                              ? "$remainingSeconds"
                              : getQuantityDisplay(),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isTimed || isResting ? "seconds" : "reps",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (isTimed && !isResting)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => adjustTimer(-5),
                    child: const Text("-5s"),
                  ),
                  ElevatedButton(
                    onPressed: () => adjustTimer(5),
                    child: const Text("+5s"),
                  ),
                ],
              ),

            const SizedBox(height: 12),

            if (isResting)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: skipRest,
                    icon: const Icon(Icons.skip_next),
                    label: const Text("Skip Rest"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              )
            else
              ElevatedButton(
                onPressed: () => completeExerciseSet(logSet: true),
                child: const Text("Finish Set"),
              ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'warmup':
        return Colors.orange;
      case 'cooldown':
        return Colors.blue;
      case 'main':
      default:
        return Colors.green;
    }
  }
}