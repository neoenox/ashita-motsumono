// lib/src/services/notification_coordinator.dart
// 通知プラグインの失敗を状態更新から隔離し、安全な予約・取消を提供する。

import 'package:flutter/foundation.dart';

import '../models/entities.dart';
import 'notification_service.dart';

class NotificationCoordinator {
  const NotificationCoordinator(this._notifications);

  final NotificationService _notifications;

  Future<void> requestPermissions() => _notifications.requestPermissions();

  Future<void> schedule(AppTodo todo) async {
    try {
      await _notifications.scheduleTodo(todo);
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('NotificationCoordinator: schedule failed: $error\n$stackTrace');
      }
    }
  }

  Future<void> cancel(String todoId) async {
    try {
      await _notifications.cancelTodo(todoId);
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('NotificationCoordinator: cancel failed: $error\n$stackTrace');
      }
    }
  }

  Future<void> rescheduleAll(Iterable<AppTodo> todos) async {
    for (final todo in todos) {
      await schedule(todo);
    }
  }

  Future<void> cancelAll(Iterable<AppTodo> todos) async {
    for (final todo in todos) {
      await cancel(todo.id);
    }
  }
}
