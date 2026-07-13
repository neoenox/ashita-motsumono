// test/database_schema_migration_test.dart
// schema v1相当のDBをv2へ更新し、参照修復と補助スキーマ作成を検証する。

import 'dart:io';

import 'package:ashita_motsumono/src/repositories/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('upgrades v1 data and repairs legacy orphan references', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'ashita_schema_migration_',
    );
    final file = File('${tempDir.path}${Platform.pathSeparator}migration.db');
    AppDatabase? databaseToClose;

    addTearDown(() async {
      await databaseToClose?.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final legacy = AppDatabase(NativeDatabase(file), databaseFile: file);
    // 現行スキーマで物理テーブルを作った後、v2追加物を除去してv1状態を再現する。
    await legacy.customSelect('SELECT 1').get();
    for (final trigger in const [
      'validate_todo_child_insert',
      'validate_todo_child_update',
      'validate_todo_document_insert',
      'validate_todo_document_update',
      'validate_checklist_todo_insert',
      'validate_checklist_todo_update',
      'clear_todo_child_on_delete',
      'clear_todo_document_on_delete',
      'delete_checklist_on_todo_delete',
    ]) {
      await legacy.customStatement('DROP TRIGGER IF EXISTS $trigger');
    }
    for (final table in const [
      'notification_id_map',
      'notification_sync_queue',
      'pending_file_cleanup',
    ]) {
      await legacy.customStatement('DROP TABLE IF EXISTS $table');
    }

    final now = DateTime(2026, 7, 13);
    await legacy.into(legacy.dbTodo).insert(
          DbTodoCompanion.insert(
            id: 'legacy-todo',
            title: '旧データ',
            childId: const Value('missing-child'),
            documentId: const Value('missing-document'),
            category: 'item',
            status: 'active',
            notifyPreviousNight: true,
            notifySameMorning: true,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await legacy.into(legacy.dbChecklistItem).insert(
          DbChecklistItemCompanion.insert(
            id: 'orphan-item',
            todoId: 'missing-todo',
            label: '孤立項目',
            isChecked: false,
          ),
        );
    await legacy.customStatement('PRAGMA user_version = 1');
    await legacy.close();

    final upgraded = AppDatabase(NativeDatabase(file), databaseFile: file);
    databaseToClose = upgraded;
    final snapshot = await upgraded.loadSnapshot();

    expect(snapshot.todos, hasLength(1));
    expect(snapshot.todos.single.id, 'legacy-todo');
    expect(snapshot.todos.single.personId, isNull);
    expect(snapshot.todos.single.documentId, isNull);
    expect(snapshot.todos.single.items, isEmpty);

    final auxiliaryTables = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name IN ('notification_id_map', "
          "'notification_sync_queue', 'pending_file_cleanup')",
        )
        .map((row) => row.read<String>('name'))
        .get();
    expect(auxiliaryTables.toSet(), {
      'notification_id_map',
      'notification_sync_queue',
      'pending_file_cleanup',
    });

    final validationTriggers = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'trigger' "
          "AND name LIKE 'validate_%'",
        )
        .map((row) => row.read<String>('name'))
        .get();
    expect(validationTriggers, hasLength(6));
  });
}
