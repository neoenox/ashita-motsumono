// test/app_state_test.dart
// AppState の状態遷移と通知再予約の回帰テスト。
// 関連: lib/src/app_state.dart, lib/src/services/notification_service.dart

import 'package:ashita_motsumono/src/app_state.dart';
import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/repositories/drift_store.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService() : super(timezoneName: 'Asia/Tokyo');

  final List<String> scheduledTodoIds = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> scheduleTodo(AppTodo todo) async {
    scheduledTodoIds.add(todo.id);
  }

  @override
  Future<void> cancelTodo(String todoId) async {}
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('reschedules all stored todos after notification time changes', () async {
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
    expect(notifications.scheduledTodoIds, unorderedEquals(appState.todos.map((todo) => todo.id)));
  });
}
