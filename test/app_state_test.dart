// test/app_state_test.dart
// AppState の状態遷移と通知再予約の回帰テスト。
// 関連: lib/src/app_state.dart, lib/src/services/notification_service.dart

import 'dart:io';

import 'package:ashita_motsumono/src/app_state.dart';
import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/repositories/drift_store.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';
import 'package:ashita_motsumono/src/services/sensitive_data_cleaner.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService() : super(timezoneName: 'Asia/Tokyo');

  final List<String> scheduledTodoIds = [];
  final List<String> canceledTodoIds = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> scheduleTodo(AppTodo todo) async {
    scheduledTodoIds.add(todo.id);
  }

  @override
  Future<void> cancelTodo(String todoId) async {
    canceledTodoIds.add(todoId);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'reschedules all stored todos after notification time changes',
    () async {
      final store = await DriftStore.createInMemory();
      final notifications = _FakeNotificationService();
      final appState = AppState(store: store, notifications: notifications);
      await appState.load();

      await appState.addTodoFromDraft(
        draft: ExtractionDraft(
          title: '水筒を持参',
          category: TodoCategory.item,
          items: ['水筒'],
          dueDate: DateTime(2026, 7, 10),
        ),
      );
      await appState.addTodoFromDraft(
        draft: ExtractionDraft(
          title: '集金袋を提出',
          category: TodoCategory.submit,
          items: ['集金袋'],
          dueDate: DateTime(2026, 7, 11),
        ),
      );

      notifications.scheduledTodoIds.clear();

      await appState.rescheduleAllNotifications();

      expect(notifications.scheduledTodoIds, hasLength(2));
      expect(
        notifications.scheduledTodoIds,
        unorderedEquals(appState.todos.map((todo) => todo.id)),
      );
    },
  );

  test(
    'clearAllData removes local records, document images and notifications',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'ashita_clear_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final store = await DriftStore.createInMemory();
      final notifications = _FakeNotificationService();
      final appState = AppState(
        store: store,
        notifications: notifications,
        sensitiveDataCleaner: SensitiveDataCleaner(
          directoryProvider: () async => tempDir,
        ),
      );
      await appState.load();

      final imageFile = File(
        '${tempDir.path}${Platform.pathSeparator}notice.jpg',
      );
      await imageFile.writeAsBytes([1, 2, 3]);

      final child = await appState.addChild('長女');
      final document = await appState.addDocument(
        sourceType: 'camera',
        localImagePath: imageFile.path,
        ocrText: '明日までに水筒',
      );
      final todo = await appState.addTodoFromDraft(
        draft: ExtractionDraft(
          title: '水筒を持参',
          category: TodoCategory.item,
          items: ['水筒'],
          dueDate: DateTime(2026, 7, 10),
        ),
        personId: child.id,
        documentId: document.id,
      );

      await appState.clearAllData(awaitPostDeleteCleanup: true);

      expect(appState.children, isEmpty);
      expect(appState.todos, isEmpty);
      expect(appState.documents, isEmpty);
      expect(await imageFile.exists(), isFalse);
      expect(notifications.canceledTodoIds, contains(todo.id));

      final loaded = await store.load();
      expect(loaded.children, isEmpty);
      expect(loaded.todos, isEmpty);
      expect(loaded.documents, isEmpty);
    },
  );
}
