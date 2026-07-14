// test/app_state_atomicity_test.dart
// AppStateが永続化成功後にだけ状態を公開し、副作用失敗を再試行することを検証する。

import 'package:ashita_motsumono/src/app_state.dart';
import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/repositories/app_database.dart';
import 'package:ashita_motsumono/src/repositories/drift_store.dart';
import 'package:ashita_motsumono/src/repositories/store.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingDriftStore extends DriftStore {
  _FailingDriftStore(super.database);

  bool failSnapshotWrites = false;
  bool failClear = false;

  @override
  Future<void> saveWithSideEffects(
    AppSnapshot snapshot, {
    Map<String, NotificationSyncOperation> notificationOperations = const {},
    Iterable<String> cleanupPaths = const [],
  }) {
    if (failSnapshotWrites) {
      throw StateError('injected snapshot failure');
    }
    return super.saveWithSideEffects(
      snapshot,
      notificationOperations: notificationOperations,
      cleanupPaths: cleanupPaths,
    );
  }

  @override
  Future<void> clearWithSideEffects({
    Iterable<String> notificationTodoIds = const [],
    Iterable<String> cleanupPaths = const [],
  }) {
    if (failClear) {
      throw StateError('injected clear failure');
    }
    return super.clearWithSideEffects(
      notificationTodoIds: notificationTodoIds,
      cleanupPaths: cleanupPaths,
    );
  }
}

class _ControllableNotificationService extends NotificationService {
  _ControllableNotificationService() : super(timezoneName: 'Asia/Tokyo');

  int scheduleAttempts = 0;
  int cancelAttempts = 0;
  bool failNextSchedule = false;
  bool failNextCancel = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> scheduleTodo(AppTodo todo) async {
    scheduleAttempts++;
    if (failNextSchedule) {
      failNextSchedule = false;
      throw StateError('injected schedule failure');
    }
  }

  @override
  Future<void> cancelTodo(String todoId) async {
    cancelAttempts++;
    if (failNextCancel) {
      failNextCancel = false;
      throw StateError('injected cancel failure');
    }
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<(_FailingDriftStore, AppState, _ControllableNotificationService)>
  createSubject() async {
    final database = await AppDatabase.createInMemory();
    final store = _FailingDriftStore(database);
    final notifications = _ControllableNotificationService();
    final appState = AppState(store: store, notifications: notifications);
    await appState.load();
    return (store, appState, notifications);
  }

  test('does not publish child state when persistence fails', () async {
    final (store, appState, _) = await createSubject();
    addTearDown(appState.dispose);
    store.failSnapshotWrites = true;

    await expectLater(appState.addChild('長女'), throwsA(isA<StateError>()));

    expect(appState.children, isEmpty);
    store.failSnapshotWrites = false;
    expect((await store.load()).children, isEmpty);
  });

  test(
    'does not publish todo state or notify when persistence fails',
    () async {
      final (store, appState, notifications) = await createSubject();
      addTearDown(appState.dispose);
      store.failSnapshotWrites = true;

      await expectLater(
        appState.addTodoFromDraft(
          draft: ExtractionDraft(
            title: '水筒',
            category: TodoCategory.item,
            items: const ['水筒'],
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect(appState.todos, isEmpty);
      expect(notifications.scheduleAttempts, 0);
    },
  );

  test('keeps failed schedule queued and clears it after retry', () async {
    final (store, appState, notifications) = await createSubject();
    addTearDown(appState.dispose);
    notifications.failNextSchedule = true;

    final todo = await appState.addTodoFromDraft(
      draft: ExtractionDraft(
        title: '水筒',
        category: TodoCategory.item,
        items: const ['水筒'],
        dueDate: DateTime(2026, 7, 20),
      ),
    );

    expect(appState.todos.single.id, todo.id);
    final pending = await store.loadPendingNotificationSync();
    expect(pending.single.todoId, todo.id);
    expect(pending.single.operation, NotificationSyncOperation.schedule);

    await appState.rescheduleAllNotifications();

    expect(await store.loadPendingNotificationSync(), isEmpty);
    expect(notifications.scheduleAttempts, greaterThanOrEqualTo(2));
  });

  test(
    'keeps failed cancel queued after todo deletion and retries it',
    () async {
      final (store, appState, notifications) = await createSubject();
      addTearDown(appState.dispose);

      final todo = await appState.addTodoFromDraft(
        draft: ExtractionDraft(
          title: '集金袋',
          category: TodoCategory.submit,
          items: const ['集金袋'],
        ),
      );
      notifications.failNextCancel = true;

      await appState.deleteTodo(todo.id);

      expect(appState.todos, isEmpty);
      final pending = await store.loadPendingNotificationSync();
      expect(pending.single.todoId, todo.id);
      expect(pending.single.operation, NotificationSyncOperation.cancel);

      await appState.rescheduleAllNotifications();

      expect(await store.loadPendingNotificationSync(), isEmpty);
      expect(notifications.cancelAttempts, greaterThanOrEqualTo(2));
    },
  );

  test('does not clear visible state when clear transaction fails', () async {
    final (store, appState, _) = await createSubject();
    addTearDown(appState.dispose);
    await appState.addChild('長女');
    store.failClear = true;

    await expectLater(appState.clearAllData(), throwsA(isA<StateError>()));

    expect(appState.children.single.name, '長女');
    store.failClear = false;
    expect((await store.load()).children.single.name, '長女');
  });
}
