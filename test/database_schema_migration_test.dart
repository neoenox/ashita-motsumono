// test/database_schema_migration_test.dart
// 旧DBをschema v4へ更新し、参照修復・ページ制約・索引を検証する。

import 'dart:io';

import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/repositories/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
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
      'db_document_page',
    ]) {
      await legacy.customStatement('DROP TABLE IF EXISTS $table');
    }
    await legacy.customStatement('DROP TABLE IF EXISTS db_document');
    await legacy.customStatement('''
      CREATE TABLE db_document (
        id TEXT NOT NULL PRIMARY KEY,
        source_type TEXT NOT NULL,
        local_image_path TEXT,
        ocr_text TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    final now = DateTime(2026, 7, 13);
    await legacy
        .into(legacy.dbTodo)
        .insert(
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
    await legacy
        .into(legacy.dbChecklistItem)
        .insert(
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

    final indexes = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name IN ('idx_db_document_source_fingerprint', "
          "'idx_db_document_page_document_page_index')",
        )
        .map((row) => row.read<String>('name'))
        .get();
    expect(indexes.toSet(), {
      'idx_db_document_source_fingerprint',
      'idx_db_document_page_document_page_index',
    });
  });

  test('upgrades v3 data to v4 without losing document pages', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'ashita_schema_v4_migration_',
    );
    final file = File('${tempDir.path}${Platform.pathSeparator}migration.db');
    AppDatabase? databaseToClose;

    addTearDown(() async {
      await databaseToClose?.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final v3 = AppDatabase(NativeDatabase(file), databaseFile: file);
    final now = DateTime(2026, 7, 27);
    await v3.saveSnapshot(
      AppSnapshot(
        children: [],
        todos: [],
        documents: [
          DocumentRecord(
            id: 'v3-document',
            sourceType: 'pdf',
            sourceFingerprint: 'v3-fingerprint',
            createdAt: now,
            updatedAt: now,
            pages: const [
              DocumentPageRecord(
                id: 'v3-page-1',
                documentId: 'v3-document',
                pageIndex: 1,
                localImagePath: '/tmp/v3-page-1.jpg',
                ocrText: '',
              ),
              DocumentPageRecord(
                id: 'v3-page-0',
                documentId: 'v3-document',
                pageIndex: 0,
                localImagePath: '/tmp/v3-page-0.jpg',
                ocrText: '本文',
              ),
            ],
          ),
        ],
      ),
    );
    await v3.customStatement(
      'DROP INDEX IF EXISTS idx_db_document_source_fingerprint',
    );
    await v3.customStatement(
      'DROP INDEX IF EXISTS '
      'idx_db_document_page_document_page_index',
    );
    await v3.customStatement('PRAGMA user_version = 3');
    await v3.close();

    final upgraded = AppDatabase(NativeDatabase(file), databaseFile: file);
    databaseToClose = upgraded;
    final snapshot = await upgraded.loadSnapshot();

    expect(snapshot.documents, hasLength(1));
    final document = snapshot.documents.single;
    expect(document.sourceFingerprint, 'v3-fingerprint');
    expect(document.pages.map((page) => page.pageIndex), [0, 1]);
    expect(document.pages.first.ocrText, '本文');

    final indexes = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name IN ('idx_db_document_source_fingerprint', "
          "'idx_db_document_page_document_page_index')",
        )
        .map((row) => row.read<String>('name'))
        .get();
    expect(indexes.toSet(), {
      'idx_db_document_source_fingerprint',
      'idx_db_document_page_document_page_index',
    });
  });
}
