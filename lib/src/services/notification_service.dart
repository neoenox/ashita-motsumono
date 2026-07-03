// lib/src/services/notification_service.dart
// flutter_local_notifications を使ったローカル通知のスケジュール・キャンセル。
// 前日20:00 と 当日7:00 に Todo 内容を通知する（JST固定、MVP限定）。
// 関連: models/entities.dart, app_state.dart

import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/entities.dart';

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<void> requestPermissions() async {
    await initialize();
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleTodo(AppTodo todo) async {
    await initialize();
    await cancelTodo(todo.id);
    final due = todo.dueDate;
    if (due == null || todo.isDone) return;

    if (todo.notifyPreviousNight) {
      final when = DateTime(due.year, due.month, due.day, 20).subtract(const Duration(days: 1));
      await _scheduleIfFuture(
        _notificationId(todo.id, 1),
        when,
        '明日の支度',
        _buildBody(todo),
      );
    }
    if (todo.notifySameMorning) {
      final when = DateTime(due.year, due.month, due.day, 7);
      await _scheduleIfFuture(
        _notificationId(todo.id, 2),
        when,
        '今日の支度・提出',
        _buildBody(todo),
      );
    }
  }

  Future<void> cancelTodo(String todoId) async {
    await initialize();
    await _plugin.cancel(id: _notificationId(todoId, 1));
    await _plugin.cancel(id: _notificationId(todoId, 2));
  }

  Future<void> _scheduleIfFuture(int id, DateTime when, String title, String body) async {
    if (!when.isAfter(DateTime.now())) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'preparation_reminders',
        '支度・提出リマインド',
        channelDescription: '明日・今日の持ち物、提出物、集金を通知します。',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(threadIdentifier: 'preparation_reminders'),
    );
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  String _buildBody(AppTodo todo) {
    final parts = <String>[];
    if (todo.items.isNotEmpty) {
      parts.add(todo.items.map((e) => e.label).join('・'));
    }
    if (todo.amount != null) {
      parts.add('集金 ${todo.amount}円');
    }
    if (parts.isEmpty) return todo.title;
    return '${todo.title}：${parts.join(' / ')}';
  }

  int _notificationId(String id, int salt) {
    var hash = salt;
    for (final codeUnit in id.codeUnits) {
      hash = 0x1fffffff & (hash + codeUnit);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= hash >> 6;
    }
    return max(1, hash.abs());
  }
}
