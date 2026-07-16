from __future__ import annotations

from pathlib import Path


def replace_once(text: str, old: str, new: str, *, label: str) -> str:
    if new in text:
        return text
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one match, found {count}')
    return text.replace(old, new)


def replace_function(
    text: str,
    *,
    start_marker: str,
    end_marker: str,
    replacement: str,
    already_applied_marker: str,
    label: str,
) -> str:
    if already_applied_marker in text:
        return text
    start = text.find(start_marker)
    if start < 0:
        raise RuntimeError(f'{label}: start marker not found')
    end = text.find(end_marker, start)
    if end < 0:
        raise RuntimeError(f'{label}: end marker not found')
    return text[:start] + replacement + text[end:]


def update_widget_tests() -> None:
    path = Path('test/widget_test.dart')
    text = path.read_text(encoding='utf-8')
    text = replace_once(
        text,
        "import 'dart:io' show Platform;",
        "import 'dart:io' show Directory, Platform;",
        label='widget test dart io import',
    )
    text = replace_once(
        text,
        "import 'package:ashita_motsumono/src/services/purchase_provider.dart';",
        "import 'package:ashita_motsumono/src/services/purchase_provider.dart';\nimport 'package:ashita_motsumono/src/services/sensitive_data_cleaner.dart';",
        label='widget test sensitive cleaner import',
    )

    helper = """Future<AppState> _createAppState() async {
  SharedPreferences.setMockInitialValues({'notification_info_shown_v1': true});
  final tempDir = await Directory.systemTemp.createTemp('ashita_widget_test_');
  addTearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });
  final store = await DriftStore.createInMemory();
  final appState = AppState(
    store: store,
    notifications: _FakeNotificationService(),
    sensitiveDataCleaner: SensitiveDataCleaner(
      directoryProvider: () async => tempDir,
    ),
  );
  await appState.load();
  return appState;
}

"""
    text = replace_function(
        text,
        start_marker='Future<AppState> _createAppState() async {',
        end_marker='void main() {',
        replacement=helper,
        already_applied_marker='ashita_widget_test_',
        label='widget test app state platform isolation',
    )

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
    text = replace_once(
        text,
        """      await tester.tap(find.text('削除する'));
      await tester.pumpAndSettle();

      expect(appState.children, isEmpty);""",
        """      await tester.tap(find.text('削除する'));
      for (var attempt = 0;
          attempt < 20 &&
              find.text('登録データを削除しました').evaluate().isEmpty;
          attempt++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      expect(appState.children, isEmpty);""",
        label='clear-all completion wait',
    )

    diagnostic = """      final snackbarTexts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data)
          .toList();
      debugPrint(
        'clear-all snackbars=$snackbarTexts '
        'labels=${settings.learnedItemLabels}',
      );

      expect(find.text('登録データを削除しました'), findsOneWidget);
      expect(appState.children, isEmpty);
      expect(appState.todos, isEmpty);
      expect(appState.documents, isEmpty);
      expect(settings.learnedItemLabels, isEmpty);"""
    clean_assertions = """      expect(find.text('登録データを削除しました'), findsOneWidget);
      expect(appState.children, isEmpty);
      expect(appState.todos, isEmpty);
      expect(appState.documents, isEmpty);
      expect(settings.learnedItemLabels, isEmpty);"""
    if diagnostic in text:
        text = text.replace(diagnostic, clean_assertions)

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
