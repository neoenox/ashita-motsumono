// test/app_state_test.dart
// AppState の状態遷移と通知再予約の回帰テスト。
// 関連: lib/src/app_state.dart, lib/src/services/notification_service.dart

import 'package:ashita_motsumono/src/app_state.dart';
import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/repositories/drift_store.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

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
      final store = await DriftStore.createInMemory();
      final notifications = _FakeNotificationService();
      final appState = AppState(store: store, notifications: notifications);
      await appState.load();

      final tempDir = await Directory.systemTemp.createTemp(
        'ashita_clear_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
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

      await appState.clearAllData();

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

  group('preparation mode', () {
    late DriftStore store;
    late _FakeNotificationService notifications;
    late AppState appState;
    late PersonProfile childA;
    late PersonProfile childB;

    setUp(() async {
      store = await DriftStore.createInMemory();
      notifications = _FakeNotificationService();
      appState = AppState(store: store, notifications: notifications);
      await appState.load();

      childA = await appState.addChild('太郎');
      childB = await appState.addChild('次郎');

      // 今日期限
      final today = DateTime.now();
      await appState.addTodosFromDrafts(
        drafts: [
          ExtractionDraft(
            title: '水筒',
            category: TodoCategory.item,
            dueDate: today,
            items: [],
          ),
          ExtractionDraft(
            title: '連絡帳',
            category: TodoCategory.submit,
            dueDate: today,
            items: [],
          ),
        ],
        personId: childA.id,
      );
      // 昨日期限（childB）
      await appState.addTodosFromDrafts(
        drafts: [
          ExtractionDraft(
            title: '集金',
            category: TodoCategory.payment,
            dueDate: today.subtract(const Duration(days: 1)),
            items: [],
          ),
        ],
        personId: childB.id,
      );
    });

    test('todosForPreparation includes active todos with past or today dueDate',
        () async {
      final todos = appState.todosForPreparation(DateTime.now());
      expect(todos.length, 3);
    });

    test('todosForPreparation excludes done todos', () async {
      final todos = appState.todosForPreparation(DateTime.now());
      await appState.toggleTodoDone(todos.first.id);
      final after = appState.todosForPreparation(DateTime.now());
      expect(after.length, 2);
    });

    test('todosForPreparation excludes undated todos', () async {
      await appState.addTodosFromDrafts(
        drafts: [
          ExtractionDraft(
            title: '期限なし',
            category: TodoCategory.other,
            items: [],
          ),
        ],
      );
      final todos = appState.todosForPreparation(DateTime.now());
      // 3 (既存) + 0 (undatedは除外)
      expect(todos.length, 3);
    });

    test('todosForPreparation excludes future dueDate', () async {
      final todos = appState.todosForPreparation(DateTime.now());
      for (final t in todos) {
        expect(t.dueDate!.isAfter(DateTime.now()), isFalse);
      }
    });

    test('todosForPreparation excludes already prepared todos', () async {
      final todos = appState.todosForPreparation(DateTime.now());
      final first = todos.first;
      await appState.markTodoPrepared(first.id, DateTime.now());
      final after = appState.todosForPreparation(DateTime.now());
      expect(after.length, 2);
      expect(after.every((t) => t.id != first.id), isTrue);
    });

    test('todosForPreparation sorts by child order, personId null last',
        () async {
      // 3つ目をpersonId nullで追加
      final today = DateTime.now();
      await appState.addTodosFromDrafts(
        drafts: [
          ExtractionDraft(
            title: '未割当',
            category: TodoCategory.other,
            dueDate: today,
            items: [],
          ),
        ],
      );

      // 子ども順は 太郎 (childA) → 次郎 (childB) → null
      final todos = appState.todosForPreparation(today);
      final persons = todos.map((t) => t.personId).toList();
      final aIdx = persons.indexOf(childA.id);
      final bIdx = persons.indexOf(childB.id);
      final nullIdx = persons.indexOf(null);
      expect(aIdx, lessThan(bIdx));
      expect(bIdx, lessThan(nullIdx));
    });

    test('markTodoPrepared does not change status', () async {
      final todos = appState.todosForPreparation(DateTime.now());
      final first = todos.first;
      expect(first.status, TodoStatus.active);
      await appState.markTodoPrepared(first.id, DateTime.now());
      final after = appState.todosForPreparation(DateTime.now());
      // 対象外になったので直接todosから取得
      final todo = appState.todos.firstWhere((t) => t.id == first.id);
      expect(todo.status, TodoStatus.active);
    });

    test('markTodoPrepared does not cancel notification', () async {
      final todos = appState.todosForPreparation(DateTime.now());
      final first = todos.first;
      final beforeCancelCount = notifications.canceledTodoIds.length;
      await appState.markTodoPrepared(first.id, DateTime.now());
      expect(notifications.canceledTodoIds.length, beforeCancelCount);
    });

    test('clearTodoPrepared makes todo eligible again', () async {
      final todos = appState.todosForPreparation(DateTime.now());
      final first = todos.first;
      await appState.markTodoPrepared(first.id, DateTime.now());
      var after = appState.todosForPreparation(DateTime.now());
      expect(after.every((t) => t.id != first.id), isTrue);

      await appState.clearTodoPrepared(first.id);
      after = appState.todosForPreparation(DateTime.now());
      expect(after.any((t) => t.id == first.id), isTrue);
    });

    test('todosPreparedToday returns only today-prepared todos', () async {
      final todos = appState.todosForPreparation(DateTime.now());
      final today = DateTime.now();
      await appState.markTodoPrepared(todos[0].id, today);
      final prepared = appState.todosPreparedToday(today);
      expect(prepared.length, 1);
      expect(prepared.first.id, todos[0].id);
    });

    test('prepChildNames returns names in child registration order', () async {
      final names = appState.prepChildNames(DateTime.now());
      // 太郎(childA) + 次郎(childB)
      expect(names.length, 2);
      expect(names[0], '太郎');
      expect(names[1], '次郎');
    });
  });
}
