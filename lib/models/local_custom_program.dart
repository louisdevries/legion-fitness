class LocalExerciseEntry {
  final int exerciseId;
  final String exerciseName;
  final String mediaUrl;
  final String coachingCues;
  final int sets;
  final int minQuantity;
  final int maxQuantity;
  final String durationType;

  LocalExerciseEntry({
    required this.exerciseId,
    required this.exerciseName,
    this.mediaUrl = '',
    this.coachingCues = '',
    required this.sets,
    required this.minQuantity,
    required this.maxQuantity,
    required this.durationType,
  });

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'mediaUrl': mediaUrl,
        'coachingCues': coachingCues,
        'sets': sets,
        'minQuantity': minQuantity,
        'maxQuantity': maxQuantity,
        'durationType': durationType,
      };

  factory LocalExerciseEntry.fromJson(Map<String, dynamic> j) =>
      LocalExerciseEntry(
        exerciseId: j['exerciseId'] as int,
        exerciseName: j['exerciseName'] as String,
        mediaUrl: j['mediaUrl'] as String? ?? '',
        coachingCues: j['coachingCues'] as String? ?? '',
        sets: j['sets'] as int,
        minQuantity: j['minQuantity'] as int,
        maxQuantity: j['maxQuantity'] as int,
        durationType: j['durationType'] as String,
      );

  Map<String, dynamic> toExerciseMap(String category) => {
        'id': exerciseId,
        'exercise_id': exerciseId,
        'name': exerciseName,
        'media_url': mediaUrl,
        'coaching_cues': coachingCues,
        'sets': sets,
        'set_quantities': List.filled(sets, minQuantity),
        'min_quantity': minQuantity,
        'max_quantity': maxQuantity,
        'duration_type': durationType,
        'category_name': category,
        'is_superset': false,
        'has_alternative': false,
        'alternative_exercise': null,
        'superset_partner': null,
      };
}

class LocalCustomProgram {
  final String id;
  final String name;
  final DateTime createdAt;
  final int weeks;
  final int daysPerWeek;
  final List<LocalExerciseEntry> warmup;
  final List<LocalExerciseEntry> main;
  final List<LocalExerciseEntry> cooldown;
  // Completed sessions stored as "week-day" strings e.g. "1-1", "2-3"
  final List<String> completedSessions;

  LocalCustomProgram({
    required this.id,
    required this.name,
    required this.createdAt,
    this.weeks = 4,
    this.daysPerWeek = 3,
    required this.warmup,
    required this.main,
    required this.cooldown,
    this.completedSessions = const [],
  });

  int get totalExercises => warmup.length + main.length + cooldown.length;

  bool isDone(int week, int day) =>
      completedSessions.contains('$week-$day');

  bool get isComplete {
    for (int w = 1; w <= weeks; w++) {
      for (int d = 1; d <= daysPerWeek; d++) {
        if (!isDone(w, d)) return false;
      }
    }
    return true;
  }

  int get nextWeek {
    for (int w = 1; w <= weeks; w++) {
      for (int d = 1; d <= daysPerWeek; d++) {
        if (!isDone(w, d)) return w;
      }
    }
    return weeks;
  }

  int get nextDay {
    for (int w = 1; w <= weeks; w++) {
      for (int d = 1; d <= daysPerWeek; d++) {
        if (!isDone(w, d)) return d;
      }
    }
    return daysPerWeek;
  }

  bool isDayLocked(int week, int day) {
    if (week == 1 && day == 1) return false;
    if (day == 1) {
      // Week unlocks when all days of the previous week are done.
      for (int d = 1; d <= daysPerWeek; d++) {
        if (!isDone(week - 1, d)) return true;
      }
      return false;
    }
    return !isDone(week, day - 1);
  }

  LocalCustomProgram copyWithCompleted(int week, int day) {
    final key = '$week-$day';
    if (completedSessions.contains(key)) return this;
    return LocalCustomProgram(
      id: id,
      name: name,
      createdAt: createdAt,
      weeks: weeks,
      daysPerWeek: daysPerWeek,
      warmup: warmup,
      main: main,
      cooldown: cooldown,
      completedSessions: [...completedSessions, key],
    );
  }

  // Converts the program's exercises into the map format expected by
  // ExercisePreviewScreen / ExerciseRunnerScreen.
  List<Map<String, dynamic>> toExerciseMaps() {
    return [
      ...warmup.map((e) => e.toExerciseMap('warm-up')),
      ...main.map((e) => e.toExerciseMap('main')),
      ...cooldown.map((e) => e.toExerciseMap('cool-down')),
    ];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'weeks': weeks,
        'daysPerWeek': daysPerWeek,
        'warmup': warmup.map((e) => e.toJson()).toList(),
        'main': main.map((e) => e.toJson()).toList(),
        'cooldown': cooldown.map((e) => e.toJson()).toList(),
        'completedSessions': completedSessions,
      };

  factory LocalCustomProgram.fromJson(Map<String, dynamic> j) =>
      LocalCustomProgram(
        id: j['id'] as String,
        name: j['name'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        weeks: j['weeks'] as int? ?? 4,
        daysPerWeek: j['daysPerWeek'] as int? ?? 3,
        warmup: (j['warmup'] as List)
            .map((e) => LocalExerciseEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        main: (j['main'] as List)
            .map((e) => LocalExerciseEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        cooldown: (j['cooldown'] as List)
            .map((e) => LocalExerciseEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        completedSessions: (j['completedSessions'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );
}
