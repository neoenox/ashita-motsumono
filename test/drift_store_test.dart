// test/drift_store_test.dart
// DriftStore 経由の保存/読込と破損DB退避を検証する。
// 関連: lib/src/repositories/drift_store.dart, lib/src/repositories/app_database.dart

import 'dart:io';

import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/repositories/app_database.dart';
import 'package:ashita_motsumono/src/repositories/drift_store.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('saves and loads a full snapshot through Store boundary', () async {
    final store = await DriftStore.createInMemory();
    final now = DateTime(2026, 7, 7);
    final snapshot = AppSnapshot(
      children: [
        PersonProfile(
          id: 'child-1',
          name: '長女',
          colorValue: 0xFF2F7D6E,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      todos: [
        AppTodo(
          id: 'todo-1',
          title: '水筒を持参',
          personId: 'child-1',
          documentId: 'doc-1',
          dueDate: DateTime(2026, 7, 8),
          category: TodoCategory.item,
          status: TodoStatus.active,
          items: [
            ChecklistItem(id: 'item-1', label: '水筒'),
            ChecklistItem(id: 'item-2', label: '帽子', isChecked: true),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      ],
      documents: [
        DocumentRecord(
          id: 'doc-1',
          sourceType: 'text',
          ocrText: '明日までに水筒と帽子を持参',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    await store.save(snapshot);

    final loaded = await store.load();

    expect(store.lastLoadHadCorruptData, isFalse);
    expect(store.loadCorruptBackup(), isNull);
    expect(loaded.children.single.name, '長女');
    expect(loaded.todos.single.title, '水筒を持参');
    expect(loaded.todos.single.items.map((item) => item.label), ['水筒', '帽子']);
    expect(loaded.todos.single.items.last.isChecked, isTrue);
    expect(loaded.documents.single.ocrText, '明日までに水筒と帽子を持参');
  });

  test(
    'returns an empty snapshot and keeps backup info when sqlite file is corrupt',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'ashita_drift_store_test_',
      );
      AppDatabase? db;
      try {
        final dbFile = File(
          '${tempDir.path}${Platform.pathSeparator}broken.db',
        );
        await dbFile.writeAsString('not a sqlite database');
        db = AppDatabase(NativeDatabase(dbFile), databaseFile: dbFile);
        final store = DriftStore(db);

        final loaded = await store.load();

        expect(loaded.children, isEmpty);
        expect(loaded.todos, isEmpty);
        expect(loaded.documents, isEmpty);
        expect(store.lastLoadHadCorruptData, isTrue);
        expect(store.loadCorruptBackup(), contains('退避コピーを作成しました'));
        expect(
          store.loadCorruptBackup(),
          contains('ashita_motsumono_corrupt_'),
        );

        final backupFiles = tempDir
            .listSync()
            .whereType<File>()
            .where(
              (file) => file.uri.pathSegments.last.startsWith(
                'ashita_motsumono_corrupt_',
              ),
            )
            .toList();
        expect(backupFiles, hasLength(1));
        expect(
          await backupFiles.single.readAsString(),
          'not a sqlite database',
        );
      } finally {
        await db?.close();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    },
  );
}
