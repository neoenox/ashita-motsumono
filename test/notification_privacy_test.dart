import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/services/app_settings.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  AppTodo todo() => AppTodo(
        id: 'todo-1',
        title: '集金袋を提出',
        category: TodoCategory.payment,
        status: TodoStatus.active,
        items: const [
          ChecklistItem(id: 'item-1', label: '集金袋'),
        ],
        amount: 500,
        dueDate: DateTime(2026, 7, 20),
        createdAt: DateTime(2026, 7, 16),
        updatedAt: DateTime(2026, 7, 16),
      );

  test('notification details are hidden by default', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    final service = NotificationService(
      settings: settings,
      timezoneName: 'Asia/Tokyo',
    );

    final requests = service.buildScheduleRequests(
      todo(),
      now: DateTime(2026, 7, 18),
    );

    expect(requests, isNotEmpty);
    expect(
      requests.every(
        (request) => request.body == 'アプリを開いて内容を確認してください。',
      ),
      isTrue,
    );
    expect(requests.any((request) => request.body.contains('500')), isFalse);
    expect(requests.any((request) => request.body.contains('集金袋')), isFalse);
  });

  test('user can explicitly enable detailed notification previews', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    await settings.setShowNotificationDetails(true);
    final service = NotificationService(
      settings: settings,
      timezoneName: 'Asia/Tokyo',
    );

    final requests = service.buildScheduleRequests(
      todo(),
      now: DateTime(2026, 7, 18),
    );

    expect(requests.any((request) => request.body.contains('集金袋')), isTrue);
    expect(requests.any((request) => request.body.contains('500円')), isTrue);
  });
}
