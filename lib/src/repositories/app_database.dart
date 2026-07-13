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
import '../services/notification_id_repository.dart';
import 'store.dart';

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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createAuxiliarySchema();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await _repairLegacyReferences();
            await _createAuxiliarySchema();
          }
        },
        beforeOpen: (details) async {
          // Drift公式推奨どおり、マイグレーション完了後に毎回有効化する。
          await customStatement('PRAGMA foreign_keys = ON');
          await _createAuxiliarySchema();
        },
      );

  static Future<AppDatabase> createWithMigration({
    bool skipLegacyMigration = false,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'ashita_motsumono.db'));
    final db = AppDatabase(NativeDatabase(file), databaseFile: file);

    if (skipLegacyMigration) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_migrationDoneKey, true);
      return db;
    }

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

  static Future<void> deleteDatabaseFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'ashita_motsumono.db');
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      final file = File('$path$suffix');
      if (await file.exists()) {
        await file.delete();
      }
    }
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
    return AppDatabase(NativeDatabase.memory());
  }

  @visibleForTesting
  static Future<bool> tryMigration(
    SharedPreferences prefs, {
    void Function(AppSnapshot snapshot)? onMigrated,
  }) async {
    final db = await createInMemory();
    try {
      final migrated = await db._migrateFromPrefs(prefs);
      if (migrated && onMigrated != null) {
        onMigrated(await db.loadSnapshot());
      }
      return migrated;
    } finally {
      await db.close();
    }
  }

  Future<String?> backupDatabaseFile() async {
    final source = databaseFile;
    if (source == null || !await source.exists()) return null;

    try {
      await customStatement('PRAGMA wal_checkpoint(FULL)');
    } on Object {
      // 破損時はcheckpointできない場合があるため、現存ファイルの退避を続行する。
    }

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

  Future<void> saveSnapshot(AppSnapshot snapshot) {
    return saveSnapshotWithSideEffects(snapshot);
  }

  Future<void> saveSnapshotWithSideEffects(
    AppSnapshot snapshot, {
    Map<String, NotificationSyncOperation> notificationOperations = const {},
    Iterable<String> cleanupPaths = const [],
  }) async {
    await transaction(() async {
      await _saveSnapshotRows(snapshot);
      await _queueNotificationSyncRows(notificationOperations);
      await _enqueueFileCleanupRows(cleanupPaths);
    });
  }

  Future<void> _saveSnapshotRows(AppSnapshot snapshot) async {
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

    await batch((batch) {
      if (childRows.isNotEmpty) {
        batch.insertAllOnConflictUpdate(dbChild, childRows);
      }
      if (documentRows.isNotEmpty) {
        batch.insertAllOnConflictUpdate(dbDocument, documentRows);
      }
      if (todoRows.isNotEmpty) {
        batch.insertAllOnConflictUpdate(dbTodo, todoRows);
      }
      if (checklistRows.isNotEmpty) {
        batch.insertAllOnConflictUpdate(dbChecklistItem, checklistRows);
      }
    });

    final itemIds = checklistRows.map((row) => row.id.value).toList();
    if (itemIds.isEmpty) {
      await delete(dbChecklistItem).go();
    } else {
      await (delete(dbChecklistItem)..where((row) => row.id.isNotIn(itemIds))).go();
    }

    final todoIds = snapshot.todos.map((todo) => todo.id).toList();
    if (todoIds.isEmpty) {
      await delete(dbTodo).go();
    } else {
      await (delete(dbTodo)..where((row) => row.id.isNotIn(todoIds))).go();
    }

    final childIds = snapshot.children.map((child) => child.id).toList();
    if (childIds.isEmpty) {
      await delete(dbChild).go();
    } else {
      await (delete(dbChild)..where((row) => row.id.isNotIn(childIds))).go();
    }

    final documentIds = snapshot.documents.map((document) => document.id).toList();
    if (documentIds.isEmpty) {
      await delete(dbDocument).go();
    } else {
      await (delete(dbDocument)..where((row) => row.id.isNotIn(documentIds))).go();
    }
  }

  Future<void> clearAll() async {
    await transaction(_clearDomainRows);
  }

  Future<void> clearAllWithSideEffects({
    Iterable<String> notificationTodoIds = const [],
    Iterable<String> cleanupPaths = const [],
  }) async {
    await transaction(() async {
      await _queueNotificationSyncRows({
        for (final id in notificationTodoIds)
          id: NotificationSyncOperation.cancel,
      });
      await _enqueueFileCleanupRows(cleanupPaths);
      await _clearDomainRows();
    });
  }

  Future<void> _clearDomainRows() async {
    await batch((batch) {
      batch.deleteAll(dbChecklistItem);
      batch.deleteAll(dbTodo);
      batch.deleteAll(dbChild);
      batch.deleteAll(dbDocument);
    });
  }

  Future<NotificationIdPair> getOrCreateNotificationIds(String todoId) async {
    return transaction(() async {
      final existing = await _loadNotificationIdMap(todoId);
      var previousNight = existing[1];
      var sameMorning = existing[2];

      if (previousNight == null) {
        previousNight = await _allocateNotificationId(todoId, 1);
        await customStatement(
          'INSERT INTO notification_id_map '
          '(todo_id, kind, notification_id) VALUES (?, ?, ?)',
          [todoId, 1, previousNight],
        );
      }
      if (sameMorning == null) {
        sameMorning = await _allocateNotificationId(todoId, 2);
        await customStatement(
          'INSERT INTO notification_id_map '
          '(todo_id, kind, notification_id) VALUES (?, ?, ?)',
          [todoId, 2, sameMorning],
        );
      }

      return NotificationIdPair(
        previousNight: previousNight,
        sameMorning: sameMorning,
      );
    });
  }

  Future<NotificationIdPair?> findNotificationIds(String todoId) async {
    final ids = await _loadNotificationIdMap(todoId);
    final previousNight = ids[1];
    final sameMorning = ids[2];
    if (previousNight == null || sameMorning == null) return null;
    return NotificationIdPair(
      previousNight: previousNight,
      sameMorning: sameMorning,
    );
  }

  Future<Map<int, int>> _loadNotificationIdMap(String todoId) async {
    final rows = await customSelect(
      'SELECT kind, notification_id FROM notification_id_map WHERE todo_id = ?',
      variables: [Variable<String>(todoId)],
    ).get();
    return {
      for (final row in rows)
        row.read<int>('kind'): row.read<int>('notification_id'),
    };
  }

  Future<int> _allocateNotificationId(String todoId, int kind) async {
    var candidate = _notificationSeed(todoId, kind);
    for (var attempts = 0; attempts < 0x7FFFFFFF; attempts++) {
      final used = await customSelect(
        'SELECT 1 FROM notification_id_map WHERE notification_id = ? LIMIT 1',
        variables: [Variable<int>(candidate)],
      ).getSingleOrNull();
      if (used == null) return candidate;
      candidate = candidate == 0x7FFFFFFF ? 1 : candidate + 1;
    }
    throw StateError('No local notification IDs are available.');
  }

  int _notificationSeed(String todoId, int kind) {
    var hash = 0;
    for (final codeUnit in todoId.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7FFFFFFF;
    }
    final candidate = (hash ^ kind) & 0x7FFFFFFF;
    return candidate == 0 ? kind : candidate;
  }

  Future<void> releaseNotificationIds(String todoId) async {
    await customStatement(
      'DELETE FROM notification_id_map WHERE todo_id = ?',
      [todoId],
    );
  }

  Future<void> queueNotificationSync(
    String todoId,
    NotificationSyncOperation operation, {
    String? lastError,
  }) async {
    await _queueNotificationSyncRows(
      {todoId: operation},
      lastErrors: {if (lastError != null) todoId: lastError},
    );
  }

  Future<void> _queueNotificationSyncRows(
    Map<String, NotificationSyncOperation> operations, {
    Map<String, String> lastErrors = const {},
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    for (final entry in operations.entries) {
      await customStatement(
        'INSERT INTO notification_sync_queue '
        '(todo_id, operation, updated_at, last_error) VALUES (?, ?, ?, ?) '
        'ON CONFLICT(todo_id) DO UPDATE SET '
        'operation = excluded.operation, updated_at = excluded.updated_at, '
        'last_error = excluded.last_error',
        [entry.key, entry.value.name, now, lastErrors[entry.key]],
      );
    }
  }

  Future<List<PendingNotificationSync>> loadPendingNotificationSync() async {
    final rows = await customSelect(
      'SELECT todo_id, operation, updated_at, last_error '
      'FROM notification_sync_queue ORDER BY updated_at',
    ).get();
    return rows
        .map(
          (row) => PendingNotificationSync(
            todoId: row.read<String>('todo_id'),
            operation: NotificationSyncOperation.fromName(
              row.read<String>('operation'),
            ),
            updatedAt: DateTime.tryParse(row.read<String>('updated_at')) ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            lastError: row.data['last_error'] as String?,
          ),
        )
        .toList();
  }

  Future<void> completeNotificationSync(
    String todoId, {
    bool releaseIds = false,
  }) async {
    await transaction(() async {
      if (releaseIds) {
        await releaseNotificationIds(todoId);
      }
      await customStatement(
        'DELETE FROM notification_sync_queue WHERE todo_id = ?',
        [todoId],
      );
    });
  }

  Future<void> enqueueFileCleanup(Iterable<String> paths) {
    return _enqueueFileCleanupRows(paths);
  }

  Future<void> _enqueueFileCleanupRows(Iterable<String> paths) async {
    final now = DateTime.now().toUtc().toIso8601String();
    for (final path in paths.toSet()) {
      if (path.trim().isEmpty) continue;
      await customStatement(
        'INSERT INTO pending_file_cleanup (path, updated_at, last_error) '
        'VALUES (?, ?, NULL) '
        'ON CONFLICT(path) DO UPDATE SET updated_at = excluded.updated_at',
        [path, now],
      );
    }
  }

  Future<List<String>> loadPendingFileCleanup() async {
    final rows = await customSelect(
      'SELECT path FROM pending_file_cleanup ORDER BY updated_at',
    ).get();
    return rows.map((row) => row.read<String>('path')).toList();
  }

  Future<void> markFileCleanupComplete(String path) async {
    await customStatement(
      'DELETE FROM pending_file_cleanup WHERE path = ?',
      [path],
    );
  }

  Future<void> markFileCleanupFailed(String path, Object error) async {
    await customStatement(
      'UPDATE pending_file_cleanup SET updated_at = ?, last_error = ? '
      'WHERE path = ?',
      [
        DateTime.now().toUtc().toIso8601String(),
        error.toString(),
        path,
      ],
    );
  }

  Future<void> _repairLegacyReferences() async {
    await customStatement(
      'DELETE FROM db_checklist_item '
      'WHERE todo_id NOT IN (SELECT id FROM db_todo)',
    );
    await customStatement(
      'UPDATE db_todo SET child_id = NULL '
      'WHERE child_id IS NOT NULL '
      'AND child_id NOT IN (SELECT id FROM db_child)',
    );
    await customStatement(
      'UPDATE db_todo SET document_id = NULL '
      'WHERE document_id IS NOT NULL '
      'AND document_id NOT IN (SELECT id FROM db_document)',
    );
  }

  Future<void> _createAuxiliarySchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS notification_id_map (
        todo_id TEXT NOT NULL,
        kind INTEGER NOT NULL CHECK(kind IN (1, 2)),
        notification_id INTEGER NOT NULL UNIQUE
          CHECK(notification_id BETWEEN 1 AND 2147483647),
        PRIMARY KEY(todo_id, kind)
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS notification_sync_queue (
        todo_id TEXT PRIMARY KEY,
        operation TEXT NOT NULL CHECK(operation IN ('schedule', 'cancel')),
        updated_at TEXT NOT NULL,
        last_error TEXT
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS pending_file_cleanup (
        path TEXT PRIMARY KEY,
        updated_at TEXT NOT NULL,
        last_error TEXT
      )
    ''');

    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS validate_todo_child_insert
      BEFORE INSERT ON db_todo
      WHEN NEW.child_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM db_child WHERE id = NEW.child_id)
      BEGIN
        SELECT RAISE(ABORT, 'db_todo.child_id references a missing child');
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS validate_todo_child_update
      BEFORE UPDATE OF child_id ON db_todo
      WHEN NEW.child_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM db_child WHERE id = NEW.child_id)
      BEGIN
        SELECT RAISE(ABORT, 'db_todo.child_id references a missing child');
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS validate_todo_document_insert
      BEFORE INSERT ON db_todo
      WHEN NEW.document_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM db_document WHERE id = NEW.document_id)
      BEGIN
        SELECT RAISE(ABORT, 'db_todo.document_id references a missing document');
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS validate_todo_document_update
      BEFORE UPDATE OF document_id ON db_todo
      WHEN NEW.document_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM db_document WHERE id = NEW.document_id)
      BEGIN
        SELECT RAISE(ABORT, 'db_todo.document_id references a missing document');
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS validate_checklist_todo_insert
      BEFORE INSERT ON db_checklist_item
      WHEN NOT EXISTS (SELECT 1 FROM db_todo WHERE id = NEW.todo_id)
      BEGIN
        SELECT RAISE(ABORT, 'db_checklist_item.todo_id references a missing todo');
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS validate_checklist_todo_update
      BEFORE UPDATE OF todo_id ON db_checklist_item
      WHEN NOT EXISTS (SELECT 1 FROM db_todo WHERE id = NEW.todo_id)
      BEGIN
        SELECT RAISE(ABORT, 'db_checklist_item.todo_id references a missing todo');
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS clear_todo_child_on_delete
      AFTER DELETE ON db_child
      BEGIN
        UPDATE db_todo SET child_id = NULL WHERE child_id = OLD.id;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS clear_todo_document_on_delete
      AFTER DELETE ON db_document
      BEGIN
        UPDATE db_todo SET document_id = NULL WHERE document_id = OLD.id;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS delete_checklist_on_todo_delete
      AFTER DELETE ON db_todo
      BEGIN
        DELETE FROM db_checklist_item WHERE todo_id = OLD.id;
      END
    ''');
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
