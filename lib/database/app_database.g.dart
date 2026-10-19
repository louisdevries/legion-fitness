// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ExerciseLogsTable extends ExerciseLogs
    with TableInfo<$ExerciseLogsTable, ExerciseLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExerciseLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _programIdMeta = const VerificationMeta(
    'programId',
  );
  @override
  late final GeneratedColumn<int> programId = GeneratedColumn<int>(
    'program_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<int> exerciseId = GeneratedColumn<int>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weekNumberMeta = const VerificationMeta(
    'weekNumber',
  );
  @override
  late final GeneratedColumn<int> weekNumber = GeneratedColumn<int>(
    'week_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayNumberMeta = const VerificationMeta(
    'dayNumber',
  );
  @override
  late final GeneratedColumn<int> dayNumber = GeneratedColumn<int>(
    'day_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setIndexMeta = const VerificationMeta(
    'setIndex',
  );
  @override
  late final GeneratedColumn<int> setIndex = GeneratedColumn<int>(
    'set_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repsCompletedMeta = const VerificationMeta(
    'repsCompleted',
  );
  @override
  late final GeneratedColumn<int> repsCompleted = GeneratedColumn<int>(
    'reps_completed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _secondsMeta = const VerificationMeta(
    'seconds',
  );
  @override
  late final GeneratedColumn<int> seconds = GeneratedColumn<int>(
    'seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
    'weight',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    programId,
    exerciseId,
    weekNumber,
    dayNumber,
    setIndex,
    repsCompleted,
    reps,
    seconds,
    weight,
    createdAt,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExerciseLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('program_id')) {
      context.handle(
        _programIdMeta,
        programId.isAcceptableOrUnknown(data['program_id']!, _programIdMeta),
      );
    } else if (isInserting) {
      context.missing(_programIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('week_number')) {
      context.handle(
        _weekNumberMeta,
        weekNumber.isAcceptableOrUnknown(data['week_number']!, _weekNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_weekNumberMeta);
    }
    if (data.containsKey('day_number')) {
      context.handle(
        _dayNumberMeta,
        dayNumber.isAcceptableOrUnknown(data['day_number']!, _dayNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_dayNumberMeta);
    }
    if (data.containsKey('set_index')) {
      context.handle(
        _setIndexMeta,
        setIndex.isAcceptableOrUnknown(data['set_index']!, _setIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_setIndexMeta);
    }
    if (data.containsKey('reps_completed')) {
      context.handle(
        _repsCompletedMeta,
        repsCompleted.isAcceptableOrUnknown(
          data['reps_completed']!,
          _repsCompletedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_repsCompletedMeta);
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('seconds')) {
      context.handle(
        _secondsMeta,
        seconds.isAcceptableOrUnknown(data['seconds']!, _secondsMeta),
      );
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExerciseLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      programId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}program_id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exercise_id'],
      )!,
      weekNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}week_number'],
      )!,
      dayNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_number'],
      )!,
      setIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}set_index'],
      )!,
      repsCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps_completed'],
      )!,
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      ),
      seconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seconds'],
      ),
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $ExerciseLogsTable createAlias(String alias) {
    return $ExerciseLogsTable(attachedDatabase, alias);
  }
}

class ExerciseLog extends DataClass implements Insertable<ExerciseLog> {
  final String id;
  final int programId;
  final int exerciseId;
  final int weekNumber;
  final int dayNumber;
  final int setIndex;
  final int repsCompleted;
  final int? reps;
  final int? seconds;
  final double? weight;
  final DateTime createdAt;
  final bool synced;
  const ExerciseLog({
    required this.id,
    required this.programId,
    required this.exerciseId,
    required this.weekNumber,
    required this.dayNumber,
    required this.setIndex,
    required this.repsCompleted,
    this.reps,
    this.seconds,
    this.weight,
    required this.createdAt,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['program_id'] = Variable<int>(programId);
    map['exercise_id'] = Variable<int>(exerciseId);
    map['week_number'] = Variable<int>(weekNumber);
    map['day_number'] = Variable<int>(dayNumber);
    map['set_index'] = Variable<int>(setIndex);
    map['reps_completed'] = Variable<int>(repsCompleted);
    if (!nullToAbsent || reps != null) {
      map['reps'] = Variable<int>(reps);
    }
    if (!nullToAbsent || seconds != null) {
      map['seconds'] = Variable<int>(seconds);
    }
    if (!nullToAbsent || weight != null) {
      map['weight'] = Variable<double>(weight);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  ExerciseLogsCompanion toCompanion(bool nullToAbsent) {
    return ExerciseLogsCompanion(
      id: Value(id),
      programId: Value(programId),
      exerciseId: Value(exerciseId),
      weekNumber: Value(weekNumber),
      dayNumber: Value(dayNumber),
      setIndex: Value(setIndex),
      repsCompleted: Value(repsCompleted),
      reps: reps == null && nullToAbsent ? const Value.absent() : Value(reps),
      seconds: seconds == null && nullToAbsent
          ? const Value.absent()
          : Value(seconds),
      weight: weight == null && nullToAbsent
          ? const Value.absent()
          : Value(weight),
      createdAt: Value(createdAt),
      synced: Value(synced),
    );
  }

  factory ExerciseLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseLog(
      id: serializer.fromJson<String>(json['id']),
      programId: serializer.fromJson<int>(json['programId']),
      exerciseId: serializer.fromJson<int>(json['exerciseId']),
      weekNumber: serializer.fromJson<int>(json['weekNumber']),
      dayNumber: serializer.fromJson<int>(json['dayNumber']),
      setIndex: serializer.fromJson<int>(json['setIndex']),
      repsCompleted: serializer.fromJson<int>(json['repsCompleted']),
      reps: serializer.fromJson<int?>(json['reps']),
      seconds: serializer.fromJson<int?>(json['seconds']),
      weight: serializer.fromJson<double?>(json['weight']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'programId': serializer.toJson<int>(programId),
      'exerciseId': serializer.toJson<int>(exerciseId),
      'weekNumber': serializer.toJson<int>(weekNumber),
      'dayNumber': serializer.toJson<int>(dayNumber),
      'setIndex': serializer.toJson<int>(setIndex),
      'repsCompleted': serializer.toJson<int>(repsCompleted),
      'reps': serializer.toJson<int?>(reps),
      'seconds': serializer.toJson<int?>(seconds),
      'weight': serializer.toJson<double?>(weight),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  ExerciseLog copyWith({
    String? id,
    int? programId,
    int? exerciseId,
    int? weekNumber,
    int? dayNumber,
    int? setIndex,
    int? repsCompleted,
    Value<int?> reps = const Value.absent(),
    Value<int?> seconds = const Value.absent(),
    Value<double?> weight = const Value.absent(),
    DateTime? createdAt,
    bool? synced,
  }) => ExerciseLog(
    id: id ?? this.id,
    programId: programId ?? this.programId,
    exerciseId: exerciseId ?? this.exerciseId,
    weekNumber: weekNumber ?? this.weekNumber,
    dayNumber: dayNumber ?? this.dayNumber,
    setIndex: setIndex ?? this.setIndex,
    repsCompleted: repsCompleted ?? this.repsCompleted,
    reps: reps.present ? reps.value : this.reps,
    seconds: seconds.present ? seconds.value : this.seconds,
    weight: weight.present ? weight.value : this.weight,
    createdAt: createdAt ?? this.createdAt,
    synced: synced ?? this.synced,
  );
  ExerciseLog copyWithCompanion(ExerciseLogsCompanion data) {
    return ExerciseLog(
      id: data.id.present ? data.id.value : this.id,
      programId: data.programId.present ? data.programId.value : this.programId,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      weekNumber: data.weekNumber.present
          ? data.weekNumber.value
          : this.weekNumber,
      dayNumber: data.dayNumber.present ? data.dayNumber.value : this.dayNumber,
      setIndex: data.setIndex.present ? data.setIndex.value : this.setIndex,
      repsCompleted: data.repsCompleted.present
          ? data.repsCompleted.value
          : this.repsCompleted,
      reps: data.reps.present ? data.reps.value : this.reps,
      seconds: data.seconds.present ? data.seconds.value : this.seconds,
      weight: data.weight.present ? data.weight.value : this.weight,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseLog(')
          ..write('id: $id, ')
          ..write('programId: $programId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('weekNumber: $weekNumber, ')
          ..write('dayNumber: $dayNumber, ')
          ..write('setIndex: $setIndex, ')
          ..write('repsCompleted: $repsCompleted, ')
          ..write('reps: $reps, ')
          ..write('seconds: $seconds, ')
          ..write('weight: $weight, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    programId,
    exerciseId,
    weekNumber,
    dayNumber,
    setIndex,
    repsCompleted,
    reps,
    seconds,
    weight,
    createdAt,
    synced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseLog &&
          other.id == this.id &&
          other.programId == this.programId &&
          other.exerciseId == this.exerciseId &&
          other.weekNumber == this.weekNumber &&
          other.dayNumber == this.dayNumber &&
          other.setIndex == this.setIndex &&
          other.repsCompleted == this.repsCompleted &&
          other.reps == this.reps &&
          other.seconds == this.seconds &&
          other.weight == this.weight &&
          other.createdAt == this.createdAt &&
          other.synced == this.synced);
}

class ExerciseLogsCompanion extends UpdateCompanion<ExerciseLog> {
  final Value<String> id;
  final Value<int> programId;
  final Value<int> exerciseId;
  final Value<int> weekNumber;
  final Value<int> dayNumber;
  final Value<int> setIndex;
  final Value<int> repsCompleted;
  final Value<int?> reps;
  final Value<int?> seconds;
  final Value<double?> weight;
  final Value<DateTime> createdAt;
  final Value<bool> synced;
  final Value<int> rowid;
  const ExerciseLogsCompanion({
    this.id = const Value.absent(),
    this.programId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.weekNumber = const Value.absent(),
    this.dayNumber = const Value.absent(),
    this.setIndex = const Value.absent(),
    this.repsCompleted = const Value.absent(),
    this.reps = const Value.absent(),
    this.seconds = const Value.absent(),
    this.weight = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExerciseLogsCompanion.insert({
    required String id,
    required int programId,
    required int exerciseId,
    required int weekNumber,
    required int dayNumber,
    required int setIndex,
    required int repsCompleted,
    this.reps = const Value.absent(),
    this.seconds = const Value.absent(),
    this.weight = const Value.absent(),
    required DateTime createdAt,
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       programId = Value(programId),
       exerciseId = Value(exerciseId),
       weekNumber = Value(weekNumber),
       dayNumber = Value(dayNumber),
       setIndex = Value(setIndex),
       repsCompleted = Value(repsCompleted),
       createdAt = Value(createdAt);
  static Insertable<ExerciseLog> custom({
    Expression<String>? id,
    Expression<int>? programId,
    Expression<int>? exerciseId,
    Expression<int>? weekNumber,
    Expression<int>? dayNumber,
    Expression<int>? setIndex,
    Expression<int>? repsCompleted,
    Expression<int>? reps,
    Expression<int>? seconds,
    Expression<double>? weight,
    Expression<DateTime>? createdAt,
    Expression<bool>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (programId != null) 'program_id': programId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (weekNumber != null) 'week_number': weekNumber,
      if (dayNumber != null) 'day_number': dayNumber,
      if (setIndex != null) 'set_index': setIndex,
      if (repsCompleted != null) 'reps_completed': repsCompleted,
      if (reps != null) 'reps': reps,
      if (seconds != null) 'seconds': seconds,
      if (weight != null) 'weight': weight,
      if (createdAt != null) 'created_at': createdAt,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExerciseLogsCompanion copyWith({
    Value<String>? id,
    Value<int>? programId,
    Value<int>? exerciseId,
    Value<int>? weekNumber,
    Value<int>? dayNumber,
    Value<int>? setIndex,
    Value<int>? repsCompleted,
    Value<int?>? reps,
    Value<int?>? seconds,
    Value<double?>? weight,
    Value<DateTime>? createdAt,
    Value<bool>? synced,
    Value<int>? rowid,
  }) {
    return ExerciseLogsCompanion(
      id: id ?? this.id,
      programId: programId ?? this.programId,
      exerciseId: exerciseId ?? this.exerciseId,
      weekNumber: weekNumber ?? this.weekNumber,
      dayNumber: dayNumber ?? this.dayNumber,
      setIndex: setIndex ?? this.setIndex,
      repsCompleted: repsCompleted ?? this.repsCompleted,
      reps: reps ?? this.reps,
      seconds: seconds ?? this.seconds,
      weight: weight ?? this.weight,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (programId.present) {
      map['program_id'] = Variable<int>(programId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<int>(exerciseId.value);
    }
    if (weekNumber.present) {
      map['week_number'] = Variable<int>(weekNumber.value);
    }
    if (dayNumber.present) {
      map['day_number'] = Variable<int>(dayNumber.value);
    }
    if (setIndex.present) {
      map['set_index'] = Variable<int>(setIndex.value);
    }
    if (repsCompleted.present) {
      map['reps_completed'] = Variable<int>(repsCompleted.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (seconds.present) {
      map['seconds'] = Variable<int>(seconds.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseLogsCompanion(')
          ..write('id: $id, ')
          ..write('programId: $programId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('weekNumber: $weekNumber, ')
          ..write('dayNumber: $dayNumber, ')
          ..write('setIndex: $setIndex, ')
          ..write('repsCompleted: $repsCompleted, ')
          ..write('reps: $reps, ')
          ..write('seconds: $seconds, ')
          ..write('weight: $weight, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MealEntriesTable extends MealEntries
    with TableInfo<$MealEntriesTable, MealEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foodRemoteIdMeta = const VerificationMeta(
    'foodRemoteId',
  );
  @override
  late final GeneratedColumn<int> foodRemoteId = GeneratedColumn<int>(
    'food_remote_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mealTypeMeta = const VerificationMeta(
    'mealType',
  );
  @override
  late final GeneratedColumn<String> mealType = GeneratedColumn<String>(
    'meal_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gramsMeta = const VerificationMeta('grams');
  @override
  late final GeneratedColumn<double> grams = GeneratedColumn<double>(
    'grams',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loggedAtMeta = const VerificationMeta(
    'loggedAt',
  );
  @override
  late final GeneratedColumn<DateTime> loggedAt = GeneratedColumn<DateTime>(
    'logged_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foodSourceMeta = const VerificationMeta(
    'foodSource',
  );
  @override
  late final GeneratedColumn<String> foodSource = GeneratedColumn<String>(
    'food_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foodBarcodeMeta = const VerificationMeta(
    'foodBarcode',
  );
  @override
  late final GeneratedColumn<String> foodBarcode = GeneratedColumn<String>(
    'food_barcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _foodNameMeta = const VerificationMeta(
    'foodName',
  );
  @override
  late final GeneratedColumn<String> foodName = GeneratedColumn<String>(
    'food_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foodBrandMeta = const VerificationMeta(
    'foodBrand',
  );
  @override
  late final GeneratedColumn<String> foodBrand = GeneratedColumn<String>(
    'food_brand',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kcal100gMeta = const VerificationMeta(
    'kcal100g',
  );
  @override
  late final GeneratedColumn<double> kcal100g = GeneratedColumn<double>(
    'kcal100g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _protein100gMeta = const VerificationMeta(
    'protein100g',
  );
  @override
  late final GeneratedColumn<double> protein100g = GeneratedColumn<double>(
    'protein100g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _carbs100gMeta = const VerificationMeta(
    'carbs100g',
  );
  @override
  late final GeneratedColumn<double> carbs100g = GeneratedColumn<double>(
    'carbs100g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fat100gMeta = const VerificationMeta(
    'fat100g',
  );
  @override
  late final GeneratedColumn<double> fat100g = GeneratedColumn<double>(
    'fat100g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fiber100gMeta = const VerificationMeta(
    'fiber100g',
  );
  @override
  late final GeneratedColumn<double> fiber100g = GeneratedColumn<double>(
    'fiber100g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sugar100gMeta = const VerificationMeta(
    'sugar100g',
  );
  @override
  late final GeneratedColumn<double> sugar100g = GeneratedColumn<double>(
    'sugar100g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _salt100gMeta = const VerificationMeta(
    'salt100g',
  );
  @override
  late final GeneratedColumn<double> salt100g = GeneratedColumn<double>(
    'salt100g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _servingGMeta = const VerificationMeta(
    'servingG',
  );
  @override
  late final GeneratedColumn<double> servingG = GeneratedColumn<double>(
    'serving_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    foodRemoteId,
    mealType,
    grams,
    loggedAt,
    foodSource,
    foodBarcode,
    foodName,
    foodBrand,
    kcal100g,
    protein100g,
    carbs100g,
    fat100g,
    fiber100g,
    sugar100g,
    salt100g,
    servingG,
    synced,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MealEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('food_remote_id')) {
      context.handle(
        _foodRemoteIdMeta,
        foodRemoteId.isAcceptableOrUnknown(
          data['food_remote_id']!,
          _foodRemoteIdMeta,
        ),
      );
    }
    if (data.containsKey('meal_type')) {
      context.handle(
        _mealTypeMeta,
        mealType.isAcceptableOrUnknown(data['meal_type']!, _mealTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mealTypeMeta);
    }
    if (data.containsKey('grams')) {
      context.handle(
        _gramsMeta,
        grams.isAcceptableOrUnknown(data['grams']!, _gramsMeta),
      );
    } else if (isInserting) {
      context.missing(_gramsMeta);
    }
    if (data.containsKey('logged_at')) {
      context.handle(
        _loggedAtMeta,
        loggedAt.isAcceptableOrUnknown(data['logged_at']!, _loggedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_loggedAtMeta);
    }
    if (data.containsKey('food_source')) {
      context.handle(
        _foodSourceMeta,
        foodSource.isAcceptableOrUnknown(data['food_source']!, _foodSourceMeta),
      );
    } else if (isInserting) {
      context.missing(_foodSourceMeta);
    }
    if (data.containsKey('food_barcode')) {
      context.handle(
        _foodBarcodeMeta,
        foodBarcode.isAcceptableOrUnknown(
          data['food_barcode']!,
          _foodBarcodeMeta,
        ),
      );
    }
    if (data.containsKey('food_name')) {
      context.handle(
        _foodNameMeta,
        foodName.isAcceptableOrUnknown(data['food_name']!, _foodNameMeta),
      );
    } else if (isInserting) {
      context.missing(_foodNameMeta);
    }
    if (data.containsKey('food_brand')) {
      context.handle(
        _foodBrandMeta,
        foodBrand.isAcceptableOrUnknown(data['food_brand']!, _foodBrandMeta),
      );
    }
    if (data.containsKey('kcal100g')) {
      context.handle(
        _kcal100gMeta,
        kcal100g.isAcceptableOrUnknown(data['kcal100g']!, _kcal100gMeta),
      );
    } else if (isInserting) {
      context.missing(_kcal100gMeta);
    }
    if (data.containsKey('protein100g')) {
      context.handle(
        _protein100gMeta,
        protein100g.isAcceptableOrUnknown(
          data['protein100g']!,
          _protein100gMeta,
        ),
      );
    }
    if (data.containsKey('carbs100g')) {
      context.handle(
        _carbs100gMeta,
        carbs100g.isAcceptableOrUnknown(data['carbs100g']!, _carbs100gMeta),
      );
    }
    if (data.containsKey('fat100g')) {
      context.handle(
        _fat100gMeta,
        fat100g.isAcceptableOrUnknown(data['fat100g']!, _fat100gMeta),
      );
    }
    if (data.containsKey('fiber100g')) {
      context.handle(
        _fiber100gMeta,
        fiber100g.isAcceptableOrUnknown(data['fiber100g']!, _fiber100gMeta),
      );
    }
    if (data.containsKey('sugar100g')) {
      context.handle(
        _sugar100gMeta,
        sugar100g.isAcceptableOrUnknown(data['sugar100g']!, _sugar100gMeta),
      );
    }
    if (data.containsKey('salt100g')) {
      context.handle(
        _salt100gMeta,
        salt100g.isAcceptableOrUnknown(data['salt100g']!, _salt100gMeta),
      );
    }
    if (data.containsKey('serving_g')) {
      context.handle(
        _servingGMeta,
        servingG.isAcceptableOrUnknown(data['serving_g']!, _servingGMeta),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      foodRemoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}food_remote_id'],
      ),
      mealType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meal_type'],
      )!,
      grams: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grams'],
      )!,
      loggedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}logged_at'],
      )!,
      foodSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}food_source'],
      )!,
      foodBarcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}food_barcode'],
      ),
      foodName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}food_name'],
      )!,
      foodBrand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}food_brand'],
      ),
      kcal100g: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kcal100g'],
      )!,
      protein100g: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}protein100g'],
      ),
      carbs100g: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carbs100g'],
      ),
      fat100g: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fat100g'],
      ),
      fiber100g: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fiber100g'],
      ),
      sugar100g: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sugar100g'],
      ),
      salt100g: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}salt100g'],
      ),
      servingG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}serving_g'],
      ),
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $MealEntriesTable createAlias(String alias) {
    return $MealEntriesTable(attachedDatabase, alias);
  }
}

class MealEntry extends DataClass implements Insertable<MealEntry> {
  final String id;
  final int? foodRemoteId;
  final String mealType;
  final double grams;
  final DateTime loggedAt;
  final String foodSource;
  final String? foodBarcode;
  final String foodName;
  final String? foodBrand;
  final double kcal100g;
  final double? protein100g;
  final double? carbs100g;
  final double? fat100g;
  final double? fiber100g;
  final double? sugar100g;
  final double? salt100g;
  final double? servingG;
  final bool synced;
  final bool deleted;
  const MealEntry({
    required this.id,
    this.foodRemoteId,
    required this.mealType,
    required this.grams,
    required this.loggedAt,
    required this.foodSource,
    this.foodBarcode,
    required this.foodName,
    this.foodBrand,
    required this.kcal100g,
    this.protein100g,
    this.carbs100g,
    this.fat100g,
    this.fiber100g,
    this.sugar100g,
    this.salt100g,
    this.servingG,
    required this.synced,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || foodRemoteId != null) {
      map['food_remote_id'] = Variable<int>(foodRemoteId);
    }
    map['meal_type'] = Variable<String>(mealType);
    map['grams'] = Variable<double>(grams);
    map['logged_at'] = Variable<DateTime>(loggedAt);
    map['food_source'] = Variable<String>(foodSource);
    if (!nullToAbsent || foodBarcode != null) {
      map['food_barcode'] = Variable<String>(foodBarcode);
    }
    map['food_name'] = Variable<String>(foodName);
    if (!nullToAbsent || foodBrand != null) {
      map['food_brand'] = Variable<String>(foodBrand);
    }
    map['kcal100g'] = Variable<double>(kcal100g);
    if (!nullToAbsent || protein100g != null) {
      map['protein100g'] = Variable<double>(protein100g);
    }
    if (!nullToAbsent || carbs100g != null) {
      map['carbs100g'] = Variable<double>(carbs100g);
    }
    if (!nullToAbsent || fat100g != null) {
      map['fat100g'] = Variable<double>(fat100g);
    }
    if (!nullToAbsent || fiber100g != null) {
      map['fiber100g'] = Variable<double>(fiber100g);
    }
    if (!nullToAbsent || sugar100g != null) {
      map['sugar100g'] = Variable<double>(sugar100g);
    }
    if (!nullToAbsent || salt100g != null) {
      map['salt100g'] = Variable<double>(salt100g);
    }
    if (!nullToAbsent || servingG != null) {
      map['serving_g'] = Variable<double>(servingG);
    }
    map['synced'] = Variable<bool>(synced);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  MealEntriesCompanion toCompanion(bool nullToAbsent) {
    return MealEntriesCompanion(
      id: Value(id),
      foodRemoteId: foodRemoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(foodRemoteId),
      mealType: Value(mealType),
      grams: Value(grams),
      loggedAt: Value(loggedAt),
      foodSource: Value(foodSource),
      foodBarcode: foodBarcode == null && nullToAbsent
          ? const Value.absent()
          : Value(foodBarcode),
      foodName: Value(foodName),
      foodBrand: foodBrand == null && nullToAbsent
          ? const Value.absent()
          : Value(foodBrand),
      kcal100g: Value(kcal100g),
      protein100g: protein100g == null && nullToAbsent
          ? const Value.absent()
          : Value(protein100g),
      carbs100g: carbs100g == null && nullToAbsent
          ? const Value.absent()
          : Value(carbs100g),
      fat100g: fat100g == null && nullToAbsent
          ? const Value.absent()
          : Value(fat100g),
      fiber100g: fiber100g == null && nullToAbsent
          ? const Value.absent()
          : Value(fiber100g),
      sugar100g: sugar100g == null && nullToAbsent
          ? const Value.absent()
          : Value(sugar100g),
      salt100g: salt100g == null && nullToAbsent
          ? const Value.absent()
          : Value(salt100g),
      servingG: servingG == null && nullToAbsent
          ? const Value.absent()
          : Value(servingG),
      synced: Value(synced),
      deleted: Value(deleted),
    );
  }

  factory MealEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealEntry(
      id: serializer.fromJson<String>(json['id']),
      foodRemoteId: serializer.fromJson<int?>(json['foodRemoteId']),
      mealType: serializer.fromJson<String>(json['mealType']),
      grams: serializer.fromJson<double>(json['grams']),
      loggedAt: serializer.fromJson<DateTime>(json['loggedAt']),
      foodSource: serializer.fromJson<String>(json['foodSource']),
      foodBarcode: serializer.fromJson<String?>(json['foodBarcode']),
      foodName: serializer.fromJson<String>(json['foodName']),
      foodBrand: serializer.fromJson<String?>(json['foodBrand']),
      kcal100g: serializer.fromJson<double>(json['kcal100g']),
      protein100g: serializer.fromJson<double?>(json['protein100g']),
      carbs100g: serializer.fromJson<double?>(json['carbs100g']),
      fat100g: serializer.fromJson<double?>(json['fat100g']),
      fiber100g: serializer.fromJson<double?>(json['fiber100g']),
      sugar100g: serializer.fromJson<double?>(json['sugar100g']),
      salt100g: serializer.fromJson<double?>(json['salt100g']),
      servingG: serializer.fromJson<double?>(json['servingG']),
      synced: serializer.fromJson<bool>(json['synced']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'foodRemoteId': serializer.toJson<int?>(foodRemoteId),
      'mealType': serializer.toJson<String>(mealType),
      'grams': serializer.toJson<double>(grams),
      'loggedAt': serializer.toJson<DateTime>(loggedAt),
      'foodSource': serializer.toJson<String>(foodSource),
      'foodBarcode': serializer.toJson<String?>(foodBarcode),
      'foodName': serializer.toJson<String>(foodName),
      'foodBrand': serializer.toJson<String?>(foodBrand),
      'kcal100g': serializer.toJson<double>(kcal100g),
      'protein100g': serializer.toJson<double?>(protein100g),
      'carbs100g': serializer.toJson<double?>(carbs100g),
      'fat100g': serializer.toJson<double?>(fat100g),
      'fiber100g': serializer.toJson<double?>(fiber100g),
      'sugar100g': serializer.toJson<double?>(sugar100g),
      'salt100g': serializer.toJson<double?>(salt100g),
      'servingG': serializer.toJson<double?>(servingG),
      'synced': serializer.toJson<bool>(synced),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  MealEntry copyWith({
    String? id,
    Value<int?> foodRemoteId = const Value.absent(),
    String? mealType,
    double? grams,
    DateTime? loggedAt,
    String? foodSource,
    Value<String?> foodBarcode = const Value.absent(),
    String? foodName,
    Value<String?> foodBrand = const Value.absent(),
    double? kcal100g,
    Value<double?> protein100g = const Value.absent(),
    Value<double?> carbs100g = const Value.absent(),
    Value<double?> fat100g = const Value.absent(),
    Value<double?> fiber100g = const Value.absent(),
    Value<double?> sugar100g = const Value.absent(),
    Value<double?> salt100g = const Value.absent(),
    Value<double?> servingG = const Value.absent(),
    bool? synced,
    bool? deleted,
  }) => MealEntry(
    id: id ?? this.id,
    foodRemoteId: foodRemoteId.present ? foodRemoteId.value : this.foodRemoteId,
    mealType: mealType ?? this.mealType,
    grams: grams ?? this.grams,
    loggedAt: loggedAt ?? this.loggedAt,
    foodSource: foodSource ?? this.foodSource,
    foodBarcode: foodBarcode.present ? foodBarcode.value : this.foodBarcode,
    foodName: foodName ?? this.foodName,
    foodBrand: foodBrand.present ? foodBrand.value : this.foodBrand,
    kcal100g: kcal100g ?? this.kcal100g,
    protein100g: protein100g.present ? protein100g.value : this.protein100g,
    carbs100g: carbs100g.present ? carbs100g.value : this.carbs100g,
    fat100g: fat100g.present ? fat100g.value : this.fat100g,
    fiber100g: fiber100g.present ? fiber100g.value : this.fiber100g,
    sugar100g: sugar100g.present ? sugar100g.value : this.sugar100g,
    salt100g: salt100g.present ? salt100g.value : this.salt100g,
    servingG: servingG.present ? servingG.value : this.servingG,
    synced: synced ?? this.synced,
    deleted: deleted ?? this.deleted,
  );
  MealEntry copyWithCompanion(MealEntriesCompanion data) {
    return MealEntry(
      id: data.id.present ? data.id.value : this.id,
      foodRemoteId: data.foodRemoteId.present
          ? data.foodRemoteId.value
          : this.foodRemoteId,
      mealType: data.mealType.present ? data.mealType.value : this.mealType,
      grams: data.grams.present ? data.grams.value : this.grams,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
      foodSource: data.foodSource.present
          ? data.foodSource.value
          : this.foodSource,
      foodBarcode: data.foodBarcode.present
          ? data.foodBarcode.value
          : this.foodBarcode,
      foodName: data.foodName.present ? data.foodName.value : this.foodName,
      foodBrand: data.foodBrand.present ? data.foodBrand.value : this.foodBrand,
      kcal100g: data.kcal100g.present ? data.kcal100g.value : this.kcal100g,
      protein100g: data.protein100g.present
          ? data.protein100g.value
          : this.protein100g,
      carbs100g: data.carbs100g.present ? data.carbs100g.value : this.carbs100g,
      fat100g: data.fat100g.present ? data.fat100g.value : this.fat100g,
      fiber100g: data.fiber100g.present ? data.fiber100g.value : this.fiber100g,
      sugar100g: data.sugar100g.present ? data.sugar100g.value : this.sugar100g,
      salt100g: data.salt100g.present ? data.salt100g.value : this.salt100g,
      servingG: data.servingG.present ? data.servingG.value : this.servingG,
      synced: data.synced.present ? data.synced.value : this.synced,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealEntry(')
          ..write('id: $id, ')
          ..write('foodRemoteId: $foodRemoteId, ')
          ..write('mealType: $mealType, ')
          ..write('grams: $grams, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('foodSource: $foodSource, ')
          ..write('foodBarcode: $foodBarcode, ')
          ..write('foodName: $foodName, ')
          ..write('foodBrand: $foodBrand, ')
          ..write('kcal100g: $kcal100g, ')
          ..write('protein100g: $protein100g, ')
          ..write('carbs100g: $carbs100g, ')
          ..write('fat100g: $fat100g, ')
          ..write('fiber100g: $fiber100g, ')
          ..write('sugar100g: $sugar100g, ')
          ..write('salt100g: $salt100g, ')
          ..write('servingG: $servingG, ')
          ..write('synced: $synced, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    foodRemoteId,
    mealType,
    grams,
    loggedAt,
    foodSource,
    foodBarcode,
    foodName,
    foodBrand,
    kcal100g,
    protein100g,
    carbs100g,
    fat100g,
    fiber100g,
    sugar100g,
    salt100g,
    servingG,
    synced,
    deleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealEntry &&
          other.id == this.id &&
          other.foodRemoteId == this.foodRemoteId &&
          other.mealType == this.mealType &&
          other.grams == this.grams &&
          other.loggedAt == this.loggedAt &&
          other.foodSource == this.foodSource &&
          other.foodBarcode == this.foodBarcode &&
          other.foodName == this.foodName &&
          other.foodBrand == this.foodBrand &&
          other.kcal100g == this.kcal100g &&
          other.protein100g == this.protein100g &&
          other.carbs100g == this.carbs100g &&
          other.fat100g == this.fat100g &&
          other.fiber100g == this.fiber100g &&
          other.sugar100g == this.sugar100g &&
          other.salt100g == this.salt100g &&
          other.servingG == this.servingG &&
          other.synced == this.synced &&
          other.deleted == this.deleted);
}

class MealEntriesCompanion extends UpdateCompanion<MealEntry> {
  final Value<String> id;
  final Value<int?> foodRemoteId;
  final Value<String> mealType;
  final Value<double> grams;
  final Value<DateTime> loggedAt;
  final Value<String> foodSource;
  final Value<String?> foodBarcode;
  final Value<String> foodName;
  final Value<String?> foodBrand;
  final Value<double> kcal100g;
  final Value<double?> protein100g;
  final Value<double?> carbs100g;
  final Value<double?> fat100g;
  final Value<double?> fiber100g;
  final Value<double?> sugar100g;
  final Value<double?> salt100g;
  final Value<double?> servingG;
  final Value<bool> synced;
  final Value<bool> deleted;
  final Value<int> rowid;
  const MealEntriesCompanion({
    this.id = const Value.absent(),
    this.foodRemoteId = const Value.absent(),
    this.mealType = const Value.absent(),
    this.grams = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.foodSource = const Value.absent(),
    this.foodBarcode = const Value.absent(),
    this.foodName = const Value.absent(),
    this.foodBrand = const Value.absent(),
    this.kcal100g = const Value.absent(),
    this.protein100g = const Value.absent(),
    this.carbs100g = const Value.absent(),
    this.fat100g = const Value.absent(),
    this.fiber100g = const Value.absent(),
    this.sugar100g = const Value.absent(),
    this.salt100g = const Value.absent(),
    this.servingG = const Value.absent(),
    this.synced = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MealEntriesCompanion.insert({
    required String id,
    this.foodRemoteId = const Value.absent(),
    required String mealType,
    required double grams,
    required DateTime loggedAt,
    required String foodSource,
    this.foodBarcode = const Value.absent(),
    required String foodName,
    this.foodBrand = const Value.absent(),
    required double kcal100g,
    this.protein100g = const Value.absent(),
    this.carbs100g = const Value.absent(),
    this.fat100g = const Value.absent(),
    this.fiber100g = const Value.absent(),
    this.sugar100g = const Value.absent(),
    this.salt100g = const Value.absent(),
    this.servingG = const Value.absent(),
    this.synced = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       mealType = Value(mealType),
       grams = Value(grams),
       loggedAt = Value(loggedAt),
       foodSource = Value(foodSource),
       foodName = Value(foodName),
       kcal100g = Value(kcal100g);
  static Insertable<MealEntry> custom({
    Expression<String>? id,
    Expression<int>? foodRemoteId,
    Expression<String>? mealType,
    Expression<double>? grams,
    Expression<DateTime>? loggedAt,
    Expression<String>? foodSource,
    Expression<String>? foodBarcode,
    Expression<String>? foodName,
    Expression<String>? foodBrand,
    Expression<double>? kcal100g,
    Expression<double>? protein100g,
    Expression<double>? carbs100g,
    Expression<double>? fat100g,
    Expression<double>? fiber100g,
    Expression<double>? sugar100g,
    Expression<double>? salt100g,
    Expression<double>? servingG,
    Expression<bool>? synced,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (foodRemoteId != null) 'food_remote_id': foodRemoteId,
      if (mealType != null) 'meal_type': mealType,
      if (grams != null) 'grams': grams,
      if (loggedAt != null) 'logged_at': loggedAt,
      if (foodSource != null) 'food_source': foodSource,
      if (foodBarcode != null) 'food_barcode': foodBarcode,
      if (foodName != null) 'food_name': foodName,
      if (foodBrand != null) 'food_brand': foodBrand,
      if (kcal100g != null) 'kcal100g': kcal100g,
      if (protein100g != null) 'protein100g': protein100g,
      if (carbs100g != null) 'carbs100g': carbs100g,
      if (fat100g != null) 'fat100g': fat100g,
      if (fiber100g != null) 'fiber100g': fiber100g,
      if (sugar100g != null) 'sugar100g': sugar100g,
      if (salt100g != null) 'salt100g': salt100g,
      if (servingG != null) 'serving_g': servingG,
      if (synced != null) 'synced': synced,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MealEntriesCompanion copyWith({
    Value<String>? id,
    Value<int?>? foodRemoteId,
    Value<String>? mealType,
    Value<double>? grams,
    Value<DateTime>? loggedAt,
    Value<String>? foodSource,
    Value<String?>? foodBarcode,
    Value<String>? foodName,
    Value<String?>? foodBrand,
    Value<double>? kcal100g,
    Value<double?>? protein100g,
    Value<double?>? carbs100g,
    Value<double?>? fat100g,
    Value<double?>? fiber100g,
    Value<double?>? sugar100g,
    Value<double?>? salt100g,
    Value<double?>? servingG,
    Value<bool>? synced,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return MealEntriesCompanion(
      id: id ?? this.id,
      foodRemoteId: foodRemoteId ?? this.foodRemoteId,
      mealType: mealType ?? this.mealType,
      grams: grams ?? this.grams,
      loggedAt: loggedAt ?? this.loggedAt,
      foodSource: foodSource ?? this.foodSource,
      foodBarcode: foodBarcode ?? this.foodBarcode,
      foodName: foodName ?? this.foodName,
      foodBrand: foodBrand ?? this.foodBrand,
      kcal100g: kcal100g ?? this.kcal100g,
      protein100g: protein100g ?? this.protein100g,
      carbs100g: carbs100g ?? this.carbs100g,
      fat100g: fat100g ?? this.fat100g,
      fiber100g: fiber100g ?? this.fiber100g,
      sugar100g: sugar100g ?? this.sugar100g,
      salt100g: salt100g ?? this.salt100g,
      servingG: servingG ?? this.servingG,
      synced: synced ?? this.synced,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (foodRemoteId.present) {
      map['food_remote_id'] = Variable<int>(foodRemoteId.value);
    }
    if (mealType.present) {
      map['meal_type'] = Variable<String>(mealType.value);
    }
    if (grams.present) {
      map['grams'] = Variable<double>(grams.value);
    }
    if (loggedAt.present) {
      map['logged_at'] = Variable<DateTime>(loggedAt.value);
    }
    if (foodSource.present) {
      map['food_source'] = Variable<String>(foodSource.value);
    }
    if (foodBarcode.present) {
      map['food_barcode'] = Variable<String>(foodBarcode.value);
    }
    if (foodName.present) {
      map['food_name'] = Variable<String>(foodName.value);
    }
    if (foodBrand.present) {
      map['food_brand'] = Variable<String>(foodBrand.value);
    }
    if (kcal100g.present) {
      map['kcal100g'] = Variable<double>(kcal100g.value);
    }
    if (protein100g.present) {
      map['protein100g'] = Variable<double>(protein100g.value);
    }
    if (carbs100g.present) {
      map['carbs100g'] = Variable<double>(carbs100g.value);
    }
    if (fat100g.present) {
      map['fat100g'] = Variable<double>(fat100g.value);
    }
    if (fiber100g.present) {
      map['fiber100g'] = Variable<double>(fiber100g.value);
    }
    if (sugar100g.present) {
      map['sugar100g'] = Variable<double>(sugar100g.value);
    }
    if (salt100g.present) {
      map['salt100g'] = Variable<double>(salt100g.value);
    }
    if (servingG.present) {
      map['serving_g'] = Variable<double>(servingG.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealEntriesCompanion(')
          ..write('id: $id, ')
          ..write('foodRemoteId: $foodRemoteId, ')
          ..write('mealType: $mealType, ')
          ..write('grams: $grams, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('foodSource: $foodSource, ')
          ..write('foodBarcode: $foodBarcode, ')
          ..write('foodName: $foodName, ')
          ..write('foodBrand: $foodBrand, ')
          ..write('kcal100g: $kcal100g, ')
          ..write('protein100g: $protein100g, ')
          ..write('carbs100g: $carbs100g, ')
          ..write('fat100g: $fat100g, ')
          ..write('fiber100g: $fiber100g, ')
          ..write('sugar100g: $sugar100g, ')
          ..write('salt100g: $salt100g, ')
          ..write('servingG: $servingG, ')
          ..write('synced: $synced, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ExerciseLogsTable exerciseLogs = $ExerciseLogsTable(this);
  late final $MealEntriesTable mealEntries = $MealEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    exerciseLogs,
    mealEntries,
  ];
}

typedef $$ExerciseLogsTableCreateCompanionBuilder =
    ExerciseLogsCompanion Function({
      required String id,
      required int programId,
      required int exerciseId,
      required int weekNumber,
      required int dayNumber,
      required int setIndex,
      required int repsCompleted,
      Value<int?> reps,
      Value<int?> seconds,
      Value<double?> weight,
      required DateTime createdAt,
      Value<bool> synced,
      Value<int> rowid,
    });
typedef $$ExerciseLogsTableUpdateCompanionBuilder =
    ExerciseLogsCompanion Function({
      Value<String> id,
      Value<int> programId,
      Value<int> exerciseId,
      Value<int> weekNumber,
      Value<int> dayNumber,
      Value<int> setIndex,
      Value<int> repsCompleted,
      Value<int?> reps,
      Value<int?> seconds,
      Value<double?> weight,
      Value<DateTime> createdAt,
      Value<bool> synced,
      Value<int> rowid,
    });

class $$ExerciseLogsTableFilterComposer
    extends Composer<_$AppDatabase, $ExerciseLogsTable> {
  $$ExerciseLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get programId => $composableBuilder(
    column: $table.programId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekNumber => $composableBuilder(
    column: $table.weekNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayNumber => $composableBuilder(
    column: $table.dayNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get setIndex => $composableBuilder(
    column: $table.setIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repsCompleted => $composableBuilder(
    column: $table.repsCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seconds => $composableBuilder(
    column: $table.seconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExerciseLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExerciseLogsTable> {
  $$ExerciseLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get programId => $composableBuilder(
    column: $table.programId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekNumber => $composableBuilder(
    column: $table.weekNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayNumber => $composableBuilder(
    column: $table.dayNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get setIndex => $composableBuilder(
    column: $table.setIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repsCompleted => $composableBuilder(
    column: $table.repsCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seconds => $composableBuilder(
    column: $table.seconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExerciseLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExerciseLogsTable> {
  $$ExerciseLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get programId =>
      $composableBuilder(column: $table.programId, builder: (column) => column);

  GeneratedColumn<int> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get weekNumber => $composableBuilder(
    column: $table.weekNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dayNumber =>
      $composableBuilder(column: $table.dayNumber, builder: (column) => column);

  GeneratedColumn<int> get setIndex =>
      $composableBuilder(column: $table.setIndex, builder: (column) => column);

  GeneratedColumn<int> get repsCompleted => $composableBuilder(
    column: $table.repsCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get seconds =>
      $composableBuilder(column: $table.seconds, builder: (column) => column);

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$ExerciseLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExerciseLogsTable,
          ExerciseLog,
          $$ExerciseLogsTableFilterComposer,
          $$ExerciseLogsTableOrderingComposer,
          $$ExerciseLogsTableAnnotationComposer,
          $$ExerciseLogsTableCreateCompanionBuilder,
          $$ExerciseLogsTableUpdateCompanionBuilder,
          (
            ExerciseLog,
            BaseReferences<_$AppDatabase, $ExerciseLogsTable, ExerciseLog>,
          ),
          ExerciseLog,
          PrefetchHooks Function()
        > {
  $$ExerciseLogsTableTableManager(_$AppDatabase db, $ExerciseLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExerciseLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExerciseLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExerciseLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> programId = const Value.absent(),
                Value<int> exerciseId = const Value.absent(),
                Value<int> weekNumber = const Value.absent(),
                Value<int> dayNumber = const Value.absent(),
                Value<int> setIndex = const Value.absent(),
                Value<int> repsCompleted = const Value.absent(),
                Value<int?> reps = const Value.absent(),
                Value<int?> seconds = const Value.absent(),
                Value<double?> weight = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExerciseLogsCompanion(
                id: id,
                programId: programId,
                exerciseId: exerciseId,
                weekNumber: weekNumber,
                dayNumber: dayNumber,
                setIndex: setIndex,
                repsCompleted: repsCompleted,
                reps: reps,
                seconds: seconds,
                weight: weight,
                createdAt: createdAt,
                synced: synced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int programId,
                required int exerciseId,
                required int weekNumber,
                required int dayNumber,
                required int setIndex,
                required int repsCompleted,
                Value<int?> reps = const Value.absent(),
                Value<int?> seconds = const Value.absent(),
                Value<double?> weight = const Value.absent(),
                required DateTime createdAt,
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExerciseLogsCompanion.insert(
                id: id,
                programId: programId,
                exerciseId: exerciseId,
                weekNumber: weekNumber,
                dayNumber: dayNumber,
                setIndex: setIndex,
                repsCompleted: repsCompleted,
                reps: reps,
                seconds: seconds,
                weight: weight,
                createdAt: createdAt,
                synced: synced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExerciseLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExerciseLogsTable,
      ExerciseLog,
      $$ExerciseLogsTableFilterComposer,
      $$ExerciseLogsTableOrderingComposer,
      $$ExerciseLogsTableAnnotationComposer,
      $$ExerciseLogsTableCreateCompanionBuilder,
      $$ExerciseLogsTableUpdateCompanionBuilder,
      (
        ExerciseLog,
        BaseReferences<_$AppDatabase, $ExerciseLogsTable, ExerciseLog>,
      ),
      ExerciseLog,
      PrefetchHooks Function()
    >;
typedef $$MealEntriesTableCreateCompanionBuilder =
    MealEntriesCompanion Function({
      required String id,
      Value<int?> foodRemoteId,
      required String mealType,
      required double grams,
      required DateTime loggedAt,
      required String foodSource,
      Value<String?> foodBarcode,
      required String foodName,
      Value<String?> foodBrand,
      required double kcal100g,
      Value<double?> protein100g,
      Value<double?> carbs100g,
      Value<double?> fat100g,
      Value<double?> fiber100g,
      Value<double?> sugar100g,
      Value<double?> salt100g,
      Value<double?> servingG,
      Value<bool> synced,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$MealEntriesTableUpdateCompanionBuilder =
    MealEntriesCompanion Function({
      Value<String> id,
      Value<int?> foodRemoteId,
      Value<String> mealType,
      Value<double> grams,
      Value<DateTime> loggedAt,
      Value<String> foodSource,
      Value<String?> foodBarcode,
      Value<String> foodName,
      Value<String?> foodBrand,
      Value<double> kcal100g,
      Value<double?> protein100g,
      Value<double?> carbs100g,
      Value<double?> fat100g,
      Value<double?> fiber100g,
      Value<double?> sugar100g,
      Value<double?> salt100g,
      Value<double?> servingG,
      Value<bool> synced,
      Value<bool> deleted,
      Value<int> rowid,
    });

class $$MealEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MealEntriesTable> {
  $$MealEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get foodRemoteId => $composableBuilder(
    column: $table.foodRemoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mealType => $composableBuilder(
    column: $table.mealType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get grams => $composableBuilder(
    column: $table.grams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foodSource => $composableBuilder(
    column: $table.foodSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foodBarcode => $composableBuilder(
    column: $table.foodBarcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foodName => $composableBuilder(
    column: $table.foodName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foodBrand => $composableBuilder(
    column: $table.foodBrand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kcal100g => $composableBuilder(
    column: $table.kcal100g,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get protein100g => $composableBuilder(
    column: $table.protein100g,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbs100g => $composableBuilder(
    column: $table.carbs100g,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fat100g => $composableBuilder(
    column: $table.fat100g,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fiber100g => $composableBuilder(
    column: $table.fiber100g,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sugar100g => $composableBuilder(
    column: $table.sugar100g,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get salt100g => $composableBuilder(
    column: $table.salt100g,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get servingG => $composableBuilder(
    column: $table.servingG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MealEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MealEntriesTable> {
  $$MealEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get foodRemoteId => $composableBuilder(
    column: $table.foodRemoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mealType => $composableBuilder(
    column: $table.mealType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get grams => $composableBuilder(
    column: $table.grams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foodSource => $composableBuilder(
    column: $table.foodSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foodBarcode => $composableBuilder(
    column: $table.foodBarcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foodName => $composableBuilder(
    column: $table.foodName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foodBrand => $composableBuilder(
    column: $table.foodBrand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kcal100g => $composableBuilder(
    column: $table.kcal100g,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get protein100g => $composableBuilder(
    column: $table.protein100g,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbs100g => $composableBuilder(
    column: $table.carbs100g,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fat100g => $composableBuilder(
    column: $table.fat100g,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fiber100g => $composableBuilder(
    column: $table.fiber100g,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sugar100g => $composableBuilder(
    column: $table.sugar100g,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get salt100g => $composableBuilder(
    column: $table.salt100g,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get servingG => $composableBuilder(
    column: $table.servingG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MealEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealEntriesTable> {
  $$MealEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get foodRemoteId => $composableBuilder(
    column: $table.foodRemoteId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mealType =>
      $composableBuilder(column: $table.mealType, builder: (column) => column);

  GeneratedColumn<double> get grams =>
      $composableBuilder(column: $table.grams, builder: (column) => column);

  GeneratedColumn<DateTime> get loggedAt =>
      $composableBuilder(column: $table.loggedAt, builder: (column) => column);

  GeneratedColumn<String> get foodSource => $composableBuilder(
    column: $table.foodSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get foodBarcode => $composableBuilder(
    column: $table.foodBarcode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get foodName =>
      $composableBuilder(column: $table.foodName, builder: (column) => column);

  GeneratedColumn<String> get foodBrand =>
      $composableBuilder(column: $table.foodBrand, builder: (column) => column);

  GeneratedColumn<double> get kcal100g =>
      $composableBuilder(column: $table.kcal100g, builder: (column) => column);

  GeneratedColumn<double> get protein100g => $composableBuilder(
    column: $table.protein100g,
    builder: (column) => column,
  );

  GeneratedColumn<double> get carbs100g =>
      $composableBuilder(column: $table.carbs100g, builder: (column) => column);

  GeneratedColumn<double> get fat100g =>
      $composableBuilder(column: $table.fat100g, builder: (column) => column);

  GeneratedColumn<double> get fiber100g =>
      $composableBuilder(column: $table.fiber100g, builder: (column) => column);

  GeneratedColumn<double> get sugar100g =>
      $composableBuilder(column: $table.sugar100g, builder: (column) => column);

  GeneratedColumn<double> get salt100g =>
      $composableBuilder(column: $table.salt100g, builder: (column) => column);

  GeneratedColumn<double> get servingG =>
      $composableBuilder(column: $table.servingG, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$MealEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealEntriesTable,
          MealEntry,
          $$MealEntriesTableFilterComposer,
          $$MealEntriesTableOrderingComposer,
          $$MealEntriesTableAnnotationComposer,
          $$MealEntriesTableCreateCompanionBuilder,
          $$MealEntriesTableUpdateCompanionBuilder,
          (
            MealEntry,
            BaseReferences<_$AppDatabase, $MealEntriesTable, MealEntry>,
          ),
          MealEntry,
          PrefetchHooks Function()
        > {
  $$MealEntriesTableTableManager(_$AppDatabase db, $MealEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> foodRemoteId = const Value.absent(),
                Value<String> mealType = const Value.absent(),
                Value<double> grams = const Value.absent(),
                Value<DateTime> loggedAt = const Value.absent(),
                Value<String> foodSource = const Value.absent(),
                Value<String?> foodBarcode = const Value.absent(),
                Value<String> foodName = const Value.absent(),
                Value<String?> foodBrand = const Value.absent(),
                Value<double> kcal100g = const Value.absent(),
                Value<double?> protein100g = const Value.absent(),
                Value<double?> carbs100g = const Value.absent(),
                Value<double?> fat100g = const Value.absent(),
                Value<double?> fiber100g = const Value.absent(),
                Value<double?> sugar100g = const Value.absent(),
                Value<double?> salt100g = const Value.absent(),
                Value<double?> servingG = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MealEntriesCompanion(
                id: id,
                foodRemoteId: foodRemoteId,
                mealType: mealType,
                grams: grams,
                loggedAt: loggedAt,
                foodSource: foodSource,
                foodBarcode: foodBarcode,
                foodName: foodName,
                foodBrand: foodBrand,
                kcal100g: kcal100g,
                protein100g: protein100g,
                carbs100g: carbs100g,
                fat100g: fat100g,
                fiber100g: fiber100g,
                sugar100g: sugar100g,
                salt100g: salt100g,
                servingG: servingG,
                synced: synced,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> foodRemoteId = const Value.absent(),
                required String mealType,
                required double grams,
                required DateTime loggedAt,
                required String foodSource,
                Value<String?> foodBarcode = const Value.absent(),
                required String foodName,
                Value<String?> foodBrand = const Value.absent(),
                required double kcal100g,
                Value<double?> protein100g = const Value.absent(),
                Value<double?> carbs100g = const Value.absent(),
                Value<double?> fat100g = const Value.absent(),
                Value<double?> fiber100g = const Value.absent(),
                Value<double?> sugar100g = const Value.absent(),
                Value<double?> salt100g = const Value.absent(),
                Value<double?> servingG = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MealEntriesCompanion.insert(
                id: id,
                foodRemoteId: foodRemoteId,
                mealType: mealType,
                grams: grams,
                loggedAt: loggedAt,
                foodSource: foodSource,
                foodBarcode: foodBarcode,
                foodName: foodName,
                foodBrand: foodBrand,
                kcal100g: kcal100g,
                protein100g: protein100g,
                carbs100g: carbs100g,
                fat100g: fat100g,
                fiber100g: fiber100g,
                sugar100g: sugar100g,
                salt100g: salt100g,
                servingG: servingG,
                synced: synced,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MealEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealEntriesTable,
      MealEntry,
      $$MealEntriesTableFilterComposer,
      $$MealEntriesTableOrderingComposer,
      $$MealEntriesTableAnnotationComposer,
      $$MealEntriesTableCreateCompanionBuilder,
      $$MealEntriesTableUpdateCompanionBuilder,
      (MealEntry, BaseReferences<_$AppDatabase, $MealEntriesTable, MealEntry>),
      MealEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ExerciseLogsTableTableManager get exerciseLogs =>
      $$ExerciseLogsTableTableManager(_db, _db.exerciseLogs);
  $$MealEntriesTableTableManager get mealEntries =>
      $$MealEntriesTableTableManager(_db, _db.mealEntries);
}
