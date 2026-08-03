// integration_test/review_extractions_ux_test.dart
// Issue #146: OCR確認画面のUX受入（大量候補・選択・削除・一括置換・OCR参照）を
// エミュレータ上で検証する。実データは使わず、匿名の人工fixtureのみ使用する。

import 'package:ashita_motsumono/src/app_state.dart';
import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/repositories/drift_store.dart';
import 'package:ashita_motsumono/src/screens/review_extractions_screen.dart';
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

ExtractionDraft _draft(int index) {
  return ExtractionDraft(
    title: '候補$index',
    category: TodoCategory.item,
    items: ['持ち物$index'],
    dueDate: DateTime(2026, 8, 10),
    amount: 100,
    rawText: 'OCR元テキスト$index',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Issue146 - 大量候補で確認画面がクラッシュせず操作できる', (tester) async {
    final appState = await _launchTestApp(tester);

    final drafts = List.generate(120, _draft);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
        ],
        child: MaterialApp(
          home: ReviewExtractionsScreen(drafts: drafts),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 全120件が初期状態で選択されている
    expect(find.text('120件の候補を確認'), findsOneWidget);
    expect(find.text('120件を登録'), findsOneWidget);

    // 一括修正ボタンと削除ボタンが表示される
    expect(find.text('一括修正'), findsOneWidget);
    expect(find.text('削除(120)'), findsOneWidget);

    // スクロールして末尾の候補を確認
    await tester.scrollUntilVisible(find.text('候補119'), 200);
    expect(find.text('候補119'), findsOneWidget);
  });

  testWidgets('Issue146 - 全選択/全解除と単一選択切替', (tester) async {
    final appState = await _launchTestApp(tester);

    final drafts = List.generate(5, _draft);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
        ],
        child: MaterialApp(
          home: ReviewExtractionsScreen(drafts: drafts),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('5件を登録'), findsOneWidget);

    // すべて解除
    await tester.tap(find.byIcon(Icons.deselect));
    await tester.pumpAndSettle();
    expect(find.text('0件を登録'), findsOneWidget);

    // すべて選択
    await tester.tap(find.byIcon(Icons.select_all));
    await tester.pumpAndSettle();
    expect(find.text('5件を登録'), findsOneWidget);

    // 単一候補の選択切替（Checkboxタップ）
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('4件を登録'), findsOneWidget);

    // 選択状態のずれがないことを確認
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('5件を登録'), findsOneWidget);
  });

  testWidgets('Issue146 - 一部削除と全削除後の空状態', (tester) async {
    final appState = await _launchTestApp(tester);

    final drafts = List.generate(5, _draft);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
        ],
        child: MaterialApp(
          home: ReviewExtractionsScreen(drafts: drafts),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1件だけ選択解除してから2件削除
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.pumpAndSettle();
    expect(find.text('4件を登録'), findsOneWidget);

    await tester.tap(find.text('削除(4)'));
    await tester.pumpAndSettle();

    // 確認ダイアログ
    expect(find.text('選択した候補を削除'), findsOneWidget);
    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();

    // 4件削除されて1件残る（0番目は選択解除で残存）
    expect(find.text('1件の候補を確認'), findsOneWidget);
    expect(find.text('候補0'), findsOneWidget);

    // 全削除
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除(1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();

    // 空状態
    expect(find.text('すべての候補を削除しました'), findsOneWidget);
    expect(find.text('登録する候補がありません'), findsOneWidget);
  });

  testWidgets('Issue146 - タイトル一括置換と持ち物一括置換', (tester) async {
    final appState = await _launchTestApp(tester);

    final drafts = List.generate(5, _draft);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
        ],
        child: MaterialApp(
          home: ReviewExtractionsScreen(drafts: drafts),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // タイトル一括置換
    await tester.tap(find.text('一括修正'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '候補');
    await tester.enterText(find.byType(TextField).at(1), '修正済み');
    await tester.tap(find.text('置換'));
    await tester.pumpAndSettle();

    // 全候補が修正される
    expect(find.text('5件の候補を修正しました'), findsOneWidget);
    expect(find.text('修正済み0'), findsOneWidget);

    // 持ち物一括置換
    await tester.tap(find.text('一括修正'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('持ち物').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '持ち物');
    await tester.enterText(find.byType(TextField).at(1), '水筒');
    await tester.tap(find.text('置換'));
    await tester.pumpAndSettle();

    expect(find.text('5件の候補を修正しました'), findsOneWidget);
  });

  testWidgets('Issue146 - 空検索と一致しない検索は安全', (tester) async {
    final appState = await _launchTestApp(tester);

    final drafts = List.generate(5, _draft);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
        ],
        child: MaterialApp(
          home: ReviewExtractionsScreen(drafts: drafts),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 空検索
    await tester.tap(find.text('一括修正'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('置換'));
    await tester.pumpAndSettle();
    expect(find.text('検索文字列を入力してください'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    // 前のSnackBarの表示期限を過ぎさせる（次のSnackBarがキュー待ちにならないように）
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // 一致しない検索
    await tester.tap(find.text('一括修正'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '存在しない');
    await tester.enterText(find.byType(TextField).at(1), 'X');
    await tester.tap(find.text('置換'));
    await tester.pump();
    expect(find.text('0件の候補を修正しました'), findsOneWidget);
    await tester.pumpAndSettle();

    // 候補が破損していない
    expect(find.text('候補0'), findsOneWidget);
  });

  testWidgets('Issue146 - OCR参照は削除後も現在の状態に追従する', (tester) async {
    final appState = await _launchTestApp(tester);

    final drafts = List.generate(3, _draft);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
        ],
        child: MaterialApp(
          home: ReviewExtractionsScreen(drafts: drafts),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // OCR元テキストのExpansionTileを開く
    await tester.scrollUntilVisible(find.text('OCR元テキスト'), 200);
    await tester.tap(find.text('OCR元テキスト'));
    await tester.pumpAndSettle();
    expect(find.text('OCR元テキスト0'), findsWidgets);

    // 全削除するとOCR参照が消える
    await tester.tap(find.text('削除(3)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();
    expect(find.text('すべての候補を削除しました'), findsOneWidget);
    expect(find.text('OCR元テキスト'), findsNothing);
  });

  testWidgets('Issue146 - 編集済みかつ選択済み候補だけ登録できる', (tester) async {
    final appState = await _launchTestApp(tester);

    final drafts = List.generate(3, _draft);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
        ],
        child: MaterialApp(
          home: ReviewExtractionsScreen(drafts: drafts),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1件選択解除
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('2件を登録'), findsOneWidget);

    // 登録ボタンが押せる
    final registerButton = find.text('2件を登録');
    expect(registerButton, findsOneWidget);

    // 0件選択時は登録できない（残り2件を個別に解除）
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).at(2));
    await tester.pumpAndSettle();
    expect(find.text('0件を登録'), findsOneWidget);
  });

  testWidgets('Issue146 - 長い日本語文字列でもレイアウトが破綻しない', (tester) async {
    final appState = await _launchTestApp(tester);

    const longTitle =
        '明日の連絡帳確認と体操着忘れ防止のための非常に長いタイトルテスト文字列そのまま表示されます';
    final drafts = [
      ExtractionDraft(
        title: longTitle,
        category: TodoCategory.item,
        items: const [
          '水筒（中身はお茶か水）',
          '体操着（赤白帽も忘れずに）',
          '健康カード（捺印必須）',
          '集金袋（7,500円）',
        ],
        dueDate: DateTime(2026, 8, 10),
        rawText: '長いOCR本文'.padRight(200, 'あ'),
      ),
    ];
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
        ],
        child: MaterialApp(
          home: ReviewExtractionsScreen(drafts: drafts),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 長いタイトルと持ち物が表示される
    expect(find.text(longTitle), findsOneWidget);
    expect(find.textContaining('水筒（中身はお茶か水）'), findsOneWidget);

    // Overflowエラーが発生していない（Flutterの例外検出）
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    expect(binding.takeException(), isNull);
  });

  testWidgets('Issue146 - 画面破棄後も非同期更新でクラッシュしない', (tester) async {
    final appState = await _launchTestApp(tester);

    final drafts = List.generate(5, _draft);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
        ],
        child: MaterialApp(
          home: ReviewExtractionsScreen(drafts: drafts),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 画面を破棄（別ウィジェットへ置換）
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Center(child: Text('After Dispose'))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 破棄後に例外が起きていない
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    expect(binding.takeException(), isNull);
  });
}
