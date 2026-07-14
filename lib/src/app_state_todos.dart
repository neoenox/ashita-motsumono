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
    final nextTodos = [...todos, todo];
    await _persistSnapshot(
      nextTodos: nextTodos,
      notificationOperations: {
        todo.id: NotificationSyncOperation.schedule,
      },
    );
    _replaceTodos(nextTodos);
    await _notificationCoordinator.executeScheduledTodo(todo);
    return todo;
  }

  Future<void> updateTodo(AppTodo todo) async {
    await _updateTodo(todo.copyWith(updatedAt: DateTime.now()));
  }

  Future<void> _updateTodo(
    AppTodo updated, {
    bool rescheduleNotification = true,
  }) async {
    final nextTodos = todos
        .map(
          (existing) => existing.id == updated.id ? updated : existing,
        )
        .toList();
    final operation = updated.isDone
        ? NotificationSyncOperation.cancel
        : NotificationSyncOperation.schedule;
    await _persistSnapshot(
      nextTodos: nextTodos,
      notificationOperations: rescheduleNotification
          ? {updated.id: operation}
          : const {},
    );
    _replaceTodos(nextTodos);
    if (rescheduleNotification) {
      if (operation == NotificationSyncOperation.cancel) {
        await _notificationCoordinator.executeCanceledTodo(updated.id);
      } else {
        await _notificationCoordinator.executeScheduledTodo(updated);
      }
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
    final nextTodos = todos
        .map((existing) => existing.id == id ? updated : existing)
        .toList();
    final operation = updated.isDone
        ? NotificationSyncOperation.cancel
        : NotificationSyncOperation.schedule;
    await _persistSnapshot(
      nextTodos: nextTodos,
      notificationOperations: {updated.id: operation},
    );
    _replaceTodos(nextTodos);
    if (updated.isDone) {
      await _notificationCoordinator.executeCanceledTodo(updated.id);
    } else {
      await _notificationCoordinator.executeScheduledTodo(updated);
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
    final nextTodos = todos.where((todo) => todo.id != id).toList();
    if (nextTodos.length == todos.length) return;

    final orphanDocuments = _orphanDocumentsAfter(nextTodos);
    final nextDocuments = _documentsReferencedBy(nextTodos);
    final cleanupPaths = _documentImageCleaner
        .pathsFor(orphanDocuments)
        .toList();
    await _persistSnapshot(
      nextTodos: nextTodos,
      nextDocuments: nextDocuments,
      notificationOperations: {
        id: NotificationSyncOperation.cancel,
      },
      cleanupPaths: cleanupPaths,
    );
    _replaceTodos(nextTodos);
    _replaceDocuments(nextDocuments);
    await _notificationCoordinator.executeCanceledTodo(id);
    await _retryPendingFileCleanup();
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
    if (newTodos.isEmpty) return const [];

    final nextTodos = [...todos, ...newTodos];
    await _persistSnapshot(
      nextTodos: nextTodos,
      notificationOperations: {
        for (final todo in newTodos)
          todo.id: NotificationSyncOperation.schedule,
      },
    );
    _replaceTodos(nextTodos);
    await Future.wait(
      newTodos.map(_notificationCoordinator.executeScheduledTodo),
    );
    return newTodos;
  }

  Future<void> rescheduleAllNotifications() async {
    await retryPendingSideEffects();
    await _notificationCoordinator.rescheduleAll(todos);
  }
}
