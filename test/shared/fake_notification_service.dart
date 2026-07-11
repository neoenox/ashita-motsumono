// test/shared/fake_notification_service.dart
// NotificationService のフェイク実装。
// テストで実際の通知を送らないようにする。
// 関連: lib/src/services/notification_service.dart

import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/services/app_settings.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';

/// テスト用のフェイク通知サービス。
class FakeNotificationService implements NotificationService {
  @override
  final AppSettings? settings;

  FakeNotificationService({this.settings});

  final List<({AppTodo todo, DateTime date})> scheduledTodos = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> scheduleTodo(AppTodo todo) async {}

  @override
  Future<void> cancelTodo(String todoId) async {}
}
