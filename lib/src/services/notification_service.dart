// lib/src/services/notification_service.dart
// flutter_local_notifications を使ったローカル通知のスケジュール・キャンセル。
// 前日20:00 と 当日7:00 に Todo 内容を通知する。
// 端末のタイムゾーンを自動検出（flutter_timezone）、フォールバックは Asia/Tokyo。
// 関連: models/entities.dart, app_state.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/entities.dart';
import 'app_settings.dart';

@immutable
class NotificationScheduleRequest {
  const NotificationScheduleRequest({
    required this.id,
    required this.scheduledDate,
    required this.title,
    required this.body,
  });

  final int id;
  final DateTime scheduledDate;
  final String title;
  final String body;
}

class NotificationService {
  /// [timezoneName] を指定すると flutter_timezone による自動検出をスキップする（テスト用）。
  NotificationService({this.settings, String? timezoneName})
    : _timezoneName = timezoneName;

  final AppSettings? settings;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final String? _timezoneName;
  bool _initialized = false;
  Future<void>? _initFuture;

  Future<void> initialize() {
    if (_initialized) return Future.value();
    if (_initFuture != null) return _initFuture!;
    return _initFuture = _doInitialize();
  }

  Future<void> _doInitialize() async {
    tzdata.initializeTimeZones();
    try {
      final id =
          _timezoneName ?? (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(id));
    } on Object {
      if (kDebugMode) {
        debugPrint(
          'NotificationService: failed to detect timezone, falling back to Asia/Tokyo',
        );
      }
      tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    try {
      await _plugin.initialize(settings: settings);
      _initialized = true;
      _initFuture = null;
    } on Object {
      _initFuture = null;
      rethrow;
    }
  }

  Future<void> requestPermissions() async {
    await initialize();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleTodo(AppTodo todo) async {
    await initialize();

    // 同じTodoの既存2通知を必ず先に削除してから、必要な未来通知だけを再登録する。
    await cancelTodo(todo.id);
    for (final request in buildScheduleRequests(todo)) {
      await _scheduleIfFuture(
        request.id,
        request.scheduledDate,
        request.title,
        request.body,
      );
    }
  }

  @visibleForTesting
  List<NotificationScheduleRequest> buildScheduleRequests(
    AppTodo todo, {
    DateTime? now,
  }) {
    final due = todo.dueDate;
    if (due == null || todo.isDone) return const [];

    final referenceTime = now ?? DateTime.now();
    final requests = <NotificationScheduleRequest>[];

    if (todo.notifyPreviousNight) {
      final h =
          settings?.previousNightHour ?? AppSettings.defaultPreviousNightHour;
      final m = settings?.previousNightMinute ??
          AppSettings.defaultPreviousNightMinute;
      final when = DateTime(
        due.year,
        due.month,
        due.day,
        h,
        m,
      ).subtract(const Duration(days: 1));
      if (when.isAfter(referenceTime)) {
        requests.add(
          NotificationScheduleRequest(
            id: _notificationId(todo.id, 1),
            scheduledDate: when,
            title: '明日の支度',
            body: _buildBody(todo),
          ),
        );
      }
    }

    if (todo.notifySameMorning) {
      final h = settings?.sameMorningHour ?? AppSettings.defaultSameMorningHour;
      final m =
          settings?.sameMorningMinute ?? AppSettings.defaultSameMorningMinute;
      final when = DateTime(due.year, due.month, due.day, h, m);
      if (when.isAfter(referenceTime)) {
        requests.add(
          NotificationScheduleRequest(
            id: _notificationId(todo.id, 2),
            scheduledDate: when,
            title: '今日の支度・提出',
            body: _buildBody(todo),
          ),
        );
      }
    }

    return requests;
  }

  Future<void> cancelTodo(String todoId) async {
    await initialize();
    await _plugin.cancel(id: _notificationId(todoId, 1));
    await _plugin.cancel(id: _notificationId(todoId, 2));
  }

  Future<void> _scheduleIfFuture(
    int id,
    DateTime when,
    String title,
    String body,
  ) async {
    if (!when.isAfter(DateTime.now())) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'preparation_reminders',
        '支度・提出リマインド',
        channelDescription: '明日・今日の持ち物、提出物、集金を通知します。',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        threadIdentifier: 'preparation_reminders',
      ),
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

  int _notificationId(String id, int salt) =>
      (id.codeUnits.fold<int>(0, (h, c) => h * 31 + c) ^ salt) & 0x7FFFFFFF;
}
