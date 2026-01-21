import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'rest_screen.dart';

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

  late final AudioPlayer tickPlayer;
  late final AudioPlayer dingPlayer;

  late AnimationController pulseController;

  Map<String, dynamic> get currentExercise => widget.exercises[currentIndex];

  int getQuantity() {
    final minQ = currentExercise['min_quantity'] as int? ?? 0;
    final maxQ = currentExercise['max_quantity'] as int? ?? minQ;
    if (minQ == 0 && maxQ == 0) return 0;
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

    startExercise();
  }

  void startExercise() {
    exerciseTimer?.cancel();
    isPaused = false;

    pulseController.stop();
    pulseController.value = 1.0;

    if (isTimedExercise()) {
      int base = max(1, getQuantity());
      totalSeconds = isPerSide() ? base * 2 : base;
      remainingSeconds = totalSeconds;

      exerciseTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (isPaused) return;

        if (remainingSeconds <= 1) {
          t.cancel();
          await dingPlayer.play(AssetSource('sounds/ding.wav'));
          finishSet();
        } else {
          setState(() => remainingSeconds--);

          if (remainingSeconds <= 5) {
            await tickPlayer.play(AssetSource('sounds/tick.wav'));
            pulseController.forward(from: 0.95);
          }
        }
      });
    }

    setState(() {});
  }

  Future<void> finishSet() async {
    exerciseTimer?.cancel();

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RestScreen(restSeconds: widget.restSeconds),
      ),
    );

    if (result != true) return;

    final totalSets = currentExercise['sets'] as int? ?? 1;

    setState(() {
      if (currentSet < totalSets) {
        currentSet++;
        startExercise();
      } else {
        if (currentIndex + 1 >= widget.exercises.length) {
          Navigator.pop(context);
        } else {
          currentIndex++;
          currentSet = 1;
          startExercise();
        }
      }
    });
  }

  void togglePause() {
    setState(() => isPaused = !isPaused);
  }

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
    pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ex = currentExercise;
    final isTimed = isTimedExercise();
    final qty = getQuantity();

    final progress =
    isTimed ? (remainingSeconds / totalSeconds).clamp(0.0, 1.0) : 1.0;

    return Scaffold(
      appBar: AppBar(title: Text(ex['name'] ?? 'Exercise')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ex['media_url'] != null && ex['media_url'].toString().isNotEmpty
                  ? Image.network(ex['media_url'],
                  height: 240, width: double.infinity, fit: BoxFit.cover)
                  : Container(
                height: 240,
                color: Colors.grey.shade300,
                child: const Center(child: Text("No media")),
              ),
            ),

            const SizedBox(height: 16),

            Text("Set $currentSet / ${ex['sets'] ?? 1}",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            const SizedBox(height: 24),

            if (isTimed)
              ScaleTransition(
                scale: remainingSeconds <= 5
                    ? pulseController
                    : const AlwaysStoppedAnimation(1.0),
                child: SizedBox(
                  width: 320,
                  height: 320,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background ring
                      SizedBox(
                        width: 300,
                        height: 300,
                        child: CircularProgressIndicator(
                          value: 1,
                          strokeWidth: 18,
                          valueColor: AlwaysStoppedAnimation(Colors.grey.shade300),
                        ),
                      ),

                      // Progress ring
                      SizedBox(
                        width: 240,
                        height: 240,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 18,
                        ),
                      ),

                      // Center content
                      Container(
                        width: 180,
                        height: 180,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "$remainingSeconds",
                              style: const TextStyle(
                                fontSize: 72,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "seconds",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )

            else
              Column(
                children: [
                  Text(
                    isPerSide() ? "$qty reps each side" : "$qty reps",
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: finishSet,
                    child: const Text("Finish Set"),
                  ),
                ],
              ),

            const Spacer(),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: togglePause,
                  child: Text(isPaused ? "Resume" : "Pause"),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => addSeconds(5),
                  child: const Text("+5s"),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => addSeconds(10),
                  child: const Text("+10s"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
