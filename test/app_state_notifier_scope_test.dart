// test/app_state_notifier_scope_test.dart
// 人物・Todo・Document変更が対象Notifierだけへ通知されることを検証する。

import 'package:ashita_motsumono/src/app_state.dart';
import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/repositories/drift_store.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService() : super(timezoneName: 'Asia/Tokyo');

  final List<String> scheduledTodoIds = [];
  final List<String> canceledTodoIds = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async => true;

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

  Future<AppState> createState() async {
    final store = await DriftStore.createInMemory();
    final state = AppState(
      store: store,
      notifications: _FakeNotificationService(),
    );
    await state.load();
    return state;
  }

  test('document changes notify DocumentState and relay to AppState', () async {
    final state = await createState();
    var appNotifications = 0;
    var childNotifications = 0;
    var todoNotifications = 0;
    var documentNotifications = 0;
    state.addListener(() => appNotifications++);
    state.childState.addListener(() => childNotifications++);
    state.todoState.addListener(() => todoNotifications++);
    state.documentState.addListener(() => documentNotifications++);

    await state.addDocument(sourceType: 'paste', ocrText: 'OCR');

    expect(documentNotifications, 1);
    expect(todoNotifications, 0);
    expect(childNotifications, 0);
    expect(appNotifications, 1);
  });

  test('todo changes notify TodoState and relay to AppState', () async {
    final state = await createState();
    var appNotifications = 0;
    var childNotifications = 0;
    var todoNotifications = 0;
    var documentNotifications = 0;
    state.addListener(() => appNotifications++);
    state.childState.addListener(() => childNotifications++);
    state.todoState.addListener(() => todoNotifications++);
    state.documentState.addListener(() => documentNotifications++);

    await state.addTodoFromDraft(
      draft: ExtractionDraft(
        title: '水筒',
        category: TodoCategory.item,
        dueDate: DateTime.now().add(const Duration(days: 2)),
        items: const ['水筒'],
      ),
    );

    expect(todoNotifications, 1);
    expect(documentNotifications, 0);
    expect(childNotifications, 0);
    expect(appNotifications, 1);
  });

  test(
    'child changes notify ChildState and the compatibility AppState listener',
    () async {
      final state = await createState();
      var appNotifications = 0;
      var childNotifications = 0;
      var todoNotifications = 0;
      var documentNotifications = 0;
      state.addListener(() => appNotifications++);
      state.childState.addListener(() => childNotifications++);
      state.todoState.addListener(() => todoNotifications++);
      state.documentState.addListener(() => documentNotifications++);

      await state.addChild('長女');

      expect(childNotifications, 1);
      expect(appNotifications, 1);
      expect(todoNotifications, 0);
      expect(documentNotifications, 0);
    },
  );
}
