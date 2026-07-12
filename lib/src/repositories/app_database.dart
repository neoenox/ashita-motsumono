// lib/src/repositories/app_database.dart
// Drift（SQLite）データベース定義。テーブル定義とCRUDを一括管理。
// 関連: drift_store.dart, models/entities.dart, repositories/store.dart

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entities.dart';

part 'app_database.g.dart';

class DbChild extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorValue => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class DbTodo extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get childId => text().nullable()();
  TextColumn get documentId => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get category => text()();
  IntColumn get amount => integer().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get status => text()();
  BoolColumn get notifyPreviousNight => boolean()();
  BoolColumn get notifySameMorning => boolean()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class DbChecklistItem extends Table {
  TextColumn get id => text()();
  TextColumn get todoId => text()();
  TextColumn get label => text()();
  BoolColumn get isChecked => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

class DbDocument extends Table {
  TextColumn get id => text()();
  TextColumn get sourceType => text()();
  TextColumn get localImagePath => text().nullable()();
  TextColumn get ocrText => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [DbChild, DbTodo, DbChecklistItem, DbDocument])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e, {this.databaseFile});

  final File? databaseFile;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v1→v2: 将来のスキーマ変更対応（現状はプレースホルダー）
        },
      );

  static Future<AppDatabase> createWithMigration() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'ashita_motsumono.db'));
    final db = AppDatabase(NativeDatabase(file), databaseFile: file);
    await db.customStatement('PRAGMA foreign_keys = OFF');

    final prefs = await SharedPreferences.getInstance();
    final migrated = prefs.getBool(_migrationDoneKey) ?? false;
    if (!migrated) {
      final ok = await db._migrateFromPrefs(prefs);
      if (ok) {
        await prefs.setBool(_migrationDoneKey, true);
      }
    }
    return db;
  }

  Future<bool> _migrateFromPrefs(SharedPreferences prefs) async {
    const key = 'ashita_motsumono_snapshot_v1';
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return true;

    await _backupRawSnapshot(raw);

    try {
      final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
      final snapshot = AppSnapshot.fromJson(jsonMap).migrate();
      await saveSnapshot(snapshot);
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _backupRawSnapshot(String rawJson) async {
    try {
      final dir = databaseFile?.parent ?? await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final backup = File(
        p.join(dir.path, 'ashita_motsumono_legacy_backup_$stamp.json'),
      );
      await backup.writeAsString(rawJson);
    } on Object {
      // バックアップ失敗は移行をブロックしない
    }
  }

  static const _migrationDoneKey = 'ashita_motsumono_drift_migrated_v1';

  static Future<AppDatabase> createInMemory() async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = OFF');
    return db;
  }

  @visibleForTesting
  static Future<bool> tryMigration(SharedPreferences prefs) async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      return await db._migrateFromPrefs(prefs);
    } finally {
      await db.close();
    }
  }

  @visibleForTesting
  static Future<AppSnapshot?> migrateSnapshotForTesting(
    SharedPreferences prefs,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      final migrated = await db._migrateFromPrefs(prefs);
      if (!migrated) return null;
      return await db.loadSnapshot();
    } finally {
      await db.close();
    }
  }

  Future<String?> backupDatabaseFile() async {
    final source = databaseFile;
    if (source == null || !await source.exists()) return null;

    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final backup = File(
      p.join(source.parent.path, 'ashita_motsumono_corrupt_$stamp.db'),
    );
    await source.copy(backup.path);
    return backup.path;
  }

  Future<AppSnapshot> loadSnapshot() async {
    final childRows = await select(dbChild).get();
    final todoRows = await select(dbTodo).get();
    final itemRows = await select(dbChecklistItem).get();
    final docRows = await select(dbDocument).get();

    final itemsByTodo = <String, List<DbChecklistItemData>>{};
    for (final item in itemRows) {
      itemsByTodo.putIfAbsent(item.todoId, () => []).add(item);
    }

    return AppSnapshot(
      children: childRows.map(_toPersonProfile).toList(),
      todos: todoRows
          .map((row) => _toAppTodo(row, itemsByTodo[row.id] ?? []))
          .toList(),
      documents: docRows.map(_toDocumentRecord).toList(),
    );
  }

  Future<void> saveSnapshot(AppSnapshot snapshot) async {
    final childRows = snapshot.children.map(_fromPersonProfile).toList();
    final documentRows = snapshot.documents.map(_fromDocumentRecord).toList();
    final todoRows = snapshot.todos.map(_fromAppTodo).toList();
    final checklistRows = snapshot.todos
        .expand(
          (todo) => todo.items.map(
            (item) => _fromChecklistItem(todo.id, item),
          ),
        )
        .toList();

    await transaction(() async {
      await batch((batch) {
        batch.deleteAll(dbChecklistItem);
        batch.deleteAll(dbTodo);
        batch.deleteAll(dbChild);
        batch.deleteAll(dbDocument);

        if (childRows.isNotEmpty) {
          batch.insertAll(dbChild, childRows);
        }
        if (documentRows.isNotEmpty) {
          batch.insertAll(dbDocument, documentRows);
        }
        if (todoRows.isNotEmpty) {
          batch.insertAll(dbTodo, todoRows);
        }
        if (checklistRows.isNotEmpty) {
          batch.insertAll(dbChecklistItem, checklistRows);
        }
      });
    });
  }

  Future<void> clearAll() async {
    await batch((batch) {
      batch.deleteAll(dbChecklistItem);
      batch.deleteAll(dbTodo);
      batch.deleteAll(dbChild);
      batch.deleteAll(dbDocument);
    });
  }

  PersonProfile _toPersonProfile(DbChildData child) => PersonProfile(
        id: child.id,
        name: child.name,
        colorValue: child.colorValue,
        createdAt: child.createdAt,
        updatedAt: child.updatedAt,
      );

  DbChildCompanion _fromPersonProfile(PersonProfile child) => DbChildCompanion(
        id: Value(child.id),
        name: Value(child.name),
        colorValue: Value(child.colorValue),
        createdAt: Value(child.createdAt),
        updatedAt: Value(child.updatedAt),
      );

  AppTodo _toAppTodo(
    DbTodoData row,
    List<DbChecklistItemData> items,
  ) => AppTodo(
        id: row.id,
        title: row.title,
        personId: row.childId,
        documentId: row.documentId,
        dueDate: row.dueDate,
        category: TodoCategory.fromName(row.category),
        amount: row.amount,
        note: row.note,
        status: TodoStatus.fromName(row.status),
        items: items
            .map(
              (item) => ChecklistItem(
                id: item.id,
                label: item.label,
                isChecked: item.isChecked,
              ),
            )
            .toList(),
        notifyPreviousNight: row.notifyPreviousNight,
        notifySameMorning: row.notifySameMorning,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  DbTodoCompanion _fromAppTodo(AppTodo todo) => DbTodoCompanion(
        id: Value(todo.id),
        title: Value(todo.title),
        childId: Value(todo.personId),
        documentId: Value(todo.documentId),
        dueDate: Value(todo.dueDate),
        category: Value(todo.category.name),
        amount: Value(todo.amount),
        note: Value(todo.note),
        status: Value(todo.status.name),
        notifyPreviousNight: Value(todo.notifyPreviousNight),
        notifySameMorning: Value(todo.notifySameMorning),
        createdAt: Value(todo.createdAt),
        updatedAt: Value(todo.updatedAt),
      );

  DbChecklistItemCompanion _fromChecklistItem(
    String todoId,
    ChecklistItem item,
  ) => DbChecklistItemCompanion(
        id: Value(item.id),
        todoId: Value(todoId),
        label: Value(item.label),
        isChecked: Value(item.isChecked),
      );

  DocumentRecord _toDocumentRecord(DbDocumentData document) => DocumentRecord(
        id: document.id,
        sourceType: document.sourceType,
        localImagePath: document.localImagePath,
        ocrText: document.ocrText,
        createdAt: document.createdAt,
        updatedAt: document.updatedAt,
      );

  DbDocumentCompanion _fromDocumentRecord(DocumentRecord document) =>
      DbDocumentCompanion(
        id: Value(document.id),
        sourceType: Value(document.sourceType),
        localImagePath: Value(document.localImagePath),
        ocrText: Value(document.ocrText),
        createdAt: Value(document.createdAt),
        updatedAt: Value(document.updatedAt),
      );
}
