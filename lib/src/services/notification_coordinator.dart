// lib/src/services/notification_coordinator.dart
// 通知プラグインの失敗を状態更新から隔離し、永続キュー付きの予約・取消を提供する。

import 'package:flutter/foundation.dart';

import '../models/entities.dart';
import '../repositories/store.dart';
import 'notification_service.dart';

class NotificationCoordinator {
  const NotificationCoordinator(this._notifications, this._store);

  final NotificationService _notifications;
  final Store _store;

  Future<void> requestPermissions() => _notifications.requestPermissions();

  Future<void> schedule(AppTodo todo) async {
    await _store.queueNotificationSync(
      todo.id,
      NotificationSyncOperation.schedule,
    );
    await executeScheduledTodo(todo);
  }

  Future<void> cancel(String todoId) async {
    await _store.queueNotificationSync(
      todoId,
      NotificationSyncOperation.cancel,
    );
    await executeCanceledTodo(todoId);
  }

  /// AppStateがスナップショットと同一トランザクションでキュー登録済みの場合に使う。
  Future<void> executeScheduledTodo(AppTodo todo) async {
    try {
      await _notifications.scheduleTodo(todo);
      await _store.completeNotificationSync(todo.id);
    } on Object catch (error, stackTrace) {
      await _recordFailure(
        todo.id,
        NotificationSyncOperation.schedule,
        error,
        stackTrace,
      );
    }
  }

  /// AppStateがスナップショットと同一トランザクションでキュー登録済みの場合に使う。
  Future<void> executeCanceledTodo(String todoId) async {
    try {
      await _notifications.cancelTodo(todoId);
      await _store.completeNotificationSync(todoId, releaseIds: true);
    } on Object catch (error, stackTrace) {
      await _recordFailure(
        todoId,
        NotificationSyncOperation.cancel,
        error,
        stackTrace,
      );
    }
  }

  Future<void> _recordFailure(
    String todoId,
    NotificationSyncOperation operation,
    Object error,
    StackTrace stackTrace,
  ) async {
    try {
      await _store.queueNotificationSync(
        todoId,
        operation,
        lastError: error.toString(),
      );
    } on Object catch (queueError, queueStackTrace) {
      if (kDebugMode) {
        debugPrint(
          'NotificationCoordinator: failed to persist retry state: '
          '$queueError\n$queueStackTrace',
        );
      }
    }
    if (kDebugMode) {
      debugPrint(
        'NotificationCoordinator: ${operation.name} failed: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<void> retryPending(Iterable<AppTodo> todos) async {
    final todosById = {for (final todo in todos) todo.id: todo};
    final pending = await _store.loadPendingNotificationSync();
    for (final task in pending) {
      switch (task.operation) {
        case NotificationSyncOperation.schedule:
          final todo = todosById[task.todoId];
          if (todo == null) {
            // Todoが既に消えている場合は、残存通知の取消へ収束させる。
            await executeCanceledTodo(task.todoId);
          } else {
            await executeScheduledTodo(todo);
          }
        case NotificationSyncOperation.cancel:
          await executeCanceledTodo(task.todoId);
      }
    }
  }

  Future<void> rescheduleAll(Iterable<AppTodo> todos) async {
    await Future.wait(todos.map(schedule));
  }

  Future<void> cancelAll(Iterable<AppTodo> todos) async {
    await Future.wait(todos.map((todo) => cancel(todo.id)));
  }
}
