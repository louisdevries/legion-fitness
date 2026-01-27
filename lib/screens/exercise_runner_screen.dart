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

  int lastSelectedReps = 1;

  late final AudioPlayer tickPlayer;
  late final AudioPlayer dingPlayer;

  late List<Map<String, dynamic>> exercises;

  Map<String, dynamic> get currentExercise => exercises[currentIndex];

  int get totalSets => currentExercise['sets'] as int? ?? 1;

  bool get isLastSet => currentSet >= totalSets;
  bool get isLastExercise => currentIndex >= exercises.length - 1;

  Map<String, dynamic>? get previewExercise {
    if (!isLastSet) {
      // Preview is next set of same exercise
      return currentExercise;
    } else if (!isLastExercise) {
      // Preview is next exercise
      return exercises[currentIndex + 1];
    }
    return null;
  }

  String get previewLabel {
    if (!isLastSet) {
      return "Next: ${currentExercise['name']} (Set ${currentSet + 1}/$totalSets)";
    } else if (!isLastExercise) {
      return "Next: ${exercises[currentIndex + 1]['name']}";
    }
    return "Workout complete";
  }

  @override
  void initState() {
    super.initState();

    exercises = widget.exercises.map((e) {
      return {
        ...e,
        'exercise_id': e['id'],
        'program_id': widget.programId,
        'week_number': widget.weekNumber,
        'day_number': widget.dayNumber,
      };
    }).toList();

    tickPlayer = AudioPlayer();
    dingPlayer = AudioPlayer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      startCurrentExercise();
    });
  }

  int getQuantity() {
    final minQ = currentExercise['min_quantity'] as int? ?? 0;
    final maxQ = currentExercise['max_quantity'] as int? ?? minQ;
    if (minQ == 0 && maxQ == 0) return 1;
    return ((minQ + maxQ) / 2).round();
  }

  bool isTimedExercise() {
    final t = (currentExercise['duration_type'] ?? '').toString().toLowerCase();
    return t.contains('sec');
  }

  bool isSuperset() => currentExercise['is_superset'] == true;

  Future<void> startCurrentExercise() async {
    exerciseTimer?.cancel();
    isResting = false;
    isPaused = false;
    mediaReady = false;
    setState(() {});

    final url = currentExercise['media_url'];
    if (url != null && url.toString().isNotEmpty) {
      try {
        await precacheImage(CachedNetworkImageProvider(url), context);
      } catch (_) {}
    }

    mediaReady = true;
    setState(() {});

    // Set reps/seconds for exercise
    lastSelectedReps = getQuantity();
    int seconds = isTimedExercise() ? max(1, getQuantity()) : 0;
    totalSeconds = seconds;
    remainingSeconds = seconds;

    if (isTimedExercise()) {
      exerciseTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (isPaused) return;

        if (remainingSeconds <= 1) {
          t.cancel();
          await dingPlayer.play(AssetSource('sounds/ding.wav'));
          await completeExerciseSet(logSet: true);
        } else {
          setState(() => remainingSeconds--);
          if (remainingSeconds <= 5) {
            await tickPlayer.play(AssetSource('sounds/tick.wav'));
          }
        }
      });
    }
  }

  Future<void> logSetToDatabase() async {
    final ex = currentExercise;
    await ProgressService.logExercise(
      programId: ex['program_id'],
      exerciseId: ex['exercise_id'],
      weekNumber: ex['week_number'],
      dayNumber: ex['day_number'],
      repsCompleted: lastSelectedReps,
      weightUsedKg: ex['weight_used_kg'] != null
          ? (ex['weight_used_kg'] as num).toDouble()
          : null,
    );
  }

  Future<void> completeExerciseSet({required bool logSet}) async {
    exerciseTimer?.cancel();

    // Only log if logSet = true
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
                const Text("How many reps did you do?", style: TextStyle(fontSize: 18)),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 40,
                    scrollController: FixedExtentScrollController(
                      initialItem: max(0, selectedReps - 1),
                    ),
                    onSelectedItemChanged: (v) {
                      selectedReps = v + 1;
                    },
                    children: List.generate(
                      max(1, (currentExercise['max_quantity'] ?? 20) + 20),
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
      }

      if (lastSelectedReps < 1) lastSelectedReps = getQuantity();
      await logSetToDatabase();
    }

    // Determine next set/exercise
    if (!isLastSet) {
      // Next set of same exercise → start rest
      startRest(nextExerciseIndex: currentIndex, nextSet: currentSet + 1);
    } else if (!isLastExercise) {
      // Last set of exercise → start rest before next exercise
      startRest(nextExerciseIndex: currentIndex + 1, nextSet: 1);
    } else if (logSet) {
      await showWorkoutComplete();
    }
  }

  void startRest({required int nextExerciseIndex, required int nextSet}) {
    exerciseTimer?.cancel();
    isResting = true;
    isPaused = false;
    remainingSeconds = widget.restSeconds;
    totalSeconds = widget.restSeconds;
    setState(() {});

    exerciseTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (isPaused) return;

      if (remainingSeconds <= 1) {
        t.cancel();
        await dingPlayer.play(AssetSource('sounds/ding.wav'));
        currentIndex = nextExerciseIndex;
        currentSet = nextSet;
        startCurrentExercise();
      } else {
        setState(() => remainingSeconds--);
      }
    });
  }

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
              Navigator.pop(context); // dialog
              Navigator.pop(context); // screen
            },
            child: const Text("Finish"),
          ),
        ],
      ),
    );
  }

  void togglePause() => setState(() => isPaused = !isPaused);

  void addSeconds(int s) {
    setState(() {
      remainingSeconds += s;
      totalSeconds += s;
    });
  }

  @override
  void dispose() {
    exerciseTimer?.cancel();
    tickPlayer.dispose();
    dingPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ex = currentExercise;
    final isTimed = isTimedExercise();

    final progress = totalSeconds == 0
        ? 0.0
        : (remainingSeconds / totalSeconds).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(isResting ? "Rest" : ex['name'] ?? 'Exercise'),
        backgroundColor: isResting ? Colors.green : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(previewLabel,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            !isResting
                ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: mediaReady
                  ? CachedNetworkImage(
                imageUrl: ex['media_url'],
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              )
                  : const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              ),
            )
                : Column(
              children: [
                const SizedBox(height: 20),
                const Text("REST",
                    style: TextStyle(
                        fontSize: 48, fontWeight: FontWeight.bold)),
                if (previewExercise != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: previewExercise!['media_url'],
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text("Set $currentSet / $totalSets",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
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
                    Text(
                      isTimed || isResting
                          ? "$remainingSeconds"
                          : "$lastSelectedReps reps",
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: togglePause,
                  child: Text(isPaused ? "Resume" : "Pause"),
                ),
                if (isTimed && !isResting)
                  ElevatedButton(
                    onPressed: () => completeExerciseSet(logSet: true),
                    child: const Text("Skip"),
                  ),
                if (isResting)
                  ElevatedButton(
                    onPressed: () {
                      exerciseTimer?.cancel();
                      // Skip rest → move to next set/exercise immediately
                      int nextIndex = currentIndex;
                      int nextSet = currentSet;
                      if (!isLastSet) {
                        nextSet = currentSet + 1;
                      } else if (!isLastExercise) {
                        nextIndex = currentIndex + 1;
                        nextSet = 1;
                      }
                      currentIndex = nextIndex;
                      currentSet = nextSet;
                      startCurrentExercise();
                    },
                    child: const Text("Skip Rest"),
                  ),
                if (isResting)
                  ElevatedButton(
                    onPressed: () => addSeconds(10),
                    child: const Text("+10s"),
                  ),
                if (!isTimed && !isResting)
                  ElevatedButton(
                    onPressed: () => completeExerciseSet(logSet: true),
                    child: const Text("Finish Set"),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
