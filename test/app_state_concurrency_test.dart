import 'dart:async';

import 'package:ashita_motsumono/src/app_state.dart';
import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/repositories/store.dart';
import 'package:ashita_motsumono/src/services/notification_id_repository.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _DelayedStore extends Store {
  AppSnapshot snapshot = AppSnapshot.empty;
  final firstWriteStarted = Completer<void>();
  final releaseFirstWrite = Completer<void>();
  var writes = 0;

  @override
  Future<AppSnapshot> load() async => snapshot;

  @override
  Future<void> save(AppSnapshot value) async {
    writes++;
    if (writes == 1) {
      firstWriteStarted.complete();
      await releaseFirstWrite.future;
    }
    snapshot = value;
  }

  @override
  Future<void> saveWithSideEffects(
    AppSnapshot value, {
    Map<String, NotificationSyncOperation> notificationOperations = const {},
    Iterable<String> cleanupPaths = const [],
  }) =>
      save(value);

  @override
  String? loadCorruptBackup() => null;
  @override
  Future<void> clear() async => snapshot = AppSnapshot.empty;
  @override
  bool get lastLoadHadCorruptData => false;
  @override
  Future<void> resetAfterLoadFailure() async {}
  @override
  Future<void> queueNotificationSync(
    String todoId,
    NotificationSyncOperation operation, {
    String? lastError,
  }) async {}
  @override
  Future<List<PendingNotificationSync>> loadPendingNotificationSync() async =>
      const [];
  @override
  Future<void> completeNotificationSync(
    String todoId, {
    bool releaseIds = false,
  }) async {}
  @override
  Future<void> enqueueFileCleanup(Iterable<String> paths) async {}
  @override
  Future<List<String>> loadPendingFileCleanup() async => const [];
  @override
  Future<void> markFileCleanupComplete(String path) async {}
  @override
  Future<void> markFileCleanupFailed(String path, Object error) async {}
  @override
  Future<NotificationIdPair> getOrCreateNotificationIds(String todoId) async =>
      const NotificationIdPair(previousNight: 1, sameMorning: 2);
  @override
  Future<NotificationIdPair?> findNotificationIds(String todoId) async => null;
  @override
  Future<void> releaseNotificationIds(String todoId) async {}
}

class _NoopNotifications extends NotificationService {
  _NoopNotifications() : super(timezoneName: 'Asia/Tokyo');

  @override
  Future<void> initialize() async {}
  @override
  Future<void> scheduleTodo(AppTodo todo) async {}
  @override
  Future<void> cancelTodo(String todoId) async {}
}

void main() {
  test('concurrent todo additions are serialized without lost updates', () async {
    final store = _DelayedStore();
    final state = AppState(store: store, notifications: _NoopNotifications());
    await state.load();
    addTearDown(state.dispose);

    final first = state.addTodoFromDraft(
      draft: const ExtractionDraft(
        title: 'A',
        category: TodoCategory.item,
        items: ['A'],
      ),
    );
    await store.firstWriteStarted.future;
    final second = state.addTodoFromDraft(
      draft: const ExtractionDraft(
        title: 'B',
        category: TodoCategory.item,
        items: ['B'],
      ),
    );
    store.releaseFirstWrite.complete();

    await Future.wait([first, second]);
    expect(state.todos.map((todo) => todo.title), containsAll(['A', 'B']));
    expect(store.snapshot.todos, hasLength(2));
  });
}
