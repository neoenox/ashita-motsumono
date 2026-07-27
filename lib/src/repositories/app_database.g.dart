// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DbChildTable extends DbChild with TableInfo<$DbChildTable, DbChildData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbChildTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    colorValue,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_child';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbChildData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbChildData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbChildData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DbChildTable createAlias(String alias) {
    return $DbChildTable(attachedDatabase, alias);
  }
}

class DbChildData extends DataClass implements Insertable<DbChildData> {
  final String id;
  final String name;
  final int colorValue;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DbChildData({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color_value'] = Variable<int>(colorValue);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DbChildCompanion toCompanion(bool nullToAbsent) {
    return DbChildCompanion(
      id: Value(id),
      name: Value(name),
      colorValue: Value(colorValue),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DbChildData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbChildData(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'colorValue': serializer.toJson<int>(colorValue),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DbChildData copyWith({
    String? id,
    String? name,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DbChildData(
    id: id ?? this.id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DbChildData copyWithCompanion(DbChildCompanion data) {
    return DbChildData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbChildData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colorValue, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbChildData &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorValue == this.colorValue &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DbChildCompanion extends UpdateCompanion<DbChildData> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> colorValue;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DbChildCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DbChildCompanion.insert({
    required String id,
    required String name,
    required int colorValue,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       colorValue = Value(colorValue),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DbChildData> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? colorValue,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorValue != null) 'color_value': colorValue,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DbChildCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? colorValue,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DbChildCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbChildCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DbTodoTable extends DbTodo with TableInfo<$DbTodoTable, DbTodoData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbTodoTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<String> childId = GeneratedColumn<String>(
    'child_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notifyPreviousNightMeta =
      const VerificationMeta('notifyPreviousNight');
  @override
  late final GeneratedColumn<bool> notifyPreviousNight = GeneratedColumn<bool>(
    'notify_previous_night',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notify_previous_night" IN (0, 1))',
    ),
  );
  static const VerificationMeta _notifySameMorningMeta = const VerificationMeta(
    'notifySameMorning',
  );
  @override
  late final GeneratedColumn<bool> notifySameMorning = GeneratedColumn<bool>(
    'notify_same_morning',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notify_same_morning" IN (0, 1))',
    ),
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    childId,
    documentId,
    dueDate,
    category,
    amount,
    note,
    status,
    notifyPreviousNight,
    notifySameMorning,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_todo';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbTodoData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('notify_previous_night')) {
      context.handle(
        _notifyPreviousNightMeta,
        notifyPreviousNight.isAcceptableOrUnknown(
          data['notify_previous_night']!,
          _notifyPreviousNightMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_notifyPreviousNightMeta);
    }
    if (data.containsKey('notify_same_morning')) {
      context.handle(
        _notifySameMorningMeta,
        notifySameMorning.isAcceptableOrUnknown(
          data['notify_same_morning']!,
          _notifySameMorningMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_notifySameMorningMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbTodoData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbTodoData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}child_id'],
      ),
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      ),
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      notifyPreviousNight: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notify_previous_night'],
      )!,
      notifySameMorning: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notify_same_morning'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DbTodoTable createAlias(String alias) {
    return $DbTodoTable(attachedDatabase, alias);
  }
}

class DbTodoData extends DataClass implements Insertable<DbTodoData> {
  final String id;
  final String title;
  final String? childId;
  final String? documentId;
  final DateTime? dueDate;
  final String category;
  final int? amount;
  final String? note;
  final String status;
  final bool notifyPreviousNight;
  final bool notifySameMorning;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DbTodoData({
    required this.id,
    required this.title,
    this.childId,
    this.documentId,
    this.dueDate,
    required this.category,
    this.amount,
    this.note,
    required this.status,
    required this.notifyPreviousNight,
    required this.notifySameMorning,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || childId != null) {
      map['child_id'] = Variable<String>(childId);
    }
    if (!nullToAbsent || documentId != null) {
      map['document_id'] = Variable<String>(documentId);
    }
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || amount != null) {
      map['amount'] = Variable<int>(amount);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['status'] = Variable<String>(status);
    map['notify_previous_night'] = Variable<bool>(notifyPreviousNight);
    map['notify_same_morning'] = Variable<bool>(notifySameMorning);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DbTodoCompanion toCompanion(bool nullToAbsent) {
    return DbTodoCompanion(
      id: Value(id),
      title: Value(title),
      childId: childId == null && nullToAbsent
          ? const Value.absent()
          : Value(childId),
      documentId: documentId == null && nullToAbsent
          ? const Value.absent()
          : Value(documentId),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      category: Value(category),
      amount: amount == null && nullToAbsent
          ? const Value.absent()
          : Value(amount),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      status: Value(status),
      notifyPreviousNight: Value(notifyPreviousNight),
      notifySameMorning: Value(notifySameMorning),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DbTodoData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbTodoData(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      childId: serializer.fromJson<String?>(json['childId']),
      documentId: serializer.fromJson<String?>(json['documentId']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      category: serializer.fromJson<String>(json['category']),
      amount: serializer.fromJson<int?>(json['amount']),
      note: serializer.fromJson<String?>(json['note']),
      status: serializer.fromJson<String>(json['status']),
      notifyPreviousNight: serializer.fromJson<bool>(
        json['notifyPreviousNight'],
      ),
      notifySameMorning: serializer.fromJson<bool>(json['notifySameMorning']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'childId': serializer.toJson<String?>(childId),
      'documentId': serializer.toJson<String?>(documentId),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'category': serializer.toJson<String>(category),
      'amount': serializer.toJson<int?>(amount),
      'note': serializer.toJson<String?>(note),
      'status': serializer.toJson<String>(status),
      'notifyPreviousNight': serializer.toJson<bool>(notifyPreviousNight),
      'notifySameMorning': serializer.toJson<bool>(notifySameMorning),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DbTodoData copyWith({
    String? id,
    String? title,
    Value<String?> childId = const Value.absent(),
    Value<String?> documentId = const Value.absent(),
    Value<DateTime?> dueDate = const Value.absent(),
    String? category,
    Value<int?> amount = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? status,
    bool? notifyPreviousNight,
    bool? notifySameMorning,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DbTodoData(
    id: id ?? this.id,
    title: title ?? this.title,
    childId: childId.present ? childId.value : this.childId,
    documentId: documentId.present ? documentId.value : this.documentId,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    category: category ?? this.category,
    amount: amount.present ? amount.value : this.amount,
    note: note.present ? note.value : this.note,
    status: status ?? this.status,
    notifyPreviousNight: notifyPreviousNight ?? this.notifyPreviousNight,
    notifySameMorning: notifySameMorning ?? this.notifySameMorning,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DbTodoData copyWithCompanion(DbTodoCompanion data) {
    return DbTodoData(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      childId: data.childId.present ? data.childId.value : this.childId,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      category: data.category.present ? data.category.value : this.category,
      amount: data.amount.present ? data.amount.value : this.amount,
      note: data.note.present ? data.note.value : this.note,
      status: data.status.present ? data.status.value : this.status,
      notifyPreviousNight: data.notifyPreviousNight.present
          ? data.notifyPreviousNight.value
          : this.notifyPreviousNight,
      notifySameMorning: data.notifySameMorning.present
          ? data.notifySameMorning.value
          : this.notifySameMorning,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbTodoData(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('childId: $childId, ')
          ..write('documentId: $documentId, ')
          ..write('dueDate: $dueDate, ')
          ..write('category: $category, ')
          ..write('amount: $amount, ')
          ..write('note: $note, ')
          ..write('status: $status, ')
          ..write('notifyPreviousNight: $notifyPreviousNight, ')
          ..write('notifySameMorning: $notifySameMorning, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    childId,
    documentId,
    dueDate,
    category,
    amount,
    note,
    status,
    notifyPreviousNight,
    notifySameMorning,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbTodoData &&
          other.id == this.id &&
          other.title == this.title &&
          other.childId == this.childId &&
          other.documentId == this.documentId &&
          other.dueDate == this.dueDate &&
          other.category == this.category &&
          other.amount == this.amount &&
          other.note == this.note &&
          other.status == this.status &&
          other.notifyPreviousNight == this.notifyPreviousNight &&
          other.notifySameMorning == this.notifySameMorning &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DbTodoCompanion extends UpdateCompanion<DbTodoData> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> childId;
  final Value<String?> documentId;
  final Value<DateTime?> dueDate;
  final Value<String> category;
  final Value<int?> amount;
  final Value<String?> note;
  final Value<String> status;
  final Value<bool> notifyPreviousNight;
  final Value<bool> notifySameMorning;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DbTodoCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.childId = const Value.absent(),
    this.documentId = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.category = const Value.absent(),
    this.amount = const Value.absent(),
    this.note = const Value.absent(),
    this.status = const Value.absent(),
    this.notifyPreviousNight = const Value.absent(),
    this.notifySameMorning = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DbTodoCompanion.insert({
    required String id,
    required String title,
    this.childId = const Value.absent(),
    this.documentId = const Value.absent(),
    this.dueDate = const Value.absent(),
    required String category,
    this.amount = const Value.absent(),
    this.note = const Value.absent(),
    required String status,
    required bool notifyPreviousNight,
    required bool notifySameMorning,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       category = Value(category),
       status = Value(status),
       notifyPreviousNight = Value(notifyPreviousNight),
       notifySameMorning = Value(notifySameMorning),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DbTodoData> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? childId,
    Expression<String>? documentId,
    Expression<DateTime>? dueDate,
    Expression<String>? category,
    Expression<int>? amount,
    Expression<String>? note,
    Expression<String>? status,
    Expression<bool>? notifyPreviousNight,
    Expression<bool>? notifySameMorning,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (childId != null) 'child_id': childId,
      if (documentId != null) 'document_id': documentId,
      if (dueDate != null) 'due_date': dueDate,
      if (category != null) 'category': category,
      if (amount != null) 'amount': amount,
      if (note != null) 'note': note,
      if (status != null) 'status': status,
      if (notifyPreviousNight != null)
        'notify_previous_night': notifyPreviousNight,
      if (notifySameMorning != null) 'notify_same_morning': notifySameMorning,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DbTodoCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? childId,
    Value<String?>? documentId,
    Value<DateTime?>? dueDate,
    Value<String>? category,
    Value<int?>? amount,
    Value<String?>? note,
    Value<String>? status,
    Value<bool>? notifyPreviousNight,
    Value<bool>? notifySameMorning,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DbTodoCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      childId: childId ?? this.childId,
      documentId: documentId ?? this.documentId,
      dueDate: dueDate ?? this.dueDate,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      status: status ?? this.status,
      notifyPreviousNight: notifyPreviousNight ?? this.notifyPreviousNight,
      notifySameMorning: notifySameMorning ?? this.notifySameMorning,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (childId.present) {
      map['child_id'] = Variable<String>(childId.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (notifyPreviousNight.present) {
      map['notify_previous_night'] = Variable<bool>(notifyPreviousNight.value);
    }
    if (notifySameMorning.present) {
      map['notify_same_morning'] = Variable<bool>(notifySameMorning.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbTodoCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('childId: $childId, ')
          ..write('documentId: $documentId, ')
          ..write('dueDate: $dueDate, ')
          ..write('category: $category, ')
          ..write('amount: $amount, ')
          ..write('note: $note, ')
          ..write('status: $status, ')
          ..write('notifyPreviousNight: $notifyPreviousNight, ')
          ..write('notifySameMorning: $notifySameMorning, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DbChecklistItemTable extends DbChecklistItem
    with TableInfo<$DbChecklistItemTable, DbChecklistItemData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbChecklistItemTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _todoIdMeta = const VerificationMeta('todoId');
  @override
  late final GeneratedColumn<String> todoId = GeneratedColumn<String>(
    'todo_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isCheckedMeta = const VerificationMeta(
    'isChecked',
  );
  @override
  late final GeneratedColumn<bool> isChecked = GeneratedColumn<bool>(
    'is_checked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_checked" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [id, todoId, label, isChecked];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_checklist_item';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbChecklistItemData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('todo_id')) {
      context.handle(
        _todoIdMeta,
        todoId.isAcceptableOrUnknown(data['todo_id']!, _todoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_todoIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('is_checked')) {
      context.handle(
        _isCheckedMeta,
        isChecked.isAcceptableOrUnknown(data['is_checked']!, _isCheckedMeta),
      );
    } else if (isInserting) {
      context.missing(_isCheckedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbChecklistItemData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbChecklistItemData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      todoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}todo_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      isChecked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_checked'],
      )!,
    );
  }

  @override
  $DbChecklistItemTable createAlias(String alias) {
    return $DbChecklistItemTable(attachedDatabase, alias);
  }
}

class DbChecklistItemData extends DataClass
    implements Insertable<DbChecklistItemData> {
  final String id;
  final String todoId;
  final String label;
  final bool isChecked;
  const DbChecklistItemData({
    required this.id,
    required this.todoId,
    required this.label,
    required this.isChecked,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['todo_id'] = Variable<String>(todoId);
    map['label'] = Variable<String>(label);
    map['is_checked'] = Variable<bool>(isChecked);
    return map;
  }

  DbChecklistItemCompanion toCompanion(bool nullToAbsent) {
    return DbChecklistItemCompanion(
      id: Value(id),
      todoId: Value(todoId),
      label: Value(label),
      isChecked: Value(isChecked),
    );
  }

  factory DbChecklistItemData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbChecklistItemData(
      id: serializer.fromJson<String>(json['id']),
      todoId: serializer.fromJson<String>(json['todoId']),
      label: serializer.fromJson<String>(json['label']),
      isChecked: serializer.fromJson<bool>(json['isChecked']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'todoId': serializer.toJson<String>(todoId),
      'label': serializer.toJson<String>(label),
      'isChecked': serializer.toJson<bool>(isChecked),
    };
  }

  DbChecklistItemData copyWith({
    String? id,
    String? todoId,
    String? label,
    bool? isChecked,
  }) => DbChecklistItemData(
    id: id ?? this.id,
    todoId: todoId ?? this.todoId,
    label: label ?? this.label,
    isChecked: isChecked ?? this.isChecked,
  );
  DbChecklistItemData copyWithCompanion(DbChecklistItemCompanion data) {
    return DbChecklistItemData(
      id: data.id.present ? data.id.value : this.id,
      todoId: data.todoId.present ? data.todoId.value : this.todoId,
      label: data.label.present ? data.label.value : this.label,
      isChecked: data.isChecked.present ? data.isChecked.value : this.isChecked,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbChecklistItemData(')
          ..write('id: $id, ')
          ..write('todoId: $todoId, ')
          ..write('label: $label, ')
          ..write('isChecked: $isChecked')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, todoId, label, isChecked);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbChecklistItemData &&
          other.id == this.id &&
          other.todoId == this.todoId &&
          other.label == this.label &&
          other.isChecked == this.isChecked);
}

class DbChecklistItemCompanion extends UpdateCompanion<DbChecklistItemData> {
  final Value<String> id;
  final Value<String> todoId;
  final Value<String> label;
  final Value<bool> isChecked;
  final Value<int> rowid;
  const DbChecklistItemCompanion({
    this.id = const Value.absent(),
    this.todoId = const Value.absent(),
    this.label = const Value.absent(),
    this.isChecked = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DbChecklistItemCompanion.insert({
    required String id,
    required String todoId,
    required String label,
    required bool isChecked,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       todoId = Value(todoId),
       label = Value(label),
       isChecked = Value(isChecked);
  static Insertable<DbChecklistItemData> custom({
    Expression<String>? id,
    Expression<String>? todoId,
    Expression<String>? label,
    Expression<bool>? isChecked,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (todoId != null) 'todo_id': todoId,
      if (label != null) 'label': label,
      if (isChecked != null) 'is_checked': isChecked,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DbChecklistItemCompanion copyWith({
    Value<String>? id,
    Value<String>? todoId,
    Value<String>? label,
    Value<bool>? isChecked,
    Value<int>? rowid,
  }) {
    return DbChecklistItemCompanion(
      id: id ?? this.id,
      todoId: todoId ?? this.todoId,
      label: label ?? this.label,
      isChecked: isChecked ?? this.isChecked,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (todoId.present) {
      map['todo_id'] = Variable<String>(todoId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (isChecked.present) {
      map['is_checked'] = Variable<bool>(isChecked.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbChecklistItemCompanion(')
          ..write('id: $id, ')
          ..write('todoId: $todoId, ')
          ..write('label: $label, ')
          ..write('isChecked: $isChecked, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DbDocumentTable extends DbDocument
    with TableInfo<$DbDocumentTable, DbDocumentData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbDocumentTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localImagePathMeta = const VerificationMeta(
    'localImagePath',
  );
  @override
  late final GeneratedColumn<String> localImagePath = GeneratedColumn<String>(
    'local_image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ocrTextMeta = const VerificationMeta(
    'ocrText',
  );
  @override
  late final GeneratedColumn<String> ocrText = GeneratedColumn<String>(
    'ocr_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMimeTypeMeta = const VerificationMeta(
    'sourceMimeType',
  );
  @override
  late final GeneratedColumn<String> sourceMimeType = GeneratedColumn<String>(
    'source_mime_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceFingerprintMeta = const VerificationMeta(
    'sourceFingerprint',
  );
  @override
  late final GeneratedColumn<String> sourceFingerprint =
      GeneratedColumn<String>(
        'source_fingerprint',
        aliasedName,
        true,
        type: DriftSqlType.string,
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceType,
    localImagePath,
    ocrText,
    sourceMimeType,
    sourceFingerprint,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_document';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbDocumentData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('local_image_path')) {
      context.handle(
        _localImagePathMeta,
        localImagePath.isAcceptableOrUnknown(
          data['local_image_path']!,
          _localImagePathMeta,
        ),
      );
    }
    if (data.containsKey('ocr_text')) {
      context.handle(
        _ocrTextMeta,
        ocrText.isAcceptableOrUnknown(data['ocr_text']!, _ocrTextMeta),
      );
    }
    if (data.containsKey('source_mime_type')) {
      context.handle(
        _sourceMimeTypeMeta,
        sourceMimeType.isAcceptableOrUnknown(
          data['source_mime_type']!,
          _sourceMimeTypeMeta,
        ),
      );
    }
    if (data.containsKey('source_fingerprint')) {
      context.handle(
        _sourceFingerprintMeta,
        sourceFingerprint.isAcceptableOrUnknown(
          data['source_fingerprint']!,
          _sourceFingerprintMeta,
        ),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbDocumentData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbDocumentData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      localImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_image_path'],
      ),
      ocrText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ocr_text'],
      ),
      sourceMimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_mime_type'],
      ),
      sourceFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_fingerprint'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DbDocumentTable createAlias(String alias) {
    return $DbDocumentTable(attachedDatabase, alias);
  }
}

class DbDocumentData extends DataClass implements Insertable<DbDocumentData> {
  final String id;
  final String sourceType;
  final String? localImagePath;
  final String? ocrText;
  final String? sourceMimeType;
  final String? sourceFingerprint;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DbDocumentData({
    required this.id,
    required this.sourceType,
    this.localImagePath,
    this.ocrText,
    this.sourceMimeType,
    this.sourceFingerprint,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_type'] = Variable<String>(sourceType);
    if (!nullToAbsent || localImagePath != null) {
      map['local_image_path'] = Variable<String>(localImagePath);
    }
    if (!nullToAbsent || ocrText != null) {
      map['ocr_text'] = Variable<String>(ocrText);
    }
    if (!nullToAbsent || sourceMimeType != null) {
      map['source_mime_type'] = Variable<String>(sourceMimeType);
    }
    if (!nullToAbsent || sourceFingerprint != null) {
      map['source_fingerprint'] = Variable<String>(sourceFingerprint);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DbDocumentCompanion toCompanion(bool nullToAbsent) {
    return DbDocumentCompanion(
      id: Value(id),
      sourceType: Value(sourceType),
      localImagePath: localImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(localImagePath),
      ocrText: ocrText == null && nullToAbsent
          ? const Value.absent()
          : Value(ocrText),
      sourceMimeType: sourceMimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceMimeType),
      sourceFingerprint: sourceFingerprint == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceFingerprint),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DbDocumentData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbDocumentData(
      id: serializer.fromJson<String>(json['id']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      localImagePath: serializer.fromJson<String?>(json['localImagePath']),
      ocrText: serializer.fromJson<String?>(json['ocrText']),
      sourceMimeType: serializer.fromJson<String?>(json['sourceMimeType']),
      sourceFingerprint: serializer.fromJson<String?>(
        json['sourceFingerprint'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceType': serializer.toJson<String>(sourceType),
      'localImagePath': serializer.toJson<String?>(localImagePath),
      'ocrText': serializer.toJson<String?>(ocrText),
      'sourceMimeType': serializer.toJson<String?>(sourceMimeType),
      'sourceFingerprint': serializer.toJson<String?>(sourceFingerprint),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DbDocumentData copyWith({
    String? id,
    String? sourceType,
    Value<String?> localImagePath = const Value.absent(),
    Value<String?> ocrText = const Value.absent(),
    Value<String?> sourceMimeType = const Value.absent(),
    Value<String?> sourceFingerprint = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DbDocumentData(
    id: id ?? this.id,
    sourceType: sourceType ?? this.sourceType,
    localImagePath: localImagePath.present
        ? localImagePath.value
        : this.localImagePath,
    ocrText: ocrText.present ? ocrText.value : this.ocrText,
    sourceMimeType: sourceMimeType.present
        ? sourceMimeType.value
        : this.sourceMimeType,
    sourceFingerprint: sourceFingerprint.present
        ? sourceFingerprint.value
        : this.sourceFingerprint,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DbDocumentData copyWithCompanion(DbDocumentCompanion data) {
    return DbDocumentData(
      id: data.id.present ? data.id.value : this.id,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      localImagePath: data.localImagePath.present
          ? data.localImagePath.value
          : this.localImagePath,
      ocrText: data.ocrText.present ? data.ocrText.value : this.ocrText,
      sourceMimeType: data.sourceMimeType.present
          ? data.sourceMimeType.value
          : this.sourceMimeType,
      sourceFingerprint: data.sourceFingerprint.present
          ? data.sourceFingerprint.value
          : this.sourceFingerprint,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbDocumentData(')
          ..write('id: $id, ')
          ..write('sourceType: $sourceType, ')
          ..write('localImagePath: $localImagePath, ')
          ..write('ocrText: $ocrText, ')
          ..write('sourceMimeType: $sourceMimeType, ')
          ..write('sourceFingerprint: $sourceFingerprint, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceType,
    localImagePath,
    ocrText,
    sourceMimeType,
    sourceFingerprint,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbDocumentData &&
          other.id == this.id &&
          other.sourceType == this.sourceType &&
          other.localImagePath == this.localImagePath &&
          other.ocrText == this.ocrText &&
          other.sourceMimeType == this.sourceMimeType &&
          other.sourceFingerprint == this.sourceFingerprint &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DbDocumentCompanion extends UpdateCompanion<DbDocumentData> {
  final Value<String> id;
  final Value<String> sourceType;
  final Value<String?> localImagePath;
  final Value<String?> ocrText;
  final Value<String?> sourceMimeType;
  final Value<String?> sourceFingerprint;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DbDocumentCompanion({
    this.id = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.localImagePath = const Value.absent(),
    this.ocrText = const Value.absent(),
    this.sourceMimeType = const Value.absent(),
    this.sourceFingerprint = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DbDocumentCompanion.insert({
    required String id,
    required String sourceType,
    this.localImagePath = const Value.absent(),
    this.ocrText = const Value.absent(),
    this.sourceMimeType = const Value.absent(),
    this.sourceFingerprint = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceType = Value(sourceType),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DbDocumentData> custom({
    Expression<String>? id,
    Expression<String>? sourceType,
    Expression<String>? localImagePath,
    Expression<String>? ocrText,
    Expression<String>? sourceMimeType,
    Expression<String>? sourceFingerprint,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceType != null) 'source_type': sourceType,
      if (localImagePath != null) 'local_image_path': localImagePath,
      if (ocrText != null) 'ocr_text': ocrText,
      if (sourceMimeType != null) 'source_mime_type': sourceMimeType,
      if (sourceFingerprint != null) 'source_fingerprint': sourceFingerprint,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DbDocumentCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceType,
    Value<String?>? localImagePath,
    Value<String?>? ocrText,
    Value<String?>? sourceMimeType,
    Value<String?>? sourceFingerprint,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DbDocumentCompanion(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      localImagePath: localImagePath ?? this.localImagePath,
      ocrText: ocrText ?? this.ocrText,
      sourceMimeType: sourceMimeType ?? this.sourceMimeType,
      sourceFingerprint: sourceFingerprint ?? this.sourceFingerprint,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (localImagePath.present) {
      map['local_image_path'] = Variable<String>(localImagePath.value);
    }
    if (ocrText.present) {
      map['ocr_text'] = Variable<String>(ocrText.value);
    }
    if (sourceMimeType.present) {
      map['source_mime_type'] = Variable<String>(sourceMimeType.value);
    }
    if (sourceFingerprint.present) {
      map['source_fingerprint'] = Variable<String>(sourceFingerprint.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbDocumentCompanion(')
          ..write('id: $id, ')
          ..write('sourceType: $sourceType, ')
          ..write('localImagePath: $localImagePath, ')
          ..write('ocrText: $ocrText, ')
          ..write('sourceMimeType: $sourceMimeType, ')
          ..write('sourceFingerprint: $sourceFingerprint, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DbDocumentPageTable extends DbDocumentPage
    with TableInfo<$DbDocumentPageTable, DbDocumentPageData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbDocumentPageTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageIndexMeta = const VerificationMeta(
    'pageIndex',
  );
  @override
  late final GeneratedColumn<int> pageIndex = GeneratedColumn<int>(
    'page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localImagePathMeta = const VerificationMeta(
    'localImagePath',
  );
  @override
  late final GeneratedColumn<String> localImagePath = GeneratedColumn<String>(
    'local_image_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ocrTextMeta = const VerificationMeta(
    'ocrText',
  );
  @override
  late final GeneratedColumn<String> ocrText = GeneratedColumn<String>(
    'ocr_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    documentId,
    pageIndex,
    localImagePath,
    ocrText,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_document_page';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbDocumentPageData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('page_index')) {
      context.handle(
        _pageIndexMeta,
        pageIndex.isAcceptableOrUnknown(data['page_index']!, _pageIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIndexMeta);
    }
    if (data.containsKey('local_image_path')) {
      context.handle(
        _localImagePathMeta,
        localImagePath.isAcceptableOrUnknown(
          data['local_image_path']!,
          _localImagePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localImagePathMeta);
    }
    if (data.containsKey('ocr_text')) {
      context.handle(
        _ocrTextMeta,
        ocrText.isAcceptableOrUnknown(data['ocr_text']!, _ocrTextMeta),
      );
    } else if (isInserting) {
      context.missing(_ocrTextMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {documentId, pageIndex},
  ];
  @override
  DbDocumentPageData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbDocumentPageData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      pageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_index'],
      )!,
      localImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_image_path'],
      )!,
      ocrText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ocr_text'],
      )!,
    );
  }

  @override
  $DbDocumentPageTable createAlias(String alias) {
    return $DbDocumentPageTable(attachedDatabase, alias);
  }
}

class DbDocumentPageData extends DataClass
    implements Insertable<DbDocumentPageData> {
  final String id;
  final String documentId;
  final int pageIndex;
  final String localImagePath;
  final String ocrText;
  const DbDocumentPageData({
    required this.id,
    required this.documentId,
    required this.pageIndex,
    required this.localImagePath,
    required this.ocrText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['document_id'] = Variable<String>(documentId);
    map['page_index'] = Variable<int>(pageIndex);
    map['local_image_path'] = Variable<String>(localImagePath);
    map['ocr_text'] = Variable<String>(ocrText);
    return map;
  }

  DbDocumentPageCompanion toCompanion(bool nullToAbsent) {
    return DbDocumentPageCompanion(
      id: Value(id),
      documentId: Value(documentId),
      pageIndex: Value(pageIndex),
      localImagePath: Value(localImagePath),
      ocrText: Value(ocrText),
    );
  }

  factory DbDocumentPageData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbDocumentPageData(
      id: serializer.fromJson<String>(json['id']),
      documentId: serializer.fromJson<String>(json['documentId']),
      pageIndex: serializer.fromJson<int>(json['pageIndex']),
      localImagePath: serializer.fromJson<String>(json['localImagePath']),
      ocrText: serializer.fromJson<String>(json['ocrText']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'documentId': serializer.toJson<String>(documentId),
      'pageIndex': serializer.toJson<int>(pageIndex),
      'localImagePath': serializer.toJson<String>(localImagePath),
      'ocrText': serializer.toJson<String>(ocrText),
    };
  }

  DbDocumentPageData copyWith({
    String? id,
    String? documentId,
    int? pageIndex,
    String? localImagePath,
    String? ocrText,
  }) => DbDocumentPageData(
    id: id ?? this.id,
    documentId: documentId ?? this.documentId,
    pageIndex: pageIndex ?? this.pageIndex,
    localImagePath: localImagePath ?? this.localImagePath,
    ocrText: ocrText ?? this.ocrText,
  );
  DbDocumentPageData copyWithCompanion(DbDocumentPageCompanion data) {
    return DbDocumentPageData(
      id: data.id.present ? data.id.value : this.id,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      pageIndex: data.pageIndex.present ? data.pageIndex.value : this.pageIndex,
      localImagePath: data.localImagePath.present
          ? data.localImagePath.value
          : this.localImagePath,
      ocrText: data.ocrText.present ? data.ocrText.value : this.ocrText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbDocumentPageData(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('localImagePath: $localImagePath, ')
          ..write('ocrText: $ocrText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, documentId, pageIndex, localImagePath, ocrText);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbDocumentPageData &&
          other.id == this.id &&
          other.documentId == this.documentId &&
          other.pageIndex == this.pageIndex &&
          other.localImagePath == this.localImagePath &&
          other.ocrText == this.ocrText);
}

class DbDocumentPageCompanion extends UpdateCompanion<DbDocumentPageData> {
  final Value<String> id;
  final Value<String> documentId;
  final Value<int> pageIndex;
  final Value<String> localImagePath;
  final Value<String> ocrText;
  final Value<int> rowid;
  const DbDocumentPageCompanion({
    this.id = const Value.absent(),
    this.documentId = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.localImagePath = const Value.absent(),
    this.ocrText = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DbDocumentPageCompanion.insert({
    required String id,
    required String documentId,
    required int pageIndex,
    required String localImagePath,
    required String ocrText,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       documentId = Value(documentId),
       pageIndex = Value(pageIndex),
       localImagePath = Value(localImagePath),
       ocrText = Value(ocrText);
  static Insertable<DbDocumentPageData> custom({
    Expression<String>? id,
    Expression<String>? documentId,
    Expression<int>? pageIndex,
    Expression<String>? localImagePath,
    Expression<String>? ocrText,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (documentId != null) 'document_id': documentId,
      if (pageIndex != null) 'page_index': pageIndex,
      if (localImagePath != null) 'local_image_path': localImagePath,
      if (ocrText != null) 'ocr_text': ocrText,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DbDocumentPageCompanion copyWith({
    Value<String>? id,
    Value<String>? documentId,
    Value<int>? pageIndex,
    Value<String>? localImagePath,
    Value<String>? ocrText,
    Value<int>? rowid,
  }) {
    return DbDocumentPageCompanion(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      pageIndex: pageIndex ?? this.pageIndex,
      localImagePath: localImagePath ?? this.localImagePath,
      ocrText: ocrText ?? this.ocrText,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (pageIndex.present) {
      map['page_index'] = Variable<int>(pageIndex.value);
    }
    if (localImagePath.present) {
      map['local_image_path'] = Variable<String>(localImagePath.value);
    }
    if (ocrText.present) {
      map['ocr_text'] = Variable<String>(ocrText.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbDocumentPageCompanion(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('localImagePath: $localImagePath, ')
          ..write('ocrText: $ocrText, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DbChildTable dbChild = $DbChildTable(this);
  late final $DbTodoTable dbTodo = $DbTodoTable(this);
  late final $DbChecklistItemTable dbChecklistItem = $DbChecklistItemTable(
    this,
  );
  late final $DbDocumentTable dbDocument = $DbDocumentTable(this);
  late final $DbDocumentPageTable dbDocumentPage = $DbDocumentPageTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    dbChild,
    dbTodo,
    dbChecklistItem,
    dbDocument,
    dbDocumentPage,
  ];
}

typedef $$DbChildTableCreateCompanionBuilder =
    DbChildCompanion Function({
      required String id,
      required String name,
      required int colorValue,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$DbChildTableUpdateCompanionBuilder =
    DbChildCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> colorValue,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$DbChildTableFilterComposer
    extends Composer<_$AppDatabase, $DbChildTable> {
  $$DbChildTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DbChildTableOrderingComposer
    extends Composer<_$AppDatabase, $DbChildTable> {
  $$DbChildTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbChildTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbChildTable> {
  $$DbChildTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DbChildTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbChildTable,
          DbChildData,
          $$DbChildTableFilterComposer,
          $$DbChildTableOrderingComposer,
          $$DbChildTableAnnotationComposer,
          $$DbChildTableCreateCompanionBuilder,
          $$DbChildTableUpdateCompanionBuilder,
          (
            DbChildData,
            BaseReferences<_$AppDatabase, $DbChildTable, DbChildData>,
          ),
          DbChildData,
          PrefetchHooks Function()
        > {
  $$DbChildTableTableManager(_$AppDatabase db, $DbChildTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbChildTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbChildTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbChildTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DbChildCompanion(
                id: id,
                name: name,
                colorValue: colorValue,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int colorValue,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DbChildCompanion.insert(
                id: id,
                name: name,
                colorValue: colorValue,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbChildTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbChildTable,
      DbChildData,
      $$DbChildTableFilterComposer,
      $$DbChildTableOrderingComposer,
      $$DbChildTableAnnotationComposer,
      $$DbChildTableCreateCompanionBuilder,
      $$DbChildTableUpdateCompanionBuilder,
      (DbChildData, BaseReferences<_$AppDatabase, $DbChildTable, DbChildData>),
      DbChildData,
      PrefetchHooks Function()
    >;
typedef $$DbTodoTableCreateCompanionBuilder =
    DbTodoCompanion Function({
      required String id,
      required String title,
      Value<String?> childId,
      Value<String?> documentId,
      Value<DateTime?> dueDate,
      required String category,
      Value<int?> amount,
      Value<String?> note,
      required String status,
      required bool notifyPreviousNight,
      required bool notifySameMorning,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$DbTodoTableUpdateCompanionBuilder =
    DbTodoCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> childId,
      Value<String?> documentId,
      Value<DateTime?> dueDate,
      Value<String> category,
      Value<int?> amount,
      Value<String?> note,
      Value<String> status,
      Value<bool> notifyPreviousNight,
      Value<bool> notifySameMorning,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$DbTodoTableFilterComposer
    extends Composer<_$AppDatabase, $DbTodoTable> {
  $$DbTodoTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get childId => $composableBuilder(
    column: $table.childId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notifyPreviousNight => $composableBuilder(
    column: $table.notifyPreviousNight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notifySameMorning => $composableBuilder(
    column: $table.notifySameMorning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DbTodoTableOrderingComposer
    extends Composer<_$AppDatabase, $DbTodoTable> {
  $$DbTodoTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get childId => $composableBuilder(
    column: $table.childId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notifyPreviousNight => $composableBuilder(
    column: $table.notifyPreviousNight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notifySameMorning => $composableBuilder(
    column: $table.notifySameMorning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbTodoTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbTodoTable> {
  $$DbTodoTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get childId =>
      $composableBuilder(column: $table.childId, builder: (column) => column);

  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get notifyPreviousNight => $composableBuilder(
    column: $table.notifyPreviousNight,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get notifySameMorning => $composableBuilder(
    column: $table.notifySameMorning,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DbTodoTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbTodoTable,
          DbTodoData,
          $$DbTodoTableFilterComposer,
          $$DbTodoTableOrderingComposer,
          $$DbTodoTableAnnotationComposer,
          $$DbTodoTableCreateCompanionBuilder,
          $$DbTodoTableUpdateCompanionBuilder,
          (DbTodoData, BaseReferences<_$AppDatabase, $DbTodoTable, DbTodoData>),
          DbTodoData,
          PrefetchHooks Function()
        > {
  $$DbTodoTableTableManager(_$AppDatabase db, $DbTodoTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbTodoTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbTodoTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbTodoTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> childId = const Value.absent(),
                Value<String?> documentId = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int?> amount = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> notifyPreviousNight = const Value.absent(),
                Value<bool> notifySameMorning = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DbTodoCompanion(
                id: id,
                title: title,
                childId: childId,
                documentId: documentId,
                dueDate: dueDate,
                category: category,
                amount: amount,
                note: note,
                status: status,
                notifyPreviousNight: notifyPreviousNight,
                notifySameMorning: notifySameMorning,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> childId = const Value.absent(),
                Value<String?> documentId = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                required String category,
                Value<int?> amount = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required String status,
                required bool notifyPreviousNight,
                required bool notifySameMorning,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DbTodoCompanion.insert(
                id: id,
                title: title,
                childId: childId,
                documentId: documentId,
                dueDate: dueDate,
                category: category,
                amount: amount,
                note: note,
                status: status,
                notifyPreviousNight: notifyPreviousNight,
                notifySameMorning: notifySameMorning,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbTodoTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbTodoTable,
      DbTodoData,
      $$DbTodoTableFilterComposer,
      $$DbTodoTableOrderingComposer,
      $$DbTodoTableAnnotationComposer,
      $$DbTodoTableCreateCompanionBuilder,
      $$DbTodoTableUpdateCompanionBuilder,
      (DbTodoData, BaseReferences<_$AppDatabase, $DbTodoTable, DbTodoData>),
      DbTodoData,
      PrefetchHooks Function()
    >;
typedef $$DbChecklistItemTableCreateCompanionBuilder =
    DbChecklistItemCompanion Function({
      required String id,
      required String todoId,
      required String label,
      required bool isChecked,
      Value<int> rowid,
    });
typedef $$DbChecklistItemTableUpdateCompanionBuilder =
    DbChecklistItemCompanion Function({
      Value<String> id,
      Value<String> todoId,
      Value<String> label,
      Value<bool> isChecked,
      Value<int> rowid,
    });

class $$DbChecklistItemTableFilterComposer
    extends Composer<_$AppDatabase, $DbChecklistItemTable> {
  $$DbChecklistItemTableFilterComposer({
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

  ColumnFilters<String> get todoId => $composableBuilder(
    column: $table.todoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isChecked => $composableBuilder(
    column: $table.isChecked,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DbChecklistItemTableOrderingComposer
    extends Composer<_$AppDatabase, $DbChecklistItemTable> {
  $$DbChecklistItemTableOrderingComposer({
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

  ColumnOrderings<String> get todoId => $composableBuilder(
    column: $table.todoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isChecked => $composableBuilder(
    column: $table.isChecked,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbChecklistItemTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbChecklistItemTable> {
  $$DbChecklistItemTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get todoId =>
      $composableBuilder(column: $table.todoId, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<bool> get isChecked =>
      $composableBuilder(column: $table.isChecked, builder: (column) => column);
}

class $$DbChecklistItemTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbChecklistItemTable,
          DbChecklistItemData,
          $$DbChecklistItemTableFilterComposer,
          $$DbChecklistItemTableOrderingComposer,
          $$DbChecklistItemTableAnnotationComposer,
          $$DbChecklistItemTableCreateCompanionBuilder,
          $$DbChecklistItemTableUpdateCompanionBuilder,
          (
            DbChecklistItemData,
            BaseReferences<
              _$AppDatabase,
              $DbChecklistItemTable,
              DbChecklistItemData
            >,
          ),
          DbChecklistItemData,
          PrefetchHooks Function()
        > {
  $$DbChecklistItemTableTableManager(
    _$AppDatabase db,
    $DbChecklistItemTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbChecklistItemTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbChecklistItemTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbChecklistItemTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> todoId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<bool> isChecked = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DbChecklistItemCompanion(
                id: id,
                todoId: todoId,
                label: label,
                isChecked: isChecked,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String todoId,
                required String label,
                required bool isChecked,
                Value<int> rowid = const Value.absent(),
              }) => DbChecklistItemCompanion.insert(
                id: id,
                todoId: todoId,
                label: label,
                isChecked: isChecked,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbChecklistItemTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbChecklistItemTable,
      DbChecklistItemData,
      $$DbChecklistItemTableFilterComposer,
      $$DbChecklistItemTableOrderingComposer,
      $$DbChecklistItemTableAnnotationComposer,
      $$DbChecklistItemTableCreateCompanionBuilder,
      $$DbChecklistItemTableUpdateCompanionBuilder,
      (
        DbChecklistItemData,
        BaseReferences<
          _$AppDatabase,
          $DbChecklistItemTable,
          DbChecklistItemData
        >,
      ),
      DbChecklistItemData,
      PrefetchHooks Function()
    >;
typedef $$DbDocumentTableCreateCompanionBuilder =
    DbDocumentCompanion Function({
      required String id,
      required String sourceType,
      Value<String?> localImagePath,
      Value<String?> ocrText,
      Value<String?> sourceMimeType,
      Value<String?> sourceFingerprint,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$DbDocumentTableUpdateCompanionBuilder =
    DbDocumentCompanion Function({
      Value<String> id,
      Value<String> sourceType,
      Value<String?> localImagePath,
      Value<String?> ocrText,
      Value<String?> sourceMimeType,
      Value<String?> sourceFingerprint,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$DbDocumentTableFilterComposer
    extends Composer<_$AppDatabase, $DbDocumentTable> {
  $$DbDocumentTableFilterComposer({
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

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localImagePath => $composableBuilder(
    column: $table.localImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ocrText => $composableBuilder(
    column: $table.ocrText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceMimeType => $composableBuilder(
    column: $table.sourceMimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceFingerprint => $composableBuilder(
    column: $table.sourceFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DbDocumentTableOrderingComposer
    extends Composer<_$AppDatabase, $DbDocumentTable> {
  $$DbDocumentTableOrderingComposer({
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

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localImagePath => $composableBuilder(
    column: $table.localImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ocrText => $composableBuilder(
    column: $table.ocrText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceMimeType => $composableBuilder(
    column: $table.sourceMimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceFingerprint => $composableBuilder(
    column: $table.sourceFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbDocumentTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbDocumentTable> {
  $$DbDocumentTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localImagePath => $composableBuilder(
    column: $table.localImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ocrText =>
      $composableBuilder(column: $table.ocrText, builder: (column) => column);

  GeneratedColumn<String> get sourceMimeType => $composableBuilder(
    column: $table.sourceMimeType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceFingerprint => $composableBuilder(
    column: $table.sourceFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DbDocumentTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbDocumentTable,
          DbDocumentData,
          $$DbDocumentTableFilterComposer,
          $$DbDocumentTableOrderingComposer,
          $$DbDocumentTableAnnotationComposer,
          $$DbDocumentTableCreateCompanionBuilder,
          $$DbDocumentTableUpdateCompanionBuilder,
          (
            DbDocumentData,
            BaseReferences<_$AppDatabase, $DbDocumentTable, DbDocumentData>,
          ),
          DbDocumentData,
          PrefetchHooks Function()
        > {
  $$DbDocumentTableTableManager(_$AppDatabase db, $DbDocumentTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbDocumentTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbDocumentTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbDocumentTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String?> localImagePath = const Value.absent(),
                Value<String?> ocrText = const Value.absent(),
                Value<String?> sourceMimeType = const Value.absent(),
                Value<String?> sourceFingerprint = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DbDocumentCompanion(
                id: id,
                sourceType: sourceType,
                localImagePath: localImagePath,
                ocrText: ocrText,
                sourceMimeType: sourceMimeType,
                sourceFingerprint: sourceFingerprint,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceType,
                Value<String?> localImagePath = const Value.absent(),
                Value<String?> ocrText = const Value.absent(),
                Value<String?> sourceMimeType = const Value.absent(),
                Value<String?> sourceFingerprint = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DbDocumentCompanion.insert(
                id: id,
                sourceType: sourceType,
                localImagePath: localImagePath,
                ocrText: ocrText,
                sourceMimeType: sourceMimeType,
                sourceFingerprint: sourceFingerprint,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbDocumentTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbDocumentTable,
      DbDocumentData,
      $$DbDocumentTableFilterComposer,
      $$DbDocumentTableOrderingComposer,
      $$DbDocumentTableAnnotationComposer,
      $$DbDocumentTableCreateCompanionBuilder,
      $$DbDocumentTableUpdateCompanionBuilder,
      (
        DbDocumentData,
        BaseReferences<_$AppDatabase, $DbDocumentTable, DbDocumentData>,
      ),
      DbDocumentData,
      PrefetchHooks Function()
    >;
typedef $$DbDocumentPageTableCreateCompanionBuilder =
    DbDocumentPageCompanion Function({
      required String id,
      required String documentId,
      required int pageIndex,
      required String localImagePath,
      required String ocrText,
      Value<int> rowid,
    });
typedef $$DbDocumentPageTableUpdateCompanionBuilder =
    DbDocumentPageCompanion Function({
      Value<String> id,
      Value<String> documentId,
      Value<int> pageIndex,
      Value<String> localImagePath,
      Value<String> ocrText,
      Value<int> rowid,
    });

class $$DbDocumentPageTableFilterComposer
    extends Composer<_$AppDatabase, $DbDocumentPageTable> {
  $$DbDocumentPageTableFilterComposer({
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

  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localImagePath => $composableBuilder(
    column: $table.localImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ocrText => $composableBuilder(
    column: $table.ocrText,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DbDocumentPageTableOrderingComposer
    extends Composer<_$AppDatabase, $DbDocumentPageTable> {
  $$DbDocumentPageTableOrderingComposer({
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

  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localImagePath => $composableBuilder(
    column: $table.localImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ocrText => $composableBuilder(
    column: $table.ocrText,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbDocumentPageTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbDocumentPageTable> {
  $$DbDocumentPageTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pageIndex =>
      $composableBuilder(column: $table.pageIndex, builder: (column) => column);

  GeneratedColumn<String> get localImagePath => $composableBuilder(
    column: $table.localImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ocrText =>
      $composableBuilder(column: $table.ocrText, builder: (column) => column);
}

class $$DbDocumentPageTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbDocumentPageTable,
          DbDocumentPageData,
          $$DbDocumentPageTableFilterComposer,
          $$DbDocumentPageTableOrderingComposer,
          $$DbDocumentPageTableAnnotationComposer,
          $$DbDocumentPageTableCreateCompanionBuilder,
          $$DbDocumentPageTableUpdateCompanionBuilder,
          (
            DbDocumentPageData,
            BaseReferences<
              _$AppDatabase,
              $DbDocumentPageTable,
              DbDocumentPageData
            >,
          ),
          DbDocumentPageData,
          PrefetchHooks Function()
        > {
  $$DbDocumentPageTableTableManager(
    _$AppDatabase db,
    $DbDocumentPageTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbDocumentPageTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbDocumentPageTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbDocumentPageTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<int> pageIndex = const Value.absent(),
                Value<String> localImagePath = const Value.absent(),
                Value<String> ocrText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DbDocumentPageCompanion(
                id: id,
                documentId: documentId,
                pageIndex: pageIndex,
                localImagePath: localImagePath,
                ocrText: ocrText,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String documentId,
                required int pageIndex,
                required String localImagePath,
                required String ocrText,
                Value<int> rowid = const Value.absent(),
              }) => DbDocumentPageCompanion.insert(
                id: id,
                documentId: documentId,
                pageIndex: pageIndex,
                localImagePath: localImagePath,
                ocrText: ocrText,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbDocumentPageTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbDocumentPageTable,
      DbDocumentPageData,
      $$DbDocumentPageTableFilterComposer,
      $$DbDocumentPageTableOrderingComposer,
      $$DbDocumentPageTableAnnotationComposer,
      $$DbDocumentPageTableCreateCompanionBuilder,
      $$DbDocumentPageTableUpdateCompanionBuilder,
      (
        DbDocumentPageData,
        BaseReferences<_$AppDatabase, $DbDocumentPageTable, DbDocumentPageData>,
      ),
      DbDocumentPageData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DbChildTableTableManager get dbChild =>
      $$DbChildTableTableManager(_db, _db.dbChild);
  $$DbTodoTableTableManager get dbTodo =>
      $$DbTodoTableTableManager(_db, _db.dbTodo);
  $$DbChecklistItemTableTableManager get dbChecklistItem =>
      $$DbChecklistItemTableTableManager(_db, _db.dbChecklistItem);
  $$DbDocumentTableTableManager get dbDocument =>
      $$DbDocumentTableTableManager(_db, _db.dbDocument);
  $$DbDocumentPageTableTableManager get dbDocumentPage =>
      $$DbDocumentPageTableTableManager(_db, _db.dbDocumentPage);
}
