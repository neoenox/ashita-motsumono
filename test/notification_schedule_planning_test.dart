// test/notification_schedule_planning_test.dart
// NotificationService が再予約時に必要な未来通知だけを構築することを検証する。

import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/services/app_settings.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  AppTodo todo({
    DateTime? dueDate,
    TodoStatus status = TodoStatus.active,
    bool notifyPreviousNight = true,
    bool notifySameMorning = true,
  }) {
    final createdAt = DateTime(2026, 7, 1, 12);
    return AppTodo(
      id: 'todo-1',
      title: '水筒を持参',
      dueDate: dueDate,
      category: TodoCategory.item,
      amount: 500,
      status: status,
      items: const [ChecklistItem(id: 'item-1', label: '水筒')],
      notifyPreviousNight: notifyPreviousNight,
      notifySameMorning: notifySameMorning,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  test('builds private previous-night and same-morning requests', () {
    final service = NotificationService(timezoneName: 'Asia/Tokyo');

    final requests = service.buildScheduleRequests(
      todo(dueDate: DateTime(2026, 7, 13)),
      now: DateTime(2026, 7, 12, 17),
    );

    expect(requests, hasLength(2));
    expect(requests[0].scheduledDate, DateTime(2026, 7, 12, 20));
    expect(requests[0].title, '明日の支度');
    expect(requests[1].scheduledDate, DateTime(2026, 7, 13, 7));
    expect(requests[1].title, '今日の支度・提出');
    expect(
      requests.every((request) => request.body == 'アプリを開いて内容を確認してください。'),
      isTrue,
    );
    expect(requests[0].id, isNot(requests[1].id));
  });

  test('does not build requests for done or undated todos', () {
    final service = NotificationService(timezoneName: 'Asia/Tokyo');
    final now = DateTime(2026, 7, 12, 17);

    expect(
      service.buildScheduleRequests(
        todo(dueDate: DateTime(2026, 7, 13), status: TodoStatus.done),
        now: now,
      ),
      isEmpty,
    );
    expect(service.buildScheduleRequests(todo(), now: now), isEmpty);
  });

  test('respects each notification opt-out flag', () {
    final service = NotificationService(timezoneName: 'Asia/Tokyo');
    final now = DateTime(2026, 7, 12, 17);
    final due = DateTime(2026, 7, 13);

    final morningOnly = service.buildScheduleRequests(
      todo(dueDate: due, notifyPreviousNight: false),
      now: now,
    );
    expect(morningOnly, hasLength(1));
    expect(morningOnly.single.title, '今日の支度・提出');

    final previousNightOnly = service.buildScheduleRequests(
      todo(dueDate: due, notifySameMorning: false),
      now: now,
    );
    expect(previousNightOnly, hasLength(1));
    expect(previousNightOnly.single.title, '明日の支度');

    expect(
      service.buildScheduleRequests(
        todo(
          dueDate: due,
          notifyPreviousNight: false,
          notifySameMorning: false,
        ),
        now: now,
      ),
      isEmpty,
    );
  });

  test('skips notification times that have already passed', () {
    final service = NotificationService(timezoneName: 'Asia/Tokyo');
    final due = DateTime(2026, 7, 13);

    final afterPreviousNight = service.buildScheduleRequests(
      todo(dueDate: due),
      now: DateTime(2026, 7, 12, 20, 1),
    );
    expect(afterPreviousNight, hasLength(1));
    expect(afterPreviousNight.single.title, '今日の支度・提出');

    expect(
      service.buildScheduleRequests(
        todo(dueDate: due),
        now: DateTime(2026, 7, 13, 7, 1),
      ),
      isEmpty,
    );
  });

  test('uses configured notification times', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(prefs);
    await settings.setPreviousNightTime(19, 30);
    await settings.setSameMorningTime(6, 45);
    final service = NotificationService(
      settings: settings,
      timezoneName: 'Asia/Tokyo',
    );

    final requests = service.buildScheduleRequests(
      todo(dueDate: DateTime(2026, 7, 13)),
      now: DateTime(2026, 7, 12, 17),
    );

    expect(requests.map((request) => request.scheduledDate), [
      DateTime(2026, 7, 12, 19, 30),
      DateTime(2026, 7, 13, 6, 45),
    ]);
  });
}
