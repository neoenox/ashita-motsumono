part of 'app_state.dart';

extension TodoAppStateOperations on AppState {
  Future<AppTodo> addTodoFromDraft({
    required ExtractionDraft draft,
    String? personId,
    String? documentId,
    bool notifyPreviousNight = true,
    bool notifySameMorning = true,
  }) async {
    final todo = _todoFactory.fromDraft(
      draft: draft,
      personId: personId,
      documentId: documentId,
      notifyPreviousNight: notifyPreviousNight,
      notifySameMorning: notifySameMorning,
    );
    _replaceTodos([...todos, todo]);
    await _persist();
    await _notificationCoordinator.schedule(todo);
    return todo;
  }

  Future<void> updateTodo(AppTodo todo) async {
    await _updateTodo(todo.copyWith(updatedAt: DateTime.now()));
  }

  Future<void> _updateTodo(
    AppTodo updated, {
    bool rescheduleNotification = true,
  }) async {
    _replaceTodos(
      todos.map(
        (existing) => existing.id == updated.id ? updated : existing,
      ),
    );
    await _persist();
    if (rescheduleNotification) {
      await _notificationCoordinator.schedule(updated);
    }
  }

  Future<void> toggleTodoDone(String id) async {
    final todo = todos.where((existing) => existing.id == id).firstOrNull;
    if (todo == null) return;
    final updated = todo.copyWith(
      status: todo.status == TodoStatus.done
          ? TodoStatus.active
          : TodoStatus.done,
      updatedAt: DateTime.now(),
    );
    _replaceTodos(
      todos.map((existing) => existing.id == id ? updated : existing),
    );
    await _persist();
    if (updated.isDone) {
      await _notificationCoordinator.cancel(updated.id);
    } else {
      await _notificationCoordinator.schedule(updated);
    }
  }

  Future<void> toggleItem(String todoId, String itemId) async {
    final todo = todos.where((existing) => existing.id == todoId).firstOrNull;
    if (todo == null) return;
    final items = todo.items
        .map(
          (item) => item.id == itemId
              ? item.copyWith(isChecked: !item.isChecked)
              : item,
        )
        .toList();
    await _updateTodo(
      todo.copyWith(items: items, updatedAt: DateTime.now()),
      rescheduleNotification: false,
    );
  }

  Future<void> deleteTodo(String id) async {
    _replaceTodos(todos.where((todo) => todo.id != id));
    final orphanDocuments = _cleanupOrphanDocuments();
    await _persist();
    await _notificationCoordinator.cancel(id);
    await _documentImageCleaner.deleteAll(orphanDocuments);
  }

  Future<List<AppTodo>> addTodosFromDrafts({
    required List<ExtractionDraft> drafts,
    String? personId,
    String? documentId,
    bool notifyPreviousNight = true,
    bool notifySameMorning = true,
  }) async {
    final newTodos = _todoFactory.fromDrafts(
      drafts: drafts,
      personId: personId,
      documentId: documentId,
      notifyPreviousNight: notifyPreviousNight,
      notifySameMorning: notifySameMorning,
    );
    _replaceTodos([...todos, ...newTodos]);
    await _persist();
    await _notificationCoordinator.rescheduleAll(newTodos);
    return newTodos;
  }

  Future<void> rescheduleAllNotifications() {
    return _notificationCoordinator.rescheduleAll(todos);
  }
}
