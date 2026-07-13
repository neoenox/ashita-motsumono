// test/drift_store_test.dart
// DriftStore 経由の保存/読込、補助キュー、破損DB書込禁止を検証する。
// 関連: lib/src/repositories/drift_store.dart, lib/src/repositories/app_database.dart

import 'dart:io';

import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/repositories/app_database.dart';
import 'package:ashita_motsumono/src/repositories/drift_store.dart';
import 'package:ashita_motsumono/src/repositories/store.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('saves and loads a full snapshot through Store boundary', () async {
    final store = await DriftStore.createInMemory();
    addTearDown(store.close);
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

  test('persists unique notification IDs and side effect queues', () async {
    final store = await DriftStore.createInMemory();
    addTearDown(store.close);

    final first = await store.getOrCreateNotificationIds('todo-a');
    final firstAgain = await store.getOrCreateNotificationIds('todo-a');
    final second = await store.getOrCreateNotificationIds('todo-b');

    expect(firstAgain.previousNight, first.previousNight);
    expect(firstAgain.sameMorning, first.sameMorning);
    expect(
      {...first.values, ...second.values},
      hasLength(4),
    );

    await store.saveWithSideEffects(
      AppSnapshot.empty,
      notificationOperations: const {
        'todo-a': NotificationSyncOperation.cancel,
      },
      cleanupPaths: const ['/tmp/image-a.jpg'],
    );

    final pendingNotifications = await store.loadPendingNotificationSync();
    expect(pendingNotifications, hasLength(1));
    expect(pendingNotifications.single.todoId, 'todo-a');
    expect(
      pendingNotifications.single.operation,
      NotificationSyncOperation.cancel,
    );
    expect(await store.loadPendingFileCleanup(), ['/tmp/image-a.jpg']);

    await store.completeNotificationSync('todo-a', releaseIds: true);
    await store.markFileCleanupComplete('/tmp/image-a.jpg');
    expect(await store.findNotificationIds('todo-a'), isNull);
    expect(await store.loadPendingNotificationSync(), isEmpty);
    expect(await store.loadPendingFileCleanup(), isEmpty);
  });

  test('rejects snapshots with missing referenced records', () async {
    final store = await DriftStore.createInMemory();
    addTearDown(store.close);
    final now = DateTime(2026, 7, 7);

    await expectLater(
      store.save(
        AppSnapshot(
          children: const [],
          documents: const [],
          todos: [
            AppTodo(
              id: 'todo-orphan',
              title: '参照不整合',
              personId: 'missing-child',
              category: TodoCategory.item,
              status: TodoStatus.active,
              items: const [],
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      ),
      throwsA(anything),
    );

    final loaded = await store.load();
    expect(loaded.todos, isEmpty);
  });

  test(
    'throws and blocks writes when sqlite file is corrupt',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'ashita_drift_store_test_',
      );
      DriftStore? store;
      try {
        final dbFile = File(
          '${tempDir.path}${Platform.pathSeparator}broken.db',
        );
        await dbFile.writeAsString('not a sqlite database');
        final db = AppDatabase(NativeDatabase(dbFile), databaseFile: dbFile);
        store = DriftStore(db);

        await expectLater(
          store.load(),
          throwsA(isA<StoreLoadException>()),
        );

        expect(store.lastLoadHadCorruptData, isTrue);
        expect(store.writesBlockedAfterLoadFailure, isTrue);
        expect(store.loadCorruptBackup(), contains('退避コピーを作成しました'));
        expect(
          store.loadCorruptBackup(),
          contains('ashita_motsumono_corrupt_'),
        );
        await expectLater(
          store.save(AppSnapshot.empty),
          throwsA(isA<StateError>()),
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
        await store?.close();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    },
  );
}
