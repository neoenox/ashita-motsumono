// test/review_extractions_ux_test.dart
// OCR確認画面の大量候補・選択・削除・一括置換・OCR参照をCIで検証する。

import 'package:ashita_motsumono/src/app_state.dart';
import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/repositories/drift_store.dart';
import 'package:ashita_motsumono/src/screens/review_extractions_screen.dart';
import 'package:ashita_motsumono/src/services/app_settings.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ReviewHarness {
  const _ReviewHarness({required this.appState, required this.settings});

  final AppState appState;
  final AppSettings settings;

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await appState.close();
    appState.dispose();
    settings.dispose();
  }
}

Future<_ReviewHarness> _mountReview(
  WidgetTester tester,
  List<ExtractionDraft> drafts,
) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs);
  final store = await DriftStore.createInMemory();
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
      child: MaterialApp(home: ReviewExtractionsScreen(drafts: drafts)),
    ),
  );
  await tester.pumpAndSettle();
  return _ReviewHarness(appState: appState, settings: settings);
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
  testWidgets('120件の候補を表示して末尾まで操作できる', (tester) async {
    final harness = await _mountReview(tester, List.generate(120, _draft));
    addTearDown(() => harness.dispose(tester));

    expect(find.text('120件の候補を確認'), findsOneWidget);
    expect(find.text('120件を登録'), findsOneWidget);
    expect(find.text('一括修正'), findsOneWidget);
    expect(find.text('削除(120)'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('候補119'), 300);
    expect(find.text('候補119'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('全選択・全解除と単一候補の選択状態が一致する', (tester) async {
    final harness = await _mountReview(tester, List.generate(5, _draft));
    addTearDown(() => harness.dispose(tester));

    await tester.tap(find.byIcon(Icons.deselect));
    await tester.pumpAndSettle();
    expect(find.text('0件を登録'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.select_all));
    await tester.pumpAndSettle();
    expect(find.text('5件を登録'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('4件を登録'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('5件を登録'), findsOneWidget);
  });

  testWidgets('選択候補を削除すると空状態とOCR参照が同期する', (tester) async {
    final harness = await _mountReview(tester, List.generate(3, _draft));
    addTearDown(() => harness.dispose(tester));

    expect(find.text('OCR元テキスト'), findsOneWidget);
    await tester.tap(find.text('削除(3)'));
    await tester.pumpAndSettle();
    expect(find.text('選択した候補を削除'), findsOneWidget);

    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();

    expect(find.text('すべての候補を削除しました'), findsOneWidget);
    expect(find.text('登録する候補がありません'), findsOneWidget);
    expect(find.text('OCR元テキスト'), findsNothing);
  });

  testWidgets('タイトルと持ち物を一括置換できる', (tester) async {
    final harness = await _mountReview(tester, List.generate(5, _draft));
    addTearDown(() => harness.dispose(tester));

    await tester.tap(find.text('一括修正'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '候補');
    await tester.enterText(find.byType(TextField).at(1), '修正済み');
    await tester.tap(find.text('置換'));
    await tester.pumpAndSettle();

    expect(find.text('5件の候補を修正しました'), findsOneWidget);
    expect(find.text('修正済み0'), findsOneWidget);

    await tester.tap(find.text('一括修正'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('持ち物').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '持ち物');
    await tester.enterText(find.byType(TextField).at(1), '水筒');
    await tester.tap(find.text('置換'));
    await tester.pumpAndSettle();

    expect(find.text('5件の候補を修正しました'), findsOneWidget);
    expect(find.textContaining('水筒0'), findsOneWidget);
  });

  testWidgets('空検索と一致しない検索で候補を破損しない', (tester) async {
    final harness = await _mountReview(tester, List.generate(3, _draft));
    addTearDown(() => harness.dispose(tester));

    await tester.tap(find.text('一括修正'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('置換'));
    await tester.pump();
    expect(find.text('検索文字列を入力してください'), findsOneWidget);

    await tester.tap(find.text('キャンセル'));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('一括修正'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '存在しない');
    await tester.enterText(find.byType(TextField).at(1), 'X');
    await tester.tap(find.text('置換'));
    await tester.pump();

    expect(find.text('0件の候補を修正しました'), findsOneWidget);
    expect(find.text('候補0'), findsOneWidget);
    expect(find.text('候補1'), findsOneWidget);
    expect(find.text('候補2'), findsOneWidget);
  });

  testWidgets('長い日本語でもレイアウト例外を発生させない', (tester) async {
    const longTitle =
        '明日の連絡帳確認と体操着忘れ防止のための非常に長いタイトルテスト文字列そのまま表示されます';
    final harness = await _mountReview(tester, [
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
    ]);
    addTearDown(() => harness.dispose(tester));

    expect(find.text(longTitle), findsOneWidget);
    expect(find.textContaining('水筒（中身はお茶か水）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
