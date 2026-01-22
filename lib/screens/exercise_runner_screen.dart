import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
          startRestOrNext();
        } else {
          setState(() => remainingSeconds--);

          if (remainingSeconds <= 5) {
            await tickPlayer.play(AssetSource('sounds/tick.wav'));
            pulseController.forward(from: 0.95);
          }
        }
      });
    } else {
      setState(() {});
    }
  }

  void startRestOrNext() {
    final totalSets = currentExercise['sets'] as int? ?? 1;

    if (currentSet < totalSets || currentIndex < widget.exercises.length - 1) {
      startRest();
    } else {
      Navigator.pop(context);
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

        final totalSets = currentExercise['sets'] as int? ?? 1;
        if (currentSet < totalSets) {
          currentSet++;
        } else if (currentIndex < widget.exercises.length - 1) {
          currentIndex++;
          currentSet = 1;
        }

        startCurrentExercise();
      } else {
        setState(() => remainingSeconds--);

        if (remainingSeconds <= 5) {
          await tickPlayer.play(AssetSource('sounds/tick.wav'));
          pulseController.forward(from: 0.95);
        }
      }
    });
  }

  void finishExercise() {
    exerciseTimer?.cancel();

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

    startRest();
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

  void skipRestOrExercise() {
    exerciseTimer?.cancel();
    final totalSets = currentExercise['sets'] as int? ?? 1;
    if (isResting) {
      if (currentSet < totalSets) {
        currentSet++;
      } else if (currentIndex < widget.exercises.length - 1) {
        currentIndex++;
        currentSet = 1;
      } else {
        Navigator.pop(context);
        return;
      }
    }
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
    final progress = (remainingSeconds / totalSeconds).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(isResting ? "Rest" : ex['name'] ?? 'Exercise'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!isResting) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: mediaReady
                    ? CachedNetworkImage(
                  imageUrl: ex['media_url'],
                  height: 240,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const SizedBox(
                      height: 240,
                      child: Center(child: CircularProgressIndicator())),
                  errorWidget: (_, __, ___) => Container(
                      height: 240,
                      color: Colors.grey,
                      child: const Icon(Icons.broken_image)),
                )
                    : const SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator())),
              ),
              const SizedBox(height: 16),
              Text(
                "Set $currentSet / ${ex['sets'] ?? 1}",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
            ] else ...[
              const SizedBox(height: 40),
              const Text("Take a short break", style: TextStyle(fontSize: 24)),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = min(constraints.maxWidth, constraints.maxHeight) * 0.6;
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
                              valueColor: AlwaysStoppedAnimation(Colors.grey.shade300),
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
                                Text(
                                  "$remainingSeconds",
                                  style: TextStyle(
                                    fontSize: size * 0.22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              else
                                Text(
                                  isPerSide()
                                      ? "$qty reps each side"
                                      : "$qty reps",
                                  style: TextStyle(
                                    fontSize: size * 0.18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              if (isTimed || isResting)
                                const Text("seconds")
                              else
                                const SizedBox.shrink(),
                              if (!isTimed && !isResting)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: ElevatedButton(
                                    onPressed: finishExercise,
                                    child: const Text("Finish Set"),
                                  ),
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
                  if (!isResting)
                    ElevatedButton(
                      onPressed: () => addSeconds(5),
                      child: const Text("+5s"),
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
