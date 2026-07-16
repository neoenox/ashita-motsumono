from __future__ import annotations

from pathlib import Path


def replace_once(text: str, old: str, new: str, *, label: str) -> str:
    if new in text:
        return text
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one match, found {count}')
    return text.replace(old, new)


def update_widget_tests() -> None:
    path = Path('test/widget_test.dart')
    text = path.read_text(encoding='utf-8')
    text = replace_once(
        text,
        "expect(find.text('買い切り ¥190'), findsOneWidget);",
        "expect(find.text('買い切り ¥190'), findsNWidgets(2));",
        label='purchase price expectation',
    )
    text = replace_once(
        text,
        "expect(find.text('購入アイテムを準備中です。しばらくしてからもう一度お試しください。'), findsOneWidget);",
        "expect(find.text('購入アイテムを準備中です。しばらくしてからもう一度お試しください。'), findsNWidgets(2));",
        label='purchase status expectation',
    )
    path.write_text(text, encoding='utf-8')


def update_screenshot_tests() -> None:
    path = Path('tool/generate_lp_screenshots_test.dart')
    text = path.read_text(encoding='utf-8')

    marker = 'Future<AppSettings> _createSettings() async {'
    fake_service = """class _ScreenshotNotificationService extends NotificationService {
  _ScreenshotNotificationService() : super(timezoneName: 'Asia/Tokyo');

  @override
  Future<void> initialize() async {}

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> scheduleTodo(AppTodo todo) async {}

  @override
  Future<void> cancelTodo(String todoId) async {}
}

"""
    if fake_service not in text:
        if text.count(marker) != 1:
            raise RuntimeError('screenshot settings marker was not unique')
        text = text.replace(marker, fake_service + marker)

    text = replace_once(
        text,
        "notifications: NotificationService(timezoneName: 'Asia/Tokyo'),",
        'notifications: _ScreenshotNotificationService(),',
        label='screenshot notification service',
    )

    old_setup = """  setUp(() {
    // このファイルはtool配下だが、CIではflutter testから実行するテスト専用コード。
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'notification_info_shown_v1': true,
    });
  });"""
    new_setup = """  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const messagesChannel = MethodChannel(
      'receive_sharing_intent/messages',
    );
    const eventsChannel = MethodChannel(
      'receive_sharing_intent/events-media',
    );
    messenger.setMockMethodCallHandler(
      messagesChannel,
      (call) async => <dynamic>[],
    );
    messenger.setMockMethodCallHandler(
      eventsChannel,
      (call) async => null,
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(messagesChannel, null);
      messenger.setMockMethodCallHandler(eventsChannel, null);
    });

    // このファイルはtool配下だが、CIではflutter testから実行するテスト専用コード。
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'notification_info_shown_v1': true,
    });
  });"""
    text = replace_once(
        text,
        old_setup,
        new_setup,
        label='screenshot platform channel setup',
    )
    path.write_text(text, encoding='utf-8')


def main() -> None:
    update_widget_tests()
    update_screenshot_tests()


if __name__ == '__main__':
    main()
