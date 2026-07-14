// integration_test/issue60_notification_test.dart
// Issue #60 通知実測テスト。3ケース（通常・再起動・再インストール）を実行する。
// Dart内ではaddTodoFromDraft()を呼ぶだけ。ADB dumpsysはホスト側スクリプトが集約する。
// 関連: app_state.dart, drift_store.dart, notification_service.dart, app_settings.dart

import 'package:ashita_motsumono/src/app_state.dart';
import 'package:ashita_motsumono/src/models/enums.dart';
import 'package:ashita_motsumono/src/models/extraction_draft.dart';
import 'package:ashita_motsumono/src/repositories/drift_store.dart';
import 'package:ashita_motsumono/src/services/app_settings.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _launchTestApp(WidgetTester tester) async {
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs);

  // 通知時刻を「今」に設定して即発火させる。
  final now = DateTime.now();
  await settings.setSameMorningTime(now.hour, now.minute);
  await settings.setPreviousNightTime(now.hour, now.minute);

  final store = await DriftStore.create();
  final notifications = NotificationService(
    settings: settings,
    notificationIds: store,
    timezoneName: 'Asia/Tokyo',
  );

  final appState = AppState(store: store, notifications: notifications);
  await appState.load();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
      ],
      child: const MaterialApp(
        home: Scaffold(body: Center(child: Text('Test Host'))),
      ),
    ),
  );
  await tester.pump();
  return appState;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Case1 Normal - Todo追加時に通知がスケジュールされる', (tester) async {
    final state = await _launchTestApp(tester);

    final draft = ExtractionDraft(
      title: 'テスト持ち物Normal',
      category: TodoCategory.item,
      items: ['ノート', '鉛筆'],
      dueDate: DateTime.now().add(const Duration(days: 1)),
    );

    final todo = await state.addTodoFromDraft(
      draft: draft,
      notifyPreviousNight: true,
      notifySameMorning: true,
    );

    await tester.pump(const Duration(seconds: 3));

    // ホスト側でADB dumpsysを確認する前に、Dart側では追加成功のみ確認。
    expect(todo.id, isNotEmpty);
    expect(state.todos.length, greaterThanOrEqualTo(1));
    expect(state.todos.any((t) => t.title == 'テスト持ち物Normal'), isTrue);

    // printでホスト側に合図を出す。
    print('CASE1_DONE');

    await state.deleteTodo(todo.id);
  });

  testWidgets('Case2 Reboot - Todo追加に成功し再起動前通知がスケジュールされる', (tester) async {
    final state = await _launchTestApp(tester);

    final draft = ExtractionDraft(
      title: 'テスト再起動',
      category: TodoCategory.submit,
      items: ['プリント'],
      dueDate: DateTime.now().add(const Duration(days: 1)),
    );

    final todo = await state.addTodoFromDraft(
      draft: draft,
      notifyPreviousNight: true,
      notifySameMorning: true,
    );

    await tester.pump(const Duration(seconds: 3));

    expect(todo.id, isNotEmpty);
    expect(state.todos.any((t) => t.title == 'テスト再起動'), isTrue);

    print('CASE2_DONE');
    // 再起動はホスト側スクリプトが実行する。
  });

  testWidgets('Case3 Install-r - Todo追加に成功し再インストール前通知がスケジュールされる', (
    tester,
  ) async {
    final state = await _launchTestApp(tester);

    final draft = ExtractionDraft(
      title: 'テスト再インストール',
      category: TodoCategory.payment,
      items: ['500円'],
      dueDate: DateTime.now().add(const Duration(days: 1)),
    );

    final todo = await state.addTodoFromDraft(
      draft: draft,
      notifyPreviousNight: true,
      notifySameMorning: true,
    );

    await tester.pump(const Duration(seconds: 3));

    expect(todo.id, isNotEmpty);
    expect(state.todos.any((t) => t.title == 'テスト再インストール'), isTrue);

    print('CASE3_DONE');
  });
}
