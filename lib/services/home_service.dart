import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/home_state.dart';
import 'dart:developer' as developer;

class HomeService {
  final supabase = Supabase.instance.client;

  Future<HomeState> loadHomeData() async {
    final prefs = await SharedPreferences.getInstance();
    final programId = prefs.getInt('active_program_id');

    if (programId == null) {
      return HomeState(isLoading: false);
    }

    final programInfo = await _loadProgramInfo(programId);
    final progressData = await _loadProgress(programId);

    await prefs.setInt('active_week_number', progressData.currentWeek);

    return HomeState(
      programId: programId,
      currentWeek: progressData.currentWeek,
      programName: programInfo['name'],
      programImage: programInfo['image'],
      completedDays: progressData.completedDays,
      completedWorkoutDates: progressData.completedWorkoutDates,
      nextWeek: progressData.nextWeek,
      nextDay: progressData.nextDay,
      programProgress: progressData.programProgress,
      weekProgress: progressData.weekProgress,
      isLoading: false,
    );
  }

  Future<Map<String, String?>> _loadProgramInfo(int programId) async {
    final data = await supabase
        .from('fitness_programs')
        .select('name, image_url')
        .eq('id', programId)
        .maybeSingle();

    return {
      'name': data?['name'] as String?,
      'image': data?['image_url'] as String?,
    };
  }

  Future<_ProgressData> _loadProgress(int programId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        developer.log("No user logged in");
        return _ProgressData();
      }

      final allExercisesData = await supabase
          .from('program_exercises')
          .select('id, week_number, day_number')
          .eq('program_id', programId)
          .order('week_number', ascending: true)
          .order('day_number', ascending: true);

      if ((allExercisesData as List).isEmpty) {
        developer.log("No exercises found for program $programId");
        return _ProgressData();
      }

      final allExercises = (allExercisesData)
          .map((e) => {
        'id': e['id'],
        'week': (e['week_number'] as num).toInt(),
        'day': (e['day_number'] as num).toInt(),
      })
          .toList();

      final exerciseDistribution = _getExerciseDistribution(allExercises);
      developer.log("Exercise distribution by week/day: $exerciseDistribution");

      final exercisesByDay = _groupExercisesByDay(allExercises);

      final completedLogsData = await supabase
          .from('exercise_completions')
          .select('week_number, day_number, exercise_id, completed_at')
          .eq('user_id', user.id)
          .eq('program_id', programId);

      final completionData = _analyzeCompletionData(
        completedLogsData as List,
        exercisesByDay,
      );

      final nextWorkout = await _findNextWorkout(
        exercisesByDay: exercisesByDay,
        completedCountByDay: completionData.countByDay,
        programId: programId,
      );

      final progressMetrics = await _calculateProgress(
        programId: programId,
        exercisesByDay: exercisesByDay,
        completedCountByDay: completionData.countByDay,
        completedWorkoutsByWeek: completionData.completedByWeek,
        currentWeek: nextWorkout.week ?? 1,
        workoutDates: completionData.workoutDates,
      );

      return _ProgressData(
        currentWeek: progressMetrics.currentWeek,
        nextWeek: nextWorkout.week,
        nextDay: nextWorkout.day,
        completedDays: progressMetrics.completedDays,
        completedWorkoutDates: completionData.workoutDates,
        programProgress: progressMetrics.programProgress,
        weekProgress: progressMetrics.weekProgress,
      );
    } catch (e, stack) {
      developer.log("ERROR in _loadProgress", error: e, stackTrace: stack);
      return _ProgressData();
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupExercisesByDay(
      List<Map<String, dynamic>> exercises) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final e in exercises) {
      final key = "${e['week']}-${e['day']}";
      grouped.putIfAbsent(key, () => []).add(e);
    }
    return grouped;
  }

  Map<int, Map<int, int>> _getExerciseDistribution(
      List<Map<String, dynamic>> exercises) {
    final Map<int, Map<int, int>> distribution = {};
    for (final e in exercises) {
      final week = e['week'] as int;
      final day = e['day'] as int;
      distribution.putIfAbsent(week, () => {});
      distribution[week]![day] = (distribution[week]![day] ?? 0) + 1;
    }
    return distribution;
  }

  _CompletionData _analyzeCompletionData(
      List logs,
      Map<String, List<Map<String, dynamic>>> exercisesByDay,
      ) {
    final Map<String, Set<int>> completedExercisesByDay = {};
    final Set<String> workoutDates = {};

    for (final log in logs) {
      final week = (log['week_number'] as num?)?.toInt();
      final day = (log['day_number'] as num?)?.toInt();
      final exerciseId = (log['exercise_id'] as num?)?.toInt();

      if (week == null || day == null || exerciseId == null) continue;

      final key = "$week-$day";
      completedExercisesByDay.putIfAbsent(key, () => <int>{});
      completedExercisesByDay[key]!.add(exerciseId);

      if (log['completed_at'] != null) {
        final date = DateTime.parse(log['completed_at']);
        workoutDates.add(date.toIso8601String().substring(0, 10));
      }
    }

    final Map<String, int> countByDay = {
      for (final e in completedExercisesByDay.entries) e.key: e.value.length
    };

    final Map<int, Set<int>> completedByWeek = {};

    countByDay.forEach((key, completedCount) {
      final exercises = exercisesByDay[key];
      final total = exercises?.length ?? 0;

      if (total > 0 && completedCount >= total) {
        final parts = key.split('-');
        final week = int.parse(parts[0]);
        final day = int.parse(parts[1]);
        completedByWeek.putIfAbsent(week, () => {}).add(day);
      }
    });

    return _CompletionData(
      countByDay: countByDay,
      firstCompletionByDay: {},
      workoutDates: workoutDates,
      completedByWeek: completedByWeek,
    );
  }

  Future<_NextWorkout> _findNextWorkout({
    required Map<String, List<Map<String, dynamic>>> exercisesByDay,
    required Map<String, int> completedCountByDay,
    required int programId,
  }) async {
    int? nextWeek;
    int? nextDay;

    final sortedKeys = exercisesByDay.keys.toList()
      ..sort((a, b) {
        final aParts = a.split('-').map(int.parse).toList();
        final bParts = b.split('-').map(int.parse).toList();
        if (aParts[0] != bParts[0]) return aParts[0] - bParts[0];
        return aParts[1] - bParts[1];
      });

    for (final key in sortedKeys) {
      final exercises = exercisesByDay[key]!;
      final completed = completedCountByDay[key] ?? 0;
      final isComplete = completed >= exercises.length;

      if (!isComplete) {
        final parts = key.split('-');
        nextWeek = int.parse(parts[0]);
        nextDay = int.parse(parts[1]);
        break;
      }
    }

    if (nextWeek == null) {
      final programData = await supabase
          .from('fitness_programs')
          .select('weeks')
          .eq('id', programId)
          .maybeSingle();

      final totalWeeks = programData?['weeks'] as int? ?? 6;

      int highestCompletedWeek = 1;
      final weekPattern = RegExp(r'^(\d+)-\d+$');
      for (final key in completedCountByDay.keys) {
        final match = weekPattern.firstMatch(key);
        if (match != null) {
          final week = int.parse(match.group(1)!);
          if (week > highestCompletedWeek) highestCompletedWeek = week;
        }
      }

      final daysPerWeek =
          exercisesByDay.keys.where((k) => k.startsWith('1-')).length;

      int completedDaysInHighestWeek = 0;
      for (int day = 1; day <= daysPerWeek; day++) {
        final key = '$highestCompletedWeek-$day';
        final completed = completedCountByDay[key] ?? 0;
        if (completed > 0) completedDaysInHighestWeek++;
      }

      if (completedDaysInHighestWeek >= daysPerWeek) {
        if (highestCompletedWeek < totalWeeks) {
          nextWeek = highestCompletedWeek + 1;
          nextDay = 1;
        }
      } else {
        for (int day = 1; day <= daysPerWeek; day++) {
          final key = '$highestCompletedWeek-$day';
          final completed = completedCountByDay[key] ?? 0;
          if (completed == 0) {
            nextWeek = highestCompletedWeek;
            nextDay = day;
            break;
          }
        }
      }
    }

    return _NextWorkout(week: nextWeek, day: nextDay);
  }

  Future<_ProgressMetrics> _calculateProgress({
    required int programId,
    required Map<String, List<Map<String, dynamic>>> exercisesByDay,
    required Map<String, int> completedCountByDay,
    required Map<int, Set<int>> completedWorkoutsByWeek,
    required int currentWeek,
    required Set<String> workoutDates,
  }) async {
    final programData = await supabase
        .from('fitness_programs')
        .select('weeks')
        .eq('id', programId)
        .maybeSingle();

    final totalWeeks = programData?['weeks'] as int? ?? 6;
    final daysPerWeek =
        exercisesByDay.keys.where((k) => k.startsWith('1-')).length;
    final totalExpectedWorkoutSessions = totalWeeks * daysPerWeek;

    final Set<String> completedSessions = {};
    for (final weekEntry in completedWorkoutsByWeek.entries) {
      final week = weekEntry.key;
      for (final day in weekEntry.value) {
        completedSessions.add("$week-$day");
      }
    }

    int completedWorkoutSessions = completedSessions.length;

    for (int week = 2; week <= totalWeeks; week++) {
      for (int day = 1; day <= daysPerWeek; day++) {
        final key = '$week-$day';
        final completed = completedCountByDay[key] ?? 0;
        final isAlreadyCounted =
            completedWorkoutsByWeek[week]?.contains(day) ?? false;
        if (completed > 0 && !isAlreadyCounted) {
          final week1DayKey = '1-$day';
          final week1DayExercises = exercisesByDay[week1DayKey]?.length ?? 10;
          if (completed >= week1DayExercises) completedWorkoutSessions++;
        }
      }
    }

    final programProgress = totalExpectedWorkoutSessions > 0
        ? completedWorkoutSessions / totalExpectedWorkoutSessions
        : 0.0;

    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final Map<int, bool> completedDays = {};
    for (int i = 1; i <= 7; i++) {
      final dayDate = startOfWeek.add(Duration(days: i - 1));
      final dateStr = dayDate.toIso8601String().substring(0, 10);
      if (workoutDates.contains(dateStr)) completedDays[i] = true;
    }

    return _ProgressMetrics(
      currentWeek: currentWeek,
      completedDays: completedDays,
      programProgress: programProgress,
      weekProgress: completedDays.length / 7.0,
    );
  }

  // ── Fetch alternative exercise data ─────────────────────────────
  Future<Map<String, dynamic>?> _fetchAlternativeExercise({
    required int altExerciseId,
    required int sets,
    required int minQ,
    required int maxQ,
    required String durationType,
  }) async {
    final altEx = await supabase
        .from('exercises')
        .select('id, name, media_url, coaching_cues')
        .eq('id', altExerciseId)
        .maybeSingle();

    if (altEx == null) return null;

    final altName = altEx['name']?.toString() ?? '';
    final altMedia = altEx['media_url']?.toString() ?? '';

    developer.log('✅ Alternative $altExerciseId: name="$altName"');

    return {
      'id': altEx['id'],
      'name': altName.isNotEmpty ? altName : 'Alternative Exercise',
      'media_url': altMedia,
      'coaching_cues': altEx['coaching_cues'] ?? '',
      'sets': sets,
      'min_quantity': minQ,
      'max_quantity': maxQ,
      'duration_type': durationType,
      'set_quantities': null,
    };
  }

  // ── Fetch superset partner exercise data ─────────────────────────
  Future<Map<String, dynamic>?> _fetchSupersetPartner({
    required int supersetExerciseId,
    required int sets,
    required List<int> setQuantities,
    required String durationType,
    required int minQ,
    required int maxQ,
  }) async {
    final ex = await supabase
        .from('exercises')
        .select('id, name, media_url, coaching_cues')
        .eq('id', supersetExerciseId)
        .maybeSingle();

    if (ex == null) return null;

    final name = ex['name']?.toString() ?? '';
    final media = ex['media_url']?.toString() ?? '';

    developer.log('✅ Superset partner $supersetExerciseId: name="$name"');

    return {
      'id': ex['id'],
      'exercise_id': supersetExerciseId,
      'name': name.isNotEmpty ? name : 'Superset Exercise',
      'media_url': media,
      'coaching_cues': ex['coaching_cues'] ?? '',
      'sets': sets,
      'set_quantities': setQuantities,
      'min_quantity': minQ,
      'max_quantity': maxQ,
      'duration_type': durationType,
    };
  }
  // ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchWeek1Exercises({
    required int programId,
    required int weekNumber,
    required int dayNumber,
  }) async {
    final exercisesData = await supabase
        .from('program_exercises')
        .select('''
          *,
          exercises (
            id,
            name,
            media_url,
            coaching_cues,
            exercise_category_association!exercise_category_association_exercise_id_fkey(
              category_id,
              exercise_categories!exercise_category_association_category_id_fkey(id, name)
            )
          )
        ''')
        .eq('program_id', programId)
        .eq('week_number', weekNumber)
        .eq('day_number', dayNumber)
        .order('id');

    final exercises = <Map<String, dynamic>>[];

    for (final programEx in exercisesData as List) {
      final exerciseData = programEx['exercises'] as Map<String, dynamic>?;
      if (exerciseData == null) continue;

      final exerciseId = programEx['exercise_id'] as int;

      final detailsData = await supabase
          .from('program_exercise_details')
          .select()
          .eq('program_exercise_id', programEx['id'])
          .maybeSingle();

      final detail = detailsData != null
          ? ProgramExerciseDetailInline.fromMap(detailsData)
          : null;

      final categoryAssociations =
      exerciseData['exercise_category_association'] as List?;
      int? categoryId;
      String? categoryName;

      if (categoryAssociations != null && categoryAssociations.isNotEmpty) {
        final catData = categoryAssociations.first['exercise_categories'];
        categoryId = catData?['id'] as int?;
        categoryName = (catData?['name'] as String?)?.toLowerCase();
      }

      final sets = detail?.sets ?? 1;
      final minQ = detail?.minQuantity ?? 0;
      final maxQ = detail?.maxQuantity ?? minQ;
      final durationType = detail?.durationType ?? 'reps';

      // Resolve per-set quantities — use set_quantities if available,
      // otherwise fall back to min_quantity repeated for each set
      final setQuantities = detail?.resolvedSetQuantities() ??
          List.filled(sets, minQ);

      // ── Alternative ──────────────────────────────────────────────
      final altExerciseId = detail?.alternativeExerciseId;
      Map<String, dynamic>? alternativeExercise;

      if (altExerciseId != null) {
        alternativeExercise = await _fetchAlternativeExercise(
          altExerciseId: altExerciseId,
          sets: detail?.alternativeSet ?? sets,
          minQ: detail?.minAlternative ?? minQ,
          maxQ: detail?.maxAlternative ?? maxQ,
          durationType: detail?.alternativeDurationType ?? durationType,
        );
      }

      // ── Superset partner ─────────────────────────────────────────
      final supersetExerciseId = detail?.supersetExerciseId;
      Map<String, dynamic>? supersetPartner;

      if (supersetExerciseId != null) {
        final supersetSetQty = detail?.resolvedSupersetSetQuantities() ??
            List.filled(sets, minQ);

        supersetPartner = await _fetchSupersetPartner(
          supersetExerciseId: supersetExerciseId,
          sets: sets,
          setQuantities: supersetSetQty,
          durationType: durationType,
          minQ: minQ,
          maxQ: maxQ,
        );
      }
      // ────────────────────────────────────────────────────────────

      exercises.add({
        'id': exerciseId,
        'exercise_id': exerciseId,
        'program_exercise_id': programEx['id'],
        'name': exerciseData['name'],
        'media_url': exerciseData['media_url'],
        'coaching_cues': exerciseData['coaching_cues'],
        'sets': sets,
        'set_quantities': setQuantities,
        'min_quantity': minQ,
        'max_quantity': maxQ,
        'duration_type': durationType,
        'is_superset': detail?.isSuperset ?? false,
        'has_alternative': altExerciseId != null,
        'alternative_exercise_id': altExerciseId,
        'alternative_exercise': alternativeExercise,
        'superset_exercise_id': supersetExerciseId,
        'superset_partner': supersetPartner, // ← populated map
        'category_id': categoryId,
        'category_name': categoryName,
      });
    }

    return exercises;
  }
}

// ── Inline detail parser (avoids importing model just for this) ───
class ProgramExerciseDetailInline {
  final int sets;
  final int minQuantity;
  final int maxQuantity;
  final String durationType;
  final bool isSuperset;
  final bool hasAlternative;
  final int? alternativeExerciseId;
  final int? alternativeSet;
  final int? minAlternative;
  final int? maxAlternative;
  final String? alternativeDurationType;
  final List<int>? setQuantities;
  final int? supersetExerciseId;
  final List<int>? supersetSetQuantities;

  ProgramExerciseDetailInline({
    required this.sets,
    required this.minQuantity,
    required this.maxQuantity,
    required this.durationType,
    required this.isSuperset,
    required this.hasAlternative,
    this.alternativeExerciseId,
    this.alternativeSet,
    this.minAlternative,
    this.maxAlternative,
    this.alternativeDurationType,
    this.setQuantities,
    this.supersetExerciseId,
    this.supersetSetQuantities,
  });

  List<int> resolvedSetQuantities() {
    if (setQuantities != null && setQuantities!.isNotEmpty) {
      return setQuantities!;
    }
    return List.filled(sets, minQuantity);
  }

  List<int> resolvedSupersetSetQuantities() {
    if (supersetSetQuantities != null && supersetSetQuantities!.isNotEmpty) {
      return supersetSetQuantities!;
    }
    return List.filled(sets, minQuantity);
  }

  factory ProgramExerciseDetailInline.fromMap(Map<String, dynamic> map) {
    return ProgramExerciseDetailInline(
      sets: map['sets'] ?? 1,
      minQuantity: map['min_quantity'] ?? 0,
      maxQuantity: map['max_quantity'] ?? map['min_quantity'] ?? 0,
      durationType: map['duration_type'] ?? 'reps',
      isSuperset: map['is_superset'] ?? false,
      hasAlternative: map['has_alternative'] ?? false,
      alternativeExerciseId: map['alternative_exercise_id'],
      alternativeSet: map['alternative_sets'],
      minAlternative: map['min_alternative'],
      maxAlternative: map['max_alternative'],
      alternativeDurationType: map['alternative_duration_type'],
      setQuantities: _parseIntArray(map['set_quantities']),
      supersetExerciseId: map['superset_exercise_id'],
      supersetSetQuantities: _parseIntArray(map['superset_set_quantities']),
    );
  }

  static List<int>? _parseIntArray(dynamic value) {
    if (value == null) return null;
    if (value is List) return value.map((e) => (e as num).toInt()).toList();
    return null;
  }
}

// ── Private data classes (unchanged) ────────────────────────────
class _ProgressData {
  final int currentWeek;
  final int? nextWeek;
  final int? nextDay;
  final Map<int, bool> completedDays;
  final Set<String> completedWorkoutDates;
  final double programProgress;
  final double weekProgress;

  _ProgressData({
    this.currentWeek = 1,
    this.nextWeek,
    this.nextDay,
    this.completedDays = const {},
    this.completedWorkoutDates = const {},
    this.programProgress = 0.0,
    this.weekProgress = 0.0,
  });
}

class _CompletionData {
  final Map<String, int> countByDay;
  final Map<String, DateTime> firstCompletionByDay;
  final Set<String> workoutDates;
  final Map<int, Set<int>> completedByWeek;

  _CompletionData({
    required this.countByDay,
    required this.firstCompletionByDay,
    required this.workoutDates,
    required this.completedByWeek,
  });
}

class _NextWorkout {
  final int? week;
  final int? day;
  _NextWorkout({this.week, this.day});
}

class _ProgressMetrics {
  final int currentWeek;
  final Map<int, bool> completedDays;
  final double programProgress;
  final double weekProgress;

  _ProgressMetrics({
    required this.currentWeek,
    required this.completedDays,
    required this.programProgress,
    required this.weekProgress,
  });
}