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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ExerciseLogsTable exerciseLogs = $ExerciseLogsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [exerciseLogs];
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ExerciseLogsTableTableManager get exerciseLogs =>
      $$ExerciseLogsTableTableManager(_db, _db.exerciseLogs);
}
