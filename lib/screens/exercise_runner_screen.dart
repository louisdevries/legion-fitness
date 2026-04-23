import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/exercise_runner_state.dart';
import '../services/exercise_runner_service.dart';
import '../utils/exercise_category_utils.dart';
import '../utils/exercise_runner_utils.dart';
import 'widgets/exercise_runner/category_badge.dart';
import 'widgets/exercise_runner/coaching_cue_box.dart';
import 'widgets/exercise_runner/exercise_media.dart';
import 'widgets/exercise_runner/progress_ring.dart';
import 'widgets/exercise_runner/rest_controls.dart';
import 'widgets/exercise_runner/timer_adjust_controls.dart';
import 'widgets/exercise_runner/workout_progress_bar.dart';
import '../services/sync_service.dart';

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

class NextExercisePreview extends StatelessWidget {
  final Map<String, dynamic> exercise;

  const NextExercisePreview({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final name = exercise['name'] ?? 'Exercise';
    final mediaUrl = exercise['media_url'] ?? '';

    final sets = exercise['sets'] ?? 1;
    final minQ = exercise['min_quantity'] ?? 0;
    final maxQ = exercise['max_quantity'] ?? minQ;
    final durationType =
    (exercise['duration_type'] ?? 'reps').toString().toLowerCase();

    final unit = durationType.contains('second') ? 'sec' : 'reps';

    final quantity = minQ == maxQ
        ? '$sets × $minQ $unit'
        : '$sets × $minQ–$maxQ $unit';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: mediaUrl.isNotEmpty
                ? Image.network(
              mediaUrl,
              width: 70,
              height: 70,
              fit: BoxFit.cover,
            )
                : const SizedBox(
              width: 70,
              height: 70,
              child: Icon(Icons.fitness_center),
            ),
          ),

          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Up Next",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  quantity,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseRunnerScreenState extends State<ExerciseRunnerScreen> {
  late ExerciseRunnerState _s;
  late List<Map<String, dynamic>> exercises;
  late final ExerciseRunnerService _svc;
  Timer? _timer;

  // ── Convenience getters ──────────────────────────────────────────

  Map<String, dynamic> get _currentExercise => exercises[_s.currentIndex];

  Map<String, dynamic>? get _currentAlternative =>
      _currentExercise['alternative'] as Map<String, dynamic>?;

  Map<String, dynamic> get _activeExercise =>
      _s.usingAlternative && _currentAlternative != null
          ? _currentAlternative!
          : _currentExercise;

  Map<String, dynamic>? get _nextExercise {
    if (!_isLastSet) {
      return _currentExercise; // same exercise, next set
    } else if (!_isLastExercise) {
      return exercises[_s.currentIndex + 1];
    }
    return null;
  }

  Map<String, dynamic>? get _nextActiveExercise {
    final next = _nextExercise;
    if (next == null) return null;

    final alt = next['alternative'] as Map<String, dynamic>?;
    return (_s.usingAlternative && alt != null) ? alt : next;
  }

  int get _totalSets => _currentExercise['sets'] as int? ?? 1;
  bool get _isLastSet => _s.currentSet >= _totalSets;
  bool get _isLastExercise => _s.currentIndex >= exercises.length - 1;

  bool get _isTimed => ExerciseRunnerUtils.isTimedExercise(_activeExercise);
  String get _category =>
      ExerciseCategoryUtils.resolveCategory(_currentExercise);

  bool _isNewCategory() {
    if (_s.currentIndex == 0) return true;

    final prev = ExerciseRunnerUtils.resolveCategory(
        exercises[_s.currentIndex - 1]);

    final current = _category;

    return prev != current;
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'warmup':
        return 'Warmup';
      case 'cooldown':
        return 'Cooldown';
      default:
        return 'Main Workout';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'warmup':
        return Colors.orange;
      case 'cooldown':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  // ── Init ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _s = const ExerciseRunnerState();
    _svc = ExerciseRunnerService();

    exercises = widget.exercises.map((e) => {
      ...e,
      'exercise_id': e['exercise_id'] ?? e['id'],
      'program_id': widget.programId,
      'week_number': widget.weekNumber,
      'day_number': widget.dayNumber,
    }).toList();

    // ✅ SORT HERE
    exercises.sort((a, b) {
      int getOrder(Map<String, dynamic> ex) {
        final cat = ExerciseRunnerUtils
            .resolveCategory(ex)
            .toLowerCase();

        if (cat.contains('warm')) return 0;
        if (cat.contains('main')) return 1;
        if (cat.contains('cool')) return 2;
        return 1; // default to main
      }

      return getOrder(a).compareTo(getOrder(b));
    });

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _startCurrentExercise());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _svc.dispose();
    super.dispose();
  }

  // ── Exercise start ───────────────────────────────────────────────

  Future<void> _startCurrentExercise() async {
    _timer?.cancel();
    _s = _s.copyWith(
      isResting: false,
      isPaused: false,
      mediaReady: false,
    );
    if (mounted) setState(() {});

    await _svc.precacheMedia(
        ExerciseRunnerUtils.getMediaUrl(_activeExercise), context);

    if (_isTimed) {
      final secs = ExerciseRunnerUtils.getQuantity(_activeExercise);
      _s = _s.copyWith(
        mediaReady: true,
        lastSelectedSeconds: secs,
        totalSeconds: secs,
        remainingSeconds: secs,
      );
    } else {
      _s = _s.copyWith(
        mediaReady: true,
        lastSelectedReps: ExerciseRunnerUtils.getQuantity(_activeExercise),
        totalSeconds: 0,
        remainingSeconds: 0,
      );
    }

    if (mounted) setState(() {});

    if (_isTimed) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (!mounted) { t.cancel(); return; }
        if (_s.isPaused) return;

        if (_s.remainingSeconds <= 1) {
          t.cancel();
          await _svc.playDing();
          await _completeSet(logSet: true);
        } else {
          setState(() => _s = _s.copyWith(
              remainingSeconds: _s.remainingSeconds - 1));
          if (_s.remainingSeconds <= 5) await _svc.playTick();
        }
      });
    }
  }

  // ── Complete set ─────────────────────────────────────────────────

  Future<void> _completeSet({required bool logSet}) async {
    _timer?.cancel();

    if (logSet) {
      int reps = _s.lastSelectedReps;

      if (!_isTimed) {
        await showModalBottomSheet(
          context: context,
          isDismissible: false,
          builder: (_) => _RepsPicker(
            initialReps: reps,
            onConfirm: (v) => reps = v,
          ),
        );
        _s = _s.copyWith(lastSelectedReps: reps);
      } else {
        _s = _s.copyWith(lastSelectedSeconds: _s.totalSeconds);
      }

      _svc.logSet(
        exercise: _currentExercise,
        isTimed: _isTimed,
        lastSelectedSeconds: _s.lastSelectedSeconds,
        lastSelectedReps: _s.lastSelectedReps,
      );

      // ✅ ADD IT HERE (after successful log)
      _s = _s.copyWith(
        completedSets: _s.completedSets + 1,
      );
    }

    if (!_isLastSet) {
      _startRest(nextIndex: _s.currentIndex, nextSet: _s.currentSet + 1);
    } else if (!_isLastExercise) {
      _s = _s.copyWith(usingAlternative: false);
      _startRest(nextIndex: _s.currentIndex + 1, nextSet: 1);
    } else {
      if (_s.completedSets >= _totalRequiredSets) {
        await _showWorkoutComplete();
      } else {
        // User skipped or exited early → just go back silently
        if (mounted) Navigator.pop(context);
      }
    }
  }
  int get _totalRequiredSets {
    return exercises.fold(0, (sum, ex) {
      return sum + ((ex['sets'] as int?) ?? 1);
    });
  }
  // ── Rest ─────────────────────────────────────────────────────────

  void _startRest({required int nextIndex, required int nextSet}) {
    _timer?.cancel();
    _s = _s.copyWith(
      isResting: true,
      remainingSeconds: widget.restSeconds,
      totalSeconds: widget.restSeconds,
    );
    if (mounted) setState(() {});

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_s.remainingSeconds <= 1) {
        t.cancel();
        _proceedToNext(nextIndex, nextSet);
      } else {
        setState(() =>
        _s = _s.copyWith(remainingSeconds: _s.remainingSeconds - 1));
      }
    });
  }

  void _skipRest() {
    _timer?.cancel();
    if (!_isLastSet) {
      _proceedToNext(_s.currentIndex, _s.currentSet + 1);
    } else if (!_isLastExercise) {
      _proceedToNext(_s.currentIndex + 1, 1);
    }
  }

  void _proceedToNext(int nextIndex, int nextSet) {
    _s = _s.copyWith(
      currentIndex: nextIndex,
      currentSet: nextSet,
      usingAlternative: nextSet == 1 ? false : _s.usingAlternative,
    );
    _startCurrentExercise();
  }

  // ── Alternative ──────────────────────────────────────────────────

  void _switchAlternative() {
    if (_currentAlternative == null) return;
    setState(() =>
    _s = _s.copyWith(usingAlternative: !_s.usingAlternative));
    _startCurrentExercise();
  }

  // ── Timer adjust ─────────────────────────────────────────────────

  void _adjustTimer(int delta) {
    final newTotal = max(5, _s.totalSeconds + delta);
    setState(() => _s = _s.copyWith(
      totalSeconds: newTotal,
      remainingSeconds: min(_s.remainingSeconds + delta, newTotal),
      lastSelectedSeconds: newTotal,
    ));
  }

  // ── Workout complete ─────────────────────────────────────────────

  Future<void> _showWorkoutComplete() async {
    // 🔥 trigger final sync
    SyncService.trySync();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Workout Complete 💪'),
        content: const Text('Great job! Your workout has been logged.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final exerciseName =
    ExerciseRunnerUtils.getName(_activeExercise);
    final coachingCues =
    ExerciseRunnerUtils.getCoachingCues(_activeExercise);
    final mediaUrl =
    ExerciseRunnerUtils.getMediaUrl(_activeExercise);
    final quantityDisplay =
    ExerciseRunnerUtils.getQuantityDisplay(_activeExercise);

    return Scaffold(
      appBar: AppBar(
        title: Text(_s.isResting ? 'Rest' : exerciseName),
        backgroundColor: _s.isResting ? Colors.green : null,
        actions: [
          if (!_s.isResting && _currentAlternative != null)
            IconButton(
              icon: Icon(_s.usingAlternative
                  ? Icons.swap_horiz
                  : Icons.sync_alt),
              tooltip: _s.usingAlternative
                  ? 'Switch to main'
                  : 'Try easier version',
              onPressed: _switchAlternative,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!_s.isResting) CategoryBadge(category: _category),
            if (!_s.isResting)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _isNewCategory()
                    ? Column(
                  key: ValueKey(_category),
                  children: [
                    Text(
                      _getCategoryLabel(_category),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _getCategoryColor(_category),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Divider(thickness: 2),
                  ],
                )
                    : const SizedBox.shrink(),
              ),
            if (!_s.isResting)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: WorkoutProgressBar(
                  completed: _s.completedSets,
                  total: _totalRequiredSets,
                ),
              ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Set ${_s.currentSet} / $_totalSets',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_s.usingAlternative)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Easier Version',
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

            if (_s.isResting) ...[
              const Text(
                'REST',
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              ),

              if (_nextActiveExercise != null)
                NextExercisePreview(exercise: _nextActiveExercise!),
            ]
            else
              ExerciseMedia(
                mediaUrl: mediaUrl,
                mediaReady: _s.mediaReady,
              ),

            const SizedBox(height: 16),

            if (!_s.isResting)
              CoachingCueBox(cues: coachingCues),

            const SizedBox(height: 16),

            Expanded(
              child: ProgressRing(
                isTimed: _isTimed,
                isResting: _s.isResting,
                remainingSeconds: _s.remainingSeconds,
                totalSeconds: _s.totalSeconds,
                quantityDisplay: quantityDisplay,
              ),
            ),

            if (_isTimed && !_s.isResting)
              TimerAdjustControls(
                onMinus: () => _adjustTimer(-5),
                onPlus: () => _adjustTimer(5),
              ),

            const SizedBox(height: 12),

            if (_s.isResting)
              RestControls(onSkip: _skipRest)
            else
              ElevatedButton(
                onPressed: () => _completeSet(logSet: true),
                child: const Text('Finish Set'),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Extracted reps picker ────────────────────────────────────────────

class _RepsPicker extends StatefulWidget {
  final int initialReps;
  final ValueChanged<int> onConfirm;

  const _RepsPicker({
    required this.initialReps,
    required this.onConfirm,
  });

  @override
  State<_RepsPicker> createState() => _RepsPickerState();
}

class _RepsPickerState extends State<_RepsPicker> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialReps;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Text('How many reps did you do?',
              style: TextStyle(fontSize: 18)),
          Expanded(
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController:
              FixedExtentScrollController(initialItem: _selected - 1),
              onSelectedItemChanged: (v) => _selected = v + 1,
              children: List.generate(
                  50, (i) => Center(child: Text('${i + 1}'))),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onConfirm(_selected);
              Navigator.pop(context);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}