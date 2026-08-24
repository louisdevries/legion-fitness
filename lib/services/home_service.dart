import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/home_state.dart';
import 'dart:developer' as developer;
import '../utils/user_prefs.dart';
import 'program_completion_service.dart';

class HomeService {
  final supabase = Supabase.instance.client;

  Future<HomeState> loadHomeData() async {
    final programId = await UserPrefs.getInt('active_program_id');

    if (programId == null) {
      return HomeState(isLoading: false);
    }

    final programInfo = await _loadProgramInfo(programId);
    final progressData = await _loadProgress(programId);

    await UserPrefs.setInt('active_week_number', progressData.currentWeek);
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

      final completion = await ProgramCompletionService.load(programId);

      // Completed days for the current calendar week (Mon-Sun strip).
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final Map<int, bool> completedDays = {};
      for (int i = 1; i <= 7; i++) {
        final dayDate = startOfWeek.add(Duration(days: i - 1));
        final dateStr = dayDate.toIso8601String().substring(0, 10);
        if (completion.workoutDates.contains(dateStr)) completedDays[i] = true;
      }

      final totalExpectedWorkoutSessions =
          completion.totalWeeks * completion.daysPerWeek;
      final completedWorkoutSessions = completion.completedDaysByWeek.values
          .fold<int>(0, (sum, days) => sum + days.length);
      final programProgress = totalExpectedWorkoutSessions > 0
          ? (completedWorkoutSessions / totalExpectedWorkoutSessions)
              .clamp(0.0, 1.0)
          : 0.0;

      // When the program is fully complete, nextWeek is null — fall back
      // to the last week for display purposes.
      final currentWeek = completion.nextWeek ?? completion.totalWeeks;

      return _ProgressData(
        currentWeek: currentWeek,
        nextWeek: completion.nextWeek,
        nextDay: completion.nextDay,
        completedDays: completedDays,
        completedWorkoutDates: completion.workoutDates,
        programProgress: programProgress,
        weekProgress: completedDays.length / 7.0,
      );
    } catch (e, stack) {
      developer.log("ERROR in _loadProgress", error: e, stackTrace: stack);
      return _ProgressData();
    }
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
