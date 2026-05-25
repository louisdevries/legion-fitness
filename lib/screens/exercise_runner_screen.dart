import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/exercise_runner_state.dart';
import '../services/exercise_runner_service.dart';
import '../utils/exercise_category_utils.dart';
import '../utils/exercise_runner_utils.dart';
import 'Widgets/exercise_runner/category_badge.dart';
import 'Widgets/exercise_runner/coaching_cue_box.dart';
import 'Widgets/exercise_runner/exercise_media.dart';
import 'Widgets/exercise_runner/progress_ring.dart';
import 'Widgets/exercise_runner/rest_controls.dart';
import 'Widgets/exercise_runner/workout_progress_bar.dart';
import '../services/sync_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:legion_fitness/models/exercise_set_result.dart';
import '../services/achievement_service.dart';
import '../services/xp_service.dart';
import 'workout_results_screen.dart';

class ExerciseRunnerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> exercises;
  final int restSeconds;
  final int programId;
  final int weekNumber;
  final int dayNumber;
  final bool resumeMode;

  const ExerciseRunnerScreen({
    super.key,
    required this.exercises,
    required this.programId,
    required this.weekNumber,
    required this.dayNumber,
    this.restSeconds = 60,
    this.resumeMode = false,
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
    final setQuantities = exercise['set_quantities'];
    final minQ = exercise['min_quantity'] ?? 0;
    final durationType =
    (exercise['duration_type'] ?? 'reps').toString().toLowerCase();
    final unit = durationType.contains('second') ? 'sec' : 'reps';

    final isUntilFailure = durationType.contains('failure');
    String quantity;
    if (setQuantities is List &&
        setQuantities.isNotEmpty &&
        setQuantities.any((v) => (v as num).toInt() > 0)) {
      // Concrete values present — use them (handles week 2+ progression
      // even for until-failure exercises).
      quantity = '$sets × ${setQuantities.map((e) => e.toString()).join('/')} $unit';
    } else if (isUntilFailure) {
      quantity = '$sets × until failure';
    } else {
      quantity = '$sets × $minQ $unit';
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: mediaUrl.isNotEmpty
                ? Image.network(mediaUrl,
                width: 70, height: 70, fit: BoxFit.cover)
                : const SizedBox(
                width: 70,
                height: 70,
                child: Icon(Icons.fitness_center)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Up Next',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(quantity, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseRunnerScreenState extends State<ExerciseRunnerScreen>
    with WidgetsBindingObserver {
  late ExerciseRunnerState _s;
  late List<Map<String, dynamic>> exercises;
  late final ExerciseRunnerService _svc;
  late final DateTime _workoutStartTime;
  Timer? _timer;

  // ── Convenience getters ──────────────────────────────────────────
  Map<String, dynamic> get _currentExercise => exercises[_s.currentIndex];

  Map<String, dynamic>? get _supersetPartner {
    final partner = _currentExercise['superset_partner'];
    if (partner is Map<String, dynamic>) return partner;
    return null;
  }

  bool get _isSuperset => _supersetPartner != null && !_s.usingAlternative;

  // Which exercise is currently active within the superset
  // (false = primary, true = superset partner)
  bool get _onSupersetPartner => _s.onSupersetPartner;

  Map<String, dynamic> get _activeExercise {
    if (_s.usingAlternative) {
      final alt = _currentExercise['alternative'];
      if (alt is Map<String, dynamic>) return alt;
    }
    if (_isSuperset && _onSupersetPartner) return _supersetPartner!;
    return _currentExercise;
  }

  Map<String, dynamic>? get _currentAlternative {
    final alt = _currentExercise['alternative'];
    if (alt is Map<String, dynamic>) return alt;
    return null;
  }

  Map<String, dynamic>? get _nextExercise {
    if (!_isLastSet) return _currentExercise;
    if (!_isLastExercise) return exercises[_s.currentIndex + 1];
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

  // Supersets are always rep-based
  bool get _isTimed =>
      !_isSuperset &&
          !_isUntilFailure &&
          ExerciseRunnerUtils.isTimedExercise(_activeExercise);

  bool get _isUntilFailure =>
      ExerciseRunnerUtils.isUntilFailure(_activeExercise);

  bool get _isEachSide =>
      ExerciseRunnerUtils.isEachSide(_activeExercise);

  String get _category =>
      ExerciseCategoryUtils.resolveCategory(_currentExercise);
  String get _resumeKey => 'active_session';

  int get _prescribedRepsForCurrentSet {
    final exercise = _onSupersetPartner && _isSuperset
        ? _supersetPartner!
        : _currentExercise;
    final setQuantities = exercise['set_quantities'];
    if (setQuantities is List && setQuantities.length >= _s.currentSet) {
      return (setQuantities[_s.currentSet - 1] as num).toInt();
    }
    return exercise['min_quantity'] as int? ?? 10;
  }

  String get _appBarTitle {
    if (_s.isResting) return 'Rest';
    if (_isSuperset) {
      final primaryName = ExerciseRunnerUtils.getName(_currentExercise);
      final partnerName = ExerciseRunnerUtils.getName(_supersetPartner!);
      return '$primaryName + $partnerName';
    }
    return ExerciseRunnerUtils.getName(_activeExercise);
  }

  bool _isNewCategory() {
    if (_s.currentIndex == 0) return true;
    final prev =
    ExerciseRunnerUtils.resolveCategory(exercises[_s.currentIndex - 1]);
    return prev != _category;
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
    _workoutStartTime = DateTime.now();

    WidgetsBinding.instance.addObserver(this);

    exercises = widget.exercises.map((e) {
      final altSource = e['alternative_exercise'];
      Map<String, dynamic>? alternative;

      if (altSource != null && altSource is Map) {
        alternative = {
          'exercise_id': altSource['id'],
          'name': altSource['name']?.toString().isNotEmpty == true
              ? altSource['name']
              : 'Alternative Exercise',
          'media_url': altSource['media_url']?.toString() ?? '',
          'coaching_cues': altSource['coaching_cues'] ?? '',
          'sets': e['alternative_sets'] ?? e['sets'],
          'min_quantity': altSource['min_quantity'],
          'max_quantity': altSource['max_quantity'],
          'duration_type': altSource['duration_type'],
          'set_quantities': altSource['set_quantities'],
        };
      } else if (e['alternative_exercise_id'] != null) {
        alternative = {
          'exercise_id': e['alternative_exercise_id'],
          'name': e['alternative_exercise_name']?.toString().isNotEmpty == true
              ? e['alternative_exercise_name']
              : 'Alternative Exercise',
          'media_url': e['alternative_media_url']?.toString() ?? '',
          'sets': e['alternative_sets'] ?? e['sets'],
          'min_quantity': e['alternative_min_quantity'] ?? e['min_quantity'],
          'max_quantity': e['alternative_max_quantity'] ?? e['max_quantity'],
          'duration_type': e['alternative_duration_type'] ?? e['duration_type'],
          'set_quantities': e['alternative_set_quantities'],
        };
      }

      // Superset partner — already a populated map from the service
      final supersetPartner = e['superset_partner'] as Map<String, dynamic>?;

      return {
        ...e,
        'exercise_id': e['exercise_id'] ?? e['id'],
        'program_id': widget.programId,
        'week_number': widget.weekNumber,
        'day_number': widget.dayNumber,
        'alternative': alternative,
        'superset_partner': supersetPartner,
      };
    }).toList();

    exercises.sort((a, b) {
      int getOrder(Map<String, dynamic> ex) {
        final cat = ExerciseRunnerUtils.resolveCategory(ex).toLowerCase();
        if (cat.contains('warm')) return 0;
        if (cat.contains('main')) return 1;
        if (cat.contains('cool')) return 2;
        return 1;
      }
      return getOrder(a).compareTo(getOrder(b));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.resumeMode) {
        await _loadSession();
      } else {
        _startCurrentExercise();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _svc.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveState();
    }
  }

  void _maybeShowUnlocks(List<UnlockedAchievement> unlocked) {
    if (!mounted || unlocked.isEmpty) return;
    for (final a in unlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(child: Text('🏆 Unlocked: ${a.label}')),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }



  // ── Session persistence ──────────────────────────────────────────
  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _resumeKey,
      jsonEncode({
        'programId': widget.programId,
        'weekNumber': widget.weekNumber,
        'dayNumber': widget.dayNumber,
        'currentIndex': _s.currentIndex,
        'currentSet': _s.currentSet,
        'completedSets': _s.completedSets,
        'usingAlternative': _s.usingAlternative,
        'onSupersetPartner': _s.onSupersetPartner,
        'onSecondSide': _s.onSecondSide,
        'isResting': _s.isResting,
        'remainingSeconds': _s.remainingSeconds,
        'totalSeconds': _s.totalSeconds,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'exercises': exercises,
      }),
    );
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_resumeKey);

    if (json == null) {
      _startCurrentExercise();
      return;
    }

    final data = jsonDecode(json) as Map<String, dynamic>;
    final timestamp = data['timestamp'] as int? ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > 3 * 60 * 60 * 1000) {
      await _clearState();
      _startCurrentExercise();
      return;
    }

    exercises =
    List<Map<String, dynamic>>.from(data['exercises'] as List? ?? []);
    if (exercises.isEmpty) {
      _startCurrentExercise();
      return;
    }

    final wasResting = data['isResting'] as bool? ?? false;

    setState(() {
      _s = ExerciseRunnerState(
        currentIndex: data['currentIndex'] as int? ?? 0,
        currentSet: data['currentSet'] as int? ?? 1,
        completedSets: data['completedSets'] as int? ?? 0,
        usingAlternative: data['usingAlternative'] as bool? ?? false,
        onSupersetPartner: data['onSupersetPartner'] as bool? ?? false,
        onSecondSide: data['onSecondSide'] as bool? ?? false,
        isResting: wasResting,
        remainingSeconds: data['remainingSeconds'] as int? ?? 0,
        totalSeconds: data['totalSeconds'] as int? ?? 0,
        mediaReady: true,
      );
    });

    if (wasResting) {
      _resumeRestTimer();
    } else {
      _startCurrentExercise();
    }
  }

  Future<void> _clearState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_resumeKey);
  }

  void _togglePause() {
    setState(() => _s = _s.copyWith(isPaused: !_s.isPaused));
    _saveState();
  }

  // ── Exercise start ───────────────────────────────────────────────
  Future<void> _startCurrentExercise() async {
    _timer?.cancel();
    _s = _s.copyWith(
      isResting: false,
      isPaused: false,
      mediaReady: false,
      onSecondSide: _s.onSecondSide,
    );
    await _saveState();
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
        lastSelectedReps: _prescribedRepsForCurrentSet,
        totalSeconds: 0,
        remainingSeconds: 0,
      );
    }

    if (mounted) setState(() {});
    if (_isTimed) _startExerciseTimer();
  }

  void _startExerciseTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_s.isPaused) return;
      if (_s.remainingSeconds <= 1) {
        t.cancel();
        await _svc.playDing();
        await _completeSet(logSet: true);
      } else {
        setState(
                () => _s = _s.copyWith(remainingSeconds: _s.remainingSeconds - 1));
        if (_s.remainingSeconds <= 5) await _svc.playTick();
      }
    });
  }

  // ── Rest ─────────────────────────────────────────────────────────
  void _startRest({required int nextIndex, required int nextSet}) {
    _timer?.cancel();
    _s = _s.copyWith(
      isResting: true,
      onSupersetPartner: false,
      remainingSeconds: widget.restSeconds,
      totalSeconds: widget.restSeconds,
    );
    if (mounted) setState(() {});
    _saveState();
    _startRestTimer(nextIndex, nextSet);
  }

  void _startRestTimer(int nextIndex, int nextSet) {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_s.isPaused) return;
      if (_s.remainingSeconds <= 1) {
        t.cancel();
        _proceedToNext(nextIndex, nextSet);
      } else {
        setState(
                () => _s = _s.copyWith(remainingSeconds: _s.remainingSeconds - 1));
        _saveState();
      }
    });
  }

  void _resumeRestTimer() {
    final nextIndex = _isLastSet ? _s.currentIndex + 1 : _s.currentIndex;
    final nextSet = _isLastSet ? 1 : _s.currentSet + 1;
    if (mounted) setState(() {});
    _startRestTimer(nextIndex, nextSet);
  }

  void _skipRest() {
    _timer?.cancel();
    final nextIndex = _isLastSet ? _s.currentIndex + 1 : _s.currentIndex;
    final nextSet = _isLastSet ? 1 : _s.currentSet + 1;
    _proceedToNext(nextIndex, nextSet);
  }

  void _proceedToNext(int nextIndex, int nextSet) {
    _s = _s.copyWith(
      currentIndex: nextIndex,
      currentSet: nextSet,
      onSupersetPartner: false,
      onSecondSide: false,
      usingAlternative: nextSet == 1 ? false : _s.usingAlternative,
    );
    _startCurrentExercise();
    _saveState();
  }

  // ── Complete set ─────────────────────────────────────────────────
  Future<void> _completeSet({required bool logSet}) async {
    _timer?.cancel();

    if (logSet) {
      final setIndexToLog = _s.currentSet;
      int repsLogged = 0;
      int? secondsLogged;

      // Decide what to log and whether to ask the user.
      if (_isUntilFailure) {
        // Until-failure: ask the user how many they managed.
        // The progression engine uses this to set a concrete target
        // for next week (previous reps + 1).
        // Default the picker to the prescribed value if we have one
        // from a previous week, otherwise start at 10 as a reasonable
        // guess.
        final prescribed = _prescribedRepsForCurrentSet > 1
            ? _prescribedRepsForCurrentSet
            : 10;
        await showModalBottomSheet(
          context: context,
          isDismissible: false,
          builder: (_) => _RepsPicker(
            initialReps: prescribed,
            onConfirm: (v) => repsLogged = v,
          ),
        );
      } else if (_isTimed) {
        // Timed: log the duration (already done — no picker needed).
        secondsLogged = _s.totalSeconds;
        repsLogged = 0;
      } else {
        // Rep-based: ask the user how many they did.
        final prescribed = _prescribedRepsForCurrentSet;
        await showModalBottomSheet(
          context: context,
          isDismissible: false,
          builder: (_) => _RepsPicker(
            initialReps: prescribed,
            onConfirm: (v) => repsLogged = v,
          ),
        );
      }

      // Log the active exercise (primary, superset partner, or current side).
      final exerciseToLog =
      _onSupersetPartner && _isSuperset ? _supersetPartner! : _currentExercise;
      final exerciseIdToLog =
          exerciseToLog['exercise_id'] as int? ?? exerciseToLog['id'] as int;

      final newSet = ExerciseSetResult(
        setIndex: setIndexToLog,
        reps: repsLogged,
        durationSeconds: secondsLogged,
      );

      _s = _s.copyWith(
        completedSetsData: [..._s.completedSetsData, newSet],
        completedSets: _s.completedSets + 1,
      );

      await _saveState();

      final completionValue = _isTimed ? (secondsLogged ?? 0) : repsLogged;

      await _svc.logSet(
        exercise: {
          ..._currentExercise,
          'exercise_id': exerciseIdToLog,
        },
        isTimed: _isTimed,
        lastSelectedSeconds: secondsLogged ?? 0,
        lastSelectedReps: repsLogged,
        setIndex: setIndexToLog,
        repsCompleted: completionValue,
      );

      // ── Achievement progress ───────────────────────────────────
      final unlocked = await AchievementService.onSetLogged(
        exerciseId: exerciseIdToLog,
        reps: repsLogged,
      );
      _maybeShowUnlocks(unlocked);

    }



    // ── Each-side flow ───────────────────────────────────────────
    // After the FIRST side, switch to the second — no rest.
    if (_isEachSide && !_s.onSecondSide) {
      setState(() => _s = _s.copyWith(onSecondSide: true));
      await _startCurrentExercise();
      return;
    }

    // ── Superset flow ────────────────────────────────────────────
    // After the primary, switch to the partner — no rest.
    if (_isSuperset && !_onSupersetPartner) {
      setState(() => _s = _s.copyWith(onSupersetPartner: true));
      await _startCurrentExercise();
      return;
    }

    // ── Normal set completion flow ───────────────────────────────
    // Reset onSecondSide for the next set so left starts again.
    final totalSetsForExercise = _currentExercise['sets'] as int? ?? 1;
    final justCompletedSet = _s.currentSet;

    if (justCompletedSet < totalSetsForExercise) {
      _s = _s.copyWith(onSecondSide: false);
      _startRest(
        nextIndex: _s.currentIndex,
        nextSet: justCompletedSet + 1,
      );
    } else if (!_isLastExercise) {
      _s = _s.copyWith(usingAlternative: false, onSecondSide: false);
      _startRest(
        nextIndex: _s.currentIndex + 1,
        nextSet: 1,
      );
    } else {
      if (_s.completedSetsData.length >= _totalRequiredSets) {
        await _showWorkoutComplete();
      } else {
        await _clearState();
        if (mounted) Navigator.pop(context);
      }
    }
  }

  int get _totalRequiredSets {
    return exercises.fold(0, (sum, ex) {
      final sets = (ex['sets'] as int?) ?? 1;
      final hasSuperset = ex['superset_partner'] != null;
      // Each-side exercises log once per side, so count them double too
      final isEachSide = ExerciseRunnerUtils.isEachSide(ex);
      final multiplier = hasSuperset ? 2 : (isEachSide ? 2 : 1);
      return sum + sets * multiplier;
    });
  }

  // ── Alternative ──────────────────────────────────────────────────
  void _switchAlternative() {
    if (_currentAlternative == null) return;
    setState(() => _s = _s.copyWith(usingAlternative: !_s.usingAlternative));
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


  // ── Exit confirmation ────────────────────────────────────────────
  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave workout?'),
        content: const Text(
          'Your progress is saved. You can resume this workout later from the home screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Workout complete ─────────────────────────────────────────────
  Future<void> _showWorkoutComplete() async {
    final duration = DateTime.now().difference(_workoutStartTime);
    final streakUnlocks = await AchievementService.onWorkoutCompleted();
    final xpGrants = await XpService.onWorkoutCompleted(
      programId: widget.programId,
      weekNumber: widget.weekNumber,
      dayNumber: widget.dayNumber,
    );
    await SyncService.trySync();
    await _clearState();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutResultsScreen(
          duration: duration,
          exercises: exercises,
          totalSetsCompleted: _s.completedSetsData.length,
          xpGrants: xpGrants,
          achievements: streakUnlocks,
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _s.isResting
                ? 'Rest'
                : _isSuperset
                ? 'Superset'
                : _getCategoryLabel(_category),
          ),
          foregroundColor: Colors.white,
          backgroundColor: _s.isResting
              ? Colors.green
              : _isSuperset
              ? Colors.purple.shade700
              : _getCategoryColor(_category),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _confirmExit()) {
                if (mounted) Navigator.pop(context);
              }
            },
          ),
        ),
        body: OrientationBuilder(
          builder: (context, orientation) {
            final coachingCues =
                ExerciseRunnerUtils.getCoachingCues(_activeExercise);
            final mediaUrl =
                ExerciseRunnerUtils.getMediaUrl(_activeExercise);
            final quantityDisplay = ExerciseRunnerUtils.getQuantityDisplay(
              _activeExercise,
              currentSet: _s.currentSet,
            );
            return orientation == Orientation.landscape
                ? _buildLandscapeBody(coachingCues, mediaUrl, quantityDisplay)
                : _buildPortraitBody(coachingCues, mediaUrl, quantityDisplay);
          },
        ),
      ),
    );
  }

  Widget _buildPortraitBody(
      String coachingCues, String mediaUrl, String quantityDisplay) {
    // Shared header widgets present in both rest and exercise states.
    final header = <Widget>[
      if (!_s.isResting && !_isSuperset)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  ExerciseRunnerUtils.getName(_activeExercise),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_currentAlternative != null)
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
        ),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: WorkoutProgressBar(
          completed: _s.completedSets,
          total: _totalRequiredSets,
        ),
      ),
      if (!_s.isResting)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Set ${_s.currentSet} / $_totalSets',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (_isSuperset)
              _Chip(
                label: _onSupersetPartner ? '2nd exercise' : '1st exercise',
                bg: Colors.purple.shade100,
                fg: Colors.purple.shade700,
              )
            else if (_isEachSide)
              _Chip(
                label: _s.onSecondSide ? 'Right side' : 'Left side',
                bg: Colors.teal.shade100,
                fg: Colors.teal.shade700,
              )
            else if (_s.usingAlternative)
                _Chip(
                  label: 'Easier Version',
                  bg: Colors.orange.shade100,
                  fg: Colors.orange.shade700,
                ),
          ],
        ),
      if (_isSuperset && !_s.isResting) ...[
        const SizedBox(height: 8),
        Text(
          ExerciseRunnerUtils.getName(_activeExercise),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.purple.shade700,
          ),
        ),
      ],
      const SizedBox(height: 12),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ...header,

          // ── Rest state ───────────────────────────────────────
          if (_s.isResting) ...[
            const SizedBox(height: 8),
            ProgressRingCircle(
              remainingSeconds: _s.remainingSeconds,
              totalSeconds: _s.totalSeconds,
              isPaused: _s.isPaused,
              onTogglePause: _togglePause,
              onMinus: () => _adjustTimer(-5),
              onPlus: () => _adjustTimer(5),
            ),
            if (_nextActiveExercise != null)
              NextExercisePreview(exercise: _nextActiveExercise!),
            const SizedBox(height: 12),
            RestControls(onSkip: _skipRest),

          // ── Exercise state — image expands to fill all remaining space ──
          ] else ...[
            Expanded(
              child: ExerciseMedia(
                mediaUrl: mediaUrl,
                mediaReady: _s.mediaReady,
                expand: true,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 10),
            CoachingCueBox(cues: coachingCues),
            const SizedBox(height: 10),
            ProgressRing(
              isTimed: _isTimed,
              isResting: false,
              isPaused: _s.isPaused,
              remainingSeconds: _s.remainingSeconds,
              totalSeconds: _s.totalSeconds,
              quantityDisplay: quantityDisplay,
              onTogglePause: _isTimed ? _togglePause : null,
              onMinus: _isTimed ? () => _adjustTimer(-5) : null,
              onPlus: _isTimed ? () => _adjustTimer(5) : null,
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isSuperset ? Colors.purple.shade700 : null,
                foregroundColor: _isSuperset ? Colors.white : null,
              ),
              onPressed: () => _completeSet(logSet: true),
              child: Text(_isSuperset && !_onSupersetPartner
                  ? 'Next Exercise →'
                  : 'Finish Set'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLandscapeBody(
      String coachingCues, String mediaUrl, String quantityDisplay) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Left: exercise image / next-exercise preview when resting ──
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
            child: _s.isResting
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_nextActiveExercise != null)
                        NextExercisePreview(exercise: _nextActiveExercise!)
                      else
                        const Center(
                          child: Icon(Icons.self_improvement,
                              size: 64, color: Colors.grey),
                        ),
                    ],
                  )
                : ExerciseMedia(
                    mediaUrl: mediaUrl,
                    mediaReady: _s.mediaReady,
                    expand: true,
                  ),
          ),
        ),

        // ── Right: timer/reps banner + controls ───────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(6, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Exercise name + alternative toggle
                if (!_s.isResting && !_isSuperset)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            ExerciseRunnerUtils.getName(_activeExercise),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_currentAlternative != null)
                          IconButton(
                            icon: Icon(_s.usingAlternative
                                ? Icons.swap_horiz
                                : Icons.sync_alt),
                            onPressed: _switchAlternative,
                          ),
                      ],
                    ),
                  ),
                if (_isSuperset && !_s.isResting) ...[
                  Text(
                    ExerciseRunnerUtils.getName(_activeExercise),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                WorkoutProgressBar(
                  completed: _s.completedSets,
                  total: _totalRequiredSets,
                ),
                const SizedBox(height: 8),

                // Set counter + chip
                if (!_s.isResting)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Set ${_s.currentSet} / $_totalSets',
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                      if (_isSuperset)
                        _Chip(
                          label: _onSupersetPartner
                              ? '2nd exercise'
                              : '1st exercise',
                          bg: Colors.purple.shade100,
                          fg: Colors.purple.shade700,
                        )
                      else if (_isEachSide)
                        _Chip(
                          label: _s.onSecondSide ? 'Right side' : 'Left side',
                          bg: Colors.teal.shade100,
                          fg: Colors.teal.shade700,
                        )
                      else if (_s.usingAlternative)
                          _Chip(
                            label: 'Easier Version',
                            bg: Colors.orange.shade100,
                            fg: Colors.orange.shade700,
                          ),
                    ],
                  ),
                const SizedBox(height: 8),

                // Timer / reps banner
                if (_s.isResting)
                  ProgressRing(
                    isTimed: false,
                    isResting: true,
                    isPaused: _s.isPaused,
                    remainingSeconds: _s.remainingSeconds,
                    totalSeconds: _s.totalSeconds,
                    quantityDisplay: '',
                    onTogglePause: _togglePause,
                    onMinus: () => _adjustTimer(-5),
                    onPlus: () => _adjustTimer(5),
                  )
                else
                  ProgressRing(
                    isTimed: _isTimed,
                    isResting: false,
                    isPaused: _s.isPaused,
                    remainingSeconds: _s.remainingSeconds,
                    totalSeconds: _s.totalSeconds,
                    quantityDisplay: quantityDisplay,
                    onTogglePause: _isTimed ? _togglePause : null,
                    onMinus: _isTimed ? () => _adjustTimer(-5) : null,
                    onPlus: _isTimed ? () => _adjustTimer(5) : null,
                  ),
                const SizedBox(height: 8),

                if (!_s.isResting) CoachingCueBox(cues: coachingCues),
                const SizedBox(height: 8),

                // Action button
                SizedBox(
                  width: double.infinity,
                  child: _s.isResting
                      ? RestControls(onSkip: _skipRest)
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _isSuperset ? Colors.purple.shade700 : null,
                            foregroundColor:
                                _isSuperset ? Colors.white : null,
                          ),
                          onPressed: () => _completeSet(logSet: true),
                          child: Text(_isSuperset && !_onSupersetPartner
                              ? 'Next Exercise →'
                              : 'Finish Set'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RepsPicker extends StatefulWidget {
  final int initialReps;
  final ValueChanged<int> onConfirm;
  const _RepsPicker({required this.initialReps, required this.onConfirm});

  @override
  State<_RepsPicker> createState() => _RepsPickerState();
}

class _Chip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Chip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
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
              children:
              List.generate(50, (i) => Center(child: Text('${i + 1}'))),
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