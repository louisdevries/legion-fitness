import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import '../services/progress_service.dart';

// MOCK: Fetch exercises from DB or API
class ExerciseService {
  static Future<List<Map<String, dynamic>>> fetchExercises({
    required int programId,
    required int weekNumber,
    required int dayNumber,
  }) async {
    // Replace with real Supabase call
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      {
        'id': 1,
        'name': 'Light Jogging in Place',
        'coaching_cues': '',
        'media_url': 'https://res.cloudinary.com/dj66v3aj7/image/upload/v1748938223/20250603_0933_Jogging_in_Place_remix_01jwtb9etwf8ea52mmqjbt4f98_hngyiw.png',
        'sets': 3,
        'min_quantity': 30,
        'max_quantity': 30,
        'duration_type': 'seconds',
        'is_superset': false,
        'has_alternative': false,
      },
      {
        'id': 2,
        'name': 'Push Ups',
        'coaching_cues': 'Keep back straight',
        'media_url': '',
        'sets': 3,
        'min_quantity': 10,
        'max_quantity': 15,
        'duration_type': 'reps',
        'is_superset': false,
        'has_alternative': false,
      },
    ];
  }
}

// SCREEN THAT LOADS AND PASSES EXERCISES TO RUNNER
class ProgramDayScreen extends StatefulWidget {
  final int programId;
  final int weekNumber;
  final int dayNumber;

  const ProgramDayScreen({
    super.key,
    required this.programId,
    required this.weekNumber,
    required this.dayNumber,
  });

  @override
  State<ProgramDayScreen> createState() => _ProgramDayScreenState();
}

class _ProgramDayScreenState extends State<ProgramDayScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> exercises = [];

  @override
  void initState() {
    super.initState();
    loadExercises();
  }

  Future<void> loadExercises() async {
    final rawExercises = await ExerciseService.fetchExercises(
      programId: widget.programId,
      weekNumber: widget.weekNumber,
      dayNumber: widget.dayNumber,
    );

    // ✅ ENRICH EXERCISES TO INCLUDE REQUIRED LOGGING IDS
    final enrichedExercises = rawExercises.map((e) {
      return {
        ...e,
        'exercise_id': e['id'],               // map exercise primary key
        'program_id': widget.programId,
        'week_number': widget.weekNumber,
        'day_number': widget.dayNumber,
      };
    }).toList();

    setState(() {
      exercises = enrichedExercises;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ExerciseRunnerScreen(
      exercises: exercises,
      restSeconds: 60,
    );
  }
}

// THE EXERCISE RUNNER SCREEN (your original full code)
class ExerciseRunnerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> exercises;
  final int restSeconds;

  const ExerciseRunnerScreen({
    super.key,
    required this.exercises,
    this.restSeconds = 60,
  });

  @override
  State<ExerciseRunnerScreen> createState() => _ExerciseRunnerScreenState();
}

class _ExerciseRunnerScreenState extends State<ExerciseRunnerScreen>
    with SingleTickerProviderStateMixin {
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
  late final AnimationController pulseController;

  Map<String, dynamic> get currentExercise => widget.exercises[currentIndex];

  @override
  void initState() {
    super.initState();

    tickPlayer = AudioPlayer();
    dingPlayer = AudioPlayer();

    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      lowerBound: 0.95,
      upperBound: 1.05,
    );

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

  String getDurationType() {
    return (currentExercise['duration_type'] as String? ?? 'reps').toLowerCase();
  }

  bool isTimedExercise() => getDurationType().contains('seconds');

  bool isPerSide() {
    final type = getDurationType();
    return type.contains('each_side') || type.contains('each_direction');
  }

  bool isSuperset() => currentExercise['is_superset'] == true;

  bool hasAlternative() =>
      currentExercise['has_alternative'] == true &&
          currentExercise['alternative'] != null;

  Future<void> startCurrentExercise() async {
    exerciseTimer?.cancel();
    isResting = false;
    mediaReady = false;
    if (mounted) setState(() {});

    final url = currentExercise['media_url'];
    if (url != null && url.toString().isNotEmpty) {
      try {
        await precacheImage(CachedNetworkImageProvider(url), context);
      } catch (_) {}
    }

    mediaReady = true;
    if (mounted) setState(() {});

    lastSelectedReps = getQuantity();

    int seconds;
    if (isTimedExercise()) {
      seconds = max(1, getQuantity());
      if (isPerSide()) seconds *= 2;
    } else {
      seconds = 0;
    }

    totalSeconds = seconds;
    remainingSeconds = seconds;
    isPaused = false;

    if (isTimedExercise()) {
      exerciseTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (isPaused) return;

        if (remainingSeconds <= 1) {
          t.cancel();
          await dingPlayer.play(AssetSource('sounds/ding.wav'));
          await finishSet();
        } else {
          setState(() => remainingSeconds--);

          if (remainingSeconds <= 5) {
            await tickPlayer.play(AssetSource('sounds/tick.wav'));
            pulseController.forward(from: 0.95);
          }
        }
      });
    }
  }

  Future<void> logSetToDatabase() async {
    final ex = currentExercise;

    final programId = ex['program_id'];
    final exerciseId = ex['exercise_id'];
    final weekNumber = ex['week_number'];
    final dayNumber = ex['day_number'];

    if (programId == null ||
        exerciseId == null ||
        weekNumber == null ||
        dayNumber == null) {
      debugPrint("❌ NOT LOGGING — missing IDs in exercise map:");
      debugPrint(ex.toString());
      return;
    }

    final repsToLog = lastSelectedReps;

    await ProgressService.logExercise(
      programId: programId as int,
      exerciseId: exerciseId as int,
      weekNumber: weekNumber as int,
      dayNumber: dayNumber as int,
      repsCompleted: repsToLog,
      weightUsedKg: ex['weight_used_kg'] != null
          ? (ex['weight_used_kg'] as num).toDouble()
          : null,
    );
  }

  Future<void> finishSet() async {
    exerciseTimer?.cancel();

    if (!isTimedExercise()) {
      int selectedReps = lastSelectedReps;

      await showModalBottomSheet(
        context: context,
        isDismissible: false,
        builder: (_) {
          return SizedBox(
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
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      );

      lastSelectedReps = selectedReps;
    }

    await logSetToDatabase();

    final totalSets = currentExercise['sets'] as int? ?? 1;

    if (currentSet < totalSets) {
      currentSet++;
    } else if (currentIndex < widget.exercises.length - 1) {
      currentIndex++;
      currentSet = 1;
    } else {
      Navigator.pop(context);
      return;
    }

    if (isSuperset()) {
      startCurrentExercise();
    } else {
      startRest();
    }
  }

  void startRest() {
    exerciseTimer?.cancel();
    isResting = true;
    remainingSeconds = widget.restSeconds;
    totalSeconds = widget.restSeconds;
    setState(() {});

    exerciseTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (isPaused) return;

      if (remainingSeconds <= 1) {
        t.cancel();
        await dingPlayer.play(AssetSource('sounds/ding.wav'));
        isResting = false;
        startCurrentExercise();
      } else {
        setState(() => remainingSeconds--);
      }
    });
  }

  void togglePause() => setState(() => isPaused = !isPaused);

  void addSeconds(int s) {
    setState(() {
      remainingSeconds += s;
      totalSeconds += s;
    });
  }

  void skipRestOrExercise() async {
    exerciseTimer?.cancel();

    if (isResting) {
      isResting = false;
      startCurrentExercise();
    } else {
      await finishSet();
    }
  }

  void switchToAlternative() {
    final alt = currentExercise['alternative'];
    if (alt == null) return;

    widget.exercises[currentIndex] = alt;
    startCurrentExercise();
  }

  @override
  void dispose() {
    exerciseTimer?.cancel();
    tickPlayer.dispose();
    dingPlayer.dispose();
    pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ex = currentExercise;
    final isTimed = isTimedExercise();
    final qty = getQuantity();
    final progress = totalSeconds == 0
        ? 0.0
        : (remainingSeconds / totalSeconds).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(isResting ? "Rest" : ex['name'] ?? 'Exercise'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!isResting && hasAlternative())
              ElevatedButton(
                onPressed: switchToAlternative,
                child: const Text("Switch Exercise"),
              ),
            if (!isResting)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: mediaReady
                    ? CachedNetworkImage(
                  imageUrl: ex['media_url'],
                  height: 240,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
                    : const SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            const SizedBox(height: 12),
            Text("Set $currentSet / ${ex['sets'] ?? 1}",
                style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size =
                      min(constraints.maxWidth, constraints.maxHeight) * 0.75;

                  return Center(
                    child: ScaleTransition(
                      scale: remainingSeconds <= 5
                          ? pulseController
                          : const AlwaysStoppedAnimation(1.0),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: size,
                            height: size,
                            child: CircularProgressIndicator(
                              value: 1,
                              strokeWidth: size * 0.07,
                              valueColor: AlwaysStoppedAnimation(
                                  Colors.grey.shade300),
                            ),
                          ),
                          if (isTimed || isResting)
                            SizedBox(
                              width: size,
                              height: size,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: size * 0.07,
                              ),
                            ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isTimed || isResting)
                                Text("$remainingSeconds",
                                    style: TextStyle(
                                        fontSize: size * 0.22,
                                        fontWeight: FontWeight.bold))
                              else
                                Text(
                                    isPerSide()
                                        ? "$qty reps each side"
                                        : "$qty reps",
                                    style: TextStyle(
                                        fontSize: size * 0.16,
                                        fontWeight: FontWeight.bold)),
                              if (!isTimed && !isResting)
                                ElevatedButton(
                                  onPressed: finishSet,
                                  child: const Text("Finish Set"),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (isTimed || isResting)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: togglePause,
                    child: Text(isPaused ? "Resume" : "Pause"),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => addSeconds(10),
                    child: const Text("+10s"),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: skipRestOrExercise,
                    child: const Text("Skip"),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
