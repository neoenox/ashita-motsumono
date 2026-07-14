// lib/src/services/notification_service.dart
// flutter_local_notifications を使ったローカル通知のスケジュール・キャンセル。
// 前日夜と当日朝に Todo 内容を通知する。
// 端末のタイムゾーンを自動検出（flutter_timezone）、フォールバックは Asia/Tokyo。
// 関連: models/entities.dart, app_state.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/entities.dart';
import 'app_settings.dart';
import 'notification_id_repository.dart';

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
  NotificationService({
    this.settings,
    this.notificationIds,
    String? timezoneName,
  }) : _timezoneName = timezoneName;

  final AppSettings? settings;
  final NotificationIdRepository? notificationIds;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
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
          _timezoneName ??
          (await FlutterTimezone.getLocalTimezone()).identifier;
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
    final ids = notificationIds == null
        ? _fallbackNotificationIds(todo.id)
        : await notificationIds!.getOrCreateNotificationIds(todo.id);

    // 同じTodoの既存2通知を必ず先に削除してから、必要な未来通知だけを再登録する。
    await _cancelIds(ids);
    for (final request in buildScheduleRequests(
      todo,
      notificationIdPair: ids,
    )) {
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
    NotificationIdPair? notificationIdPair,
  }) {
    final due = todo.dueDate?.toLocal();
    if (due == null || todo.isDone) return const [];

    final ids = notificationIdPair ?? _fallbackNotificationIds(todo.id);
    final referenceTime = now ?? DateTime.now();
    final requests = <NotificationScheduleRequest>[];

    if (todo.notifyPreviousNight) {
      final h =
          settings?.previousNightHour ?? AppSettings.defaultPreviousNightHour;
      final m =
          settings?.previousNightMinute ??
          AppSettings.defaultPreviousNightMinute;
      // ここでは「端末の壁時計時刻」を表す。実際のTZ変換は登録直前に行う。
      final when = DateTime(due.year, due.month, due.day - 1, h, m);
      if (when.isAfter(referenceTime)) {
        requests.add(
          NotificationScheduleRequest(
            id: ids.previousNight,
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
            id: ids.sameMorning,
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
    final ids = notificationIds == null
        ? _fallbackNotificationIds(todoId)
        : await notificationIds!.findNotificationIds(todoId);
    if (ids == null) return;
    await _cancelIds(ids);
  }

  Future<void> _cancelIds(NotificationIdPair ids) async {
    await _plugin.cancel(id: ids.previousNight);
    await _plugin.cancel(id: ids.sameMorning);
  }

  Future<void> _scheduleIfFuture(
    int id,
    DateTime when,
    String title,
    String body,
  ) async {
    // TZDateTime.from は同じ「瞬間」へ変換するため、壁時計の時刻がずれる場合がある。
    // 年月日時分から端末TZ上の予定時刻を構築し、設定した時刻を維持する。
    final scheduled = tz.TZDateTime(
      tz.local,
      when.year,
      when.month,
      when.day,
      when.hour,
      when.minute,
      when.second,
      when.millisecond,
      when.microsecond,
    );
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) return;
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
      scheduledDate: scheduled,
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

  NotificationIdPair _fallbackNotificationIds(String todoId) =>
      NotificationIdPair(
        previousNight: _legacyNotificationId(todoId, 1),
        sameMorning: _legacyNotificationId(todoId, 2),
      );

  int _legacyNotificationId(String id, int salt) {
    final value =
        (id.codeUnits.fold<int>(0, (hash, code) => hash * 31 + code) ^ salt) &
        0x7FFFFFFF;
    return value == 0 ? salt : value;
  }
}
