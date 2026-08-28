// test/widget_test.dart
// アプリ起動直後と主要画面遷移のウィジェットテスト。
// 関連: main.dart, src/screens/home_screen.dart, src/screens/add_child_screen.dart,
//       src/screens/todo_detail_screen.dart, src/app_state.dart

import 'dart:convert';
import 'dart:io' show Directory, Platform;

import 'package:ashita_motsumono/main.dart';
import 'package:ashita_motsumono/src/app_state.dart';
import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/repositories/drift_store.dart';
import 'package:ashita_motsumono/src/services/app_settings.dart';
import 'package:ashita_motsumono/src/services/export_service.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';
import 'package:ashita_motsumono/src/services/purchase_provider.dart';
import 'package:ashita_motsumono/src/services/sensitive_data_cleaner.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ashita_motsumono/src/screens/add_todo_screen.dart';
import 'package:ashita_motsumono/src/screens/review_extraction_screen.dart';
import 'package:ashita_motsumono/src/screens/todo_detail_screen.dart';

/// 現在のモック SharedPreferences から AppSettings を生成する。
Future<AppSettings> _createSettings() async {
  final prefs = await SharedPreferences.getInstance();
  return AppSettings(prefs);
}

/// Advances enough deterministic frames for route and implicit animations.
///
/// The app can keep scheduling frames while the HomeScreen is visible, so
/// pumpAndSettle is not a valid completion condition for these UI tests.
Future<void> _pumpUi(WidgetTester tester) async {
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// テスト用の NotificationService（実プラグインへ到達しない）。
class _FakeNotificationService extends NotificationService {
  _FakeNotificationService() : super(timezoneName: 'Asia/Tokyo');

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> scheduleTodo(AppTodo todo) async {}

  @override
  Future<void> cancelTodo(String todoId) async {}
}

/// テスト用の PurchaseProvider（実際の課金処理は行わない）。
class _TestPurchaseProvider extends PurchaseProvider {
  _TestPurchaseProvider({
    this.adRemoved = false,
    this.aiAccess = false,
    this.priceLabel = '買い切り ¥190',
    this.canPurchase = true,
    this.statusMessage,
  });

  @override
  final bool adRemoved;

  @override
  final bool aiAccess;

  @override
  bool get busy => false;

  @override
  final String priceLabel;

  @override
  String get aiPriceLabel => '買い切り ¥190';

  @override
  final bool canPurchase;

  @override
  bool get canPurchaseAi => true;

  @override
  final String? statusMessage;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  Future<void> purchase() async {}

  @override
  Future<void> purchaseAi() async {}

  @override
  Future<void> restore() async {}
}

/// 通知説明ダイアログをスキップした AppState を生成する。
Future<AppState> _createAppState() async {
  SharedPreferences.setMockInitialValues({
    'onboarding_completed_v1': true,
    'notification_info_shown_v1': true,
  });
  // Widget tests run in a fake-async zone, so real temporary-directory IO
  // must be synchronous or the setup Future can remain pending indefinitely.
  final tempDir = Directory.systemTemp.createTempSync('ashita_widget_test_');
  addTearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
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
  addTearDown(appState.close);
  return appState;
}

void main() {
  // 各テストが独立したインメモリDBを使うため、複数インスタンス警告は抑制
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('HomeScreen', () {
    testWidgets('shows home screen and first run card', (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_completed_v1': true,
        'notification_info_shown_v1': true,
      });
      final settings = await _createSettings();
      final store = await DriftStore.createInMemory();
      final appState = AppState(
        store: store,
        notifications: _FakeNotificationService(),
      );
      await appState.load();
      addTearDown(appState.close);

      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(priceLabel: '買い切り ¥190'),
        ),
      );
      await _pumpUi(tester);

      expect(find.text('あしたもつもの'), findsOneWidget);
      expect(find.text('まず人物を登録'), findsOneWidget);
      expect(find.text('Todoは人物別に整理できます。\nログイン不要・端末内保存です。'), findsOneWidget);
    });

    testWidgets('shows empty state when children exist but no todos', (
      tester,
    ) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await appState.addChild('長女');

      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(priceLabel: '買い切り ¥190'),
        ),
      );
      await _pumpUi(tester);

      expect(find.text('まず人物を登録'), findsNothing);
      expect(find.text('Todoがありません'), findsOneWidget);
      expect(find.text('「追加」ボタンから新しくTodoを作成できます'), findsOneWidget);
    });

    testWidgets('shows today section with due todo', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await appState.addChild('次男');
      await appState.addTodoFromDraft(
        draft: ExtractionDraft(
          title: '水筒を持参',
          category: TodoCategory.item,
          items: ['水筒'],
          dueDate: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(),
        ),
      );
      await _pumpUi(tester);

      expect(find.text('今日やること'), findsOneWidget);
      expect(find.text('水筒を持参'), findsOneWidget);
    });

    testWidgets('reports no corrupt data on normal load', (tester) async {
      final appState = await _createAppState();
      expect(appState.lastLoadHadCorruptData, isFalse);
    });

    testWidgets('opens settings from bottom nav', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();

      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(),
        ),
      );
      await _pumpUi(tester);

      await tester.tap(find.text('設定'));
      await _pumpUi(tester);

      expect(find.text('通知時刻'), findsOneWidget);
    });

    test('creates export snapshot without local image paths', () async {
      final appState = await _createAppState();
      final doc = await appState.addDocument(
        sourceType: 'camera',
        localImagePath: '/private/photo.jpg',
        ocrText: '明日までに水筒を持参',
        pages: const [
          DocumentPageRecord(
            id: 'page-0',
            documentId: 'page-doc',
            pageIndex: 0,
            localImagePath: '/private/page-0.jpg',
            ocrText: '1ページ目',
          ),
        ],
      );
      await appState.addTodoFromDraft(
        draft: const ExtractionDraft(
          title: '水筒を持参',
          category: TodoCategory.item,
          items: ['水筒'],
        ),
        documentId: doc.id,
      );

      final snapshot = createExportSnapshot(appState);

      expect(snapshot.documents.single.localImagePath, null);
      expect(snapshot.documents.single.ocrText, '明日までに水筒を持参');
      expect(snapshot.todos.single.documentId, doc.id);
      final json = jsonEncode(snapshot.toJson());
      expect(json, isNot(contains('localImagePath')));
    });
  });

  group('AddChildScreen', () {
    testWidgets('shows empty state and can add a child', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(),
        ),
      );
      await _pumpUi(tester);

      await tester.tap(find.byIcon(Icons.person_add_outlined));
      await _pumpUi(tester);

      expect(find.text('まだ登録されていません。'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '長女');
      await tester.tap(find.text('追加'));
      await _pumpUi(tester);

      expect(find.text('まだ登録されていません。'), findsNothing);
      expect(find.text('長女'), findsOneWidget);
    });

    testWidgets('prevents duplicate name', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await appState.addChild('長女');
      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(),
        ),
      );
      await _pumpUi(tester);

      await tester.tap(find.byIcon(Icons.person_add_outlined));
      await _pumpUi(tester);

      await tester.enterText(find.byType(TextField), '長女');
      await tester.tap(find.text('追加'));
      await _pumpUi(tester);

      expect(find.text('同じ名前がすでに登録されています'), findsOneWidget);
    });
  });

  group('TodoDetailScreen', () {
    testWidgets('shows todo details after tapping a tile', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await appState.addTodoFromDraft(
        draft: ExtractionDraft(
          title: '集金袋を提出',
          category: TodoCategory.submit,
          items: ['集金袋'],
          amount: 3000,
          dueDate: DateTime.now(),
          note: '封筒に入れて持参',
        ),
      );

      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(),
        ),
      );
      await _pumpUi(tester);

      expect(find.text('今日やること'), findsOneWidget);
      await tester.tap(find.text('集金袋を提出'));
      await _pumpUi(tester);

      expect(find.text('Todo詳細'), findsOneWidget);
      expect(find.text('提出'), findsWidgets);
      expect(find.text('金額：'), findsOneWidget);
      expect(find.text('3000円'), findsOneWidget);
    });

    testWidgets('shows not found when todo is missing', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: appState,
            child: const TodoDetailScreen(todoId: 'nonexistent'),
          ),
        ),
      );
      await _pumpUi(tester);

      expect(find.text('Todoが見つかりませんでした'), findsOneWidget);
    });
  });

  group('ReviewExtractionScreen', () {
    testWidgets('deletes document when cancelled without save', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await appState.addChild('長女');
      final doc = await appState.addDocument(
        sourceType: 'paste',
        ocrText: '明日までに水筒を持参',
      );
      final docId = doc.id;

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: appState),
            ChangeNotifierProvider.value(value: settings),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReviewExtractionScreen(
                      draft: const ExtractionDraft(
                        title: '水筒を持参',
                        category: TodoCategory.item,
                        items: ['水筒'],
                      ),
                      documentId: docId,
                    ),
                  ),
                ),
                child: const Text('開く'),
              ),
            ),
          ),
        ),
      );
      await _pumpUi(tester);

      await tester.tap(find.text('開く'));
      await _pumpUi(tester);

      expect(find.text('読み取り結果の確認'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await _pumpUi(tester);

      expect(appState.documents.where((d) => d.id == docId), isEmpty);
    });
  });

  group('SettingsScreen', () {
    Future<void> _openSettings(WidgetTester tester) async {
      await tester.tap(find.text('設定'));
      await _pumpUi(tester);
    }

    testWidgets('shows notification time tiles', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();

      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(),
        ),
      );
      await _pumpUi(tester);

      await _openSettings(tester);

      expect(find.text('通知時刻'), findsOneWidget);
      expect(find.text('夜 前日 20:00'), findsOneWidget);
      expect(find.text('朝 当日 07:00'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('サポーター'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await _pumpUi(tester);
      expect(find.text('サポーター'), findsOneWidget);
    });

    testWidgets('shows purchase section', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();

      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(),
        ),
      );
      await _pumpUi(tester);

      await _openSettings(tester);
      await tester.scrollUntilVisible(
        find.text('買い切りサポーター'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await _pumpUi(tester);

      expect(find.text('買い切りサポーター'), findsOneWidget);
      expect(find.text('買い切り ¥190'), findsNWidgets(2));
      expect(find.text('広告を消して応援する'), findsOneWidget);
      expect(find.text('購入を復元'), findsOneWidget);
    });

    testWidgets('shows purchase status when store product is unavailable', (
      tester,
    ) async {
      final appState = await _createAppState();
      final settings = await _createSettings();

      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(
            canPurchase: false,
            statusMessage: '購入アイテムを準備中です。しばらくしてからもう一度お試しください。',
          ),
        ),
      );
      await _pumpUi(tester);

      await _openSettings(tester);
      await tester.scrollUntilVisible(
        find.text('購入アイテムを準備中です。しばらくしてからもう一度お試しください。'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await _pumpUi(tester);

      expect(find.text('購入アイテムを準備中です。しばらくしてからもう一度お試しください。'), findsNWidgets(2));
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '広告を消して応援する'),
      );
      expect(button.onPressed, null);
    });

    testWidgets('shows supporter thank-you when ads are removed', (
      tester,
    ) async {
      final appState = await _createAppState();
      final settings = await _createSettings();

      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(adRemoved: true),
        ),
      );
      await _pumpUi(tester);

      await _openSettings(tester);
      await tester.scrollUntilVisible(
        find.text('サポーター登録済み'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await _pumpUi(tester);

      expect(find.text('サポーター登録済み'), findsOneWidget);
      expect(find.text('広告なしで使えます。ご購入ありがとうございます。'), findsOneWidget);
    });

    testWidgets('clears all local data after confirmation', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await appState.addChild('長女');
      await settings.addLearnedItemLabels(['軍手']);
      await appState.addTodoFromDraft(
        draft: const ExtractionDraft(
          title: '水筒を持参',
          category: TodoCategory.item,
          items: ['水筒'],
        ),
      );

      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(),
        ),
      );
      await _pumpUi(tester);

      await _openSettings(tester);
      await tester.dragUntilVisible(
        find.text('登録データをすべて削除'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await _pumpUi(tester);

      await tester.tap(find.text('登録データをすべて削除'));
      await _pumpUi(tester);
      await tester.tap(find.text('削除する'));
      for (
        var attempt = 0;
        attempt < 400 && find.text('登録データを削除しました').evaluate().isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(find.textContaining('登録データの削除に失敗しました').evaluate(), isEmpty);
      expect(appState.children, isEmpty);
      expect(appState.todos, isEmpty);
      expect(appState.documents, isEmpty);
      expect(settings.learnedItemLabels, isEmpty);
    });
  });

  group('AddTodoScreen', () {
    testWidgets('AI button opens external data disclosure', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await appState.addChild('長女');

      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(
            adRemoved: true,
            aiAccess: true,
          ),
        ),
      );
      await _pumpUi(tester);

      await tester.tap(find.text('追加'));
      await _pumpUi(tester);
      await tester.tap(find.text('AIで解析（手書きも対応）'));
      await _pumpUi(tester);

      expect(find.text('AI画像解析について'), findsOneWidget);
      expect(find.textContaining('Cloudflare Workers'), findsOneWidget);
      expect(find.textContaining('Google Gemini API'), findsOneWidget);
      expect(find.textContaining('通常のOCRでは画像を外部送信しません'), findsOneWidget);
      expect(find.text('同意して画像を選ぶ'), findsOneWidget);

      await tester.tap(find.text('キャンセル'));
      await _pumpUi(tester);
      expect(find.text('AI画像解析について'), findsNothing);
    });

    testWidgets('AI analysis starts only after explicit consent', (
      tester,
    ) async {
      var startCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => requestAiImageAnalysisWithDisclosure(
                  context,
                  startAnalysis: () async => startCount++,
                ),
                child: const Text('AI解析を開始'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('AI解析を開始'));
      await _pumpUi(tester);
      await tester.tap(find.text('キャンセル'));
      await _pumpUi(tester);
      expect(startCount, 0);

      await tester.tap(find.text('AI解析を開始'));
      await _pumpUi(tester);
      await tester.tap(find.text('同意して画像を選ぶ'));
      await _pumpUi(tester);
      expect(startCount, 1);
    });

    testWidgets('shows add screen with OCR and paste options', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await appState.addChild('長女');

      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(),
        ),
      );
      await _pumpUi(tester);

      await tester.tap(find.text('追加'));
      await _pumpUi(tester);

      expect(find.text('画像・スクショから登録'), findsOneWidget);
      if (Platform.isWindows) {
        expect(find.text('写真を撮る'), findsNothing);
        expect(find.text('画像を選ぶ'), findsNothing);
        expect(find.textContaining('カメラ・OCRはWindows未対応'), findsOneWidget);
      } else {
        expect(find.text('写真を撮る'), findsOneWidget);
        expect(find.text('画像を選ぶ'), findsOneWidget);
      }
      expect(find.text('OCRテキストを貼り付けて抽出'), findsOneWidget);
      expect(find.text('手動で入力する'), findsOneWidget);
    });

    testWidgets('shows manual input form when toggled', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await appState.addChild('長女');

      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(),
        ),
      );
      await _pumpUi(tester);

      await tester.tap(find.text('追加'));
      await _pumpUi(tester);

      await tester.tap(find.byIcon(Icons.edit_note));
      await _pumpUi(tester);

      expect(find.text('手入力'), findsOneWidget);
      // Scroll down to reveal manual form TextFields (paste field is scrolled out of tree)
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await _pumpUi(tester);
      expect(find.byType(TextField), findsNWidgets(4));
    });

    testWidgets('validates empty title on manual save', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await appState.addChild('長女');

      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(),
        ),
      );
      await _pumpUi(tester);

      await tester.tap(find.text('追加'));
      await _pumpUi(tester);

      await tester.tap(find.byIcon(Icons.edit_note));
      await _pumpUi(tester);

      // Scroll to reveal the 登録 button
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await _pumpUi(tester);

      await tester.tap(find.widgetWithText(FilledButton, '登録'));
      await _pumpUi(tester);

      expect(find.text('タイトルを入力してください'), findsOneWidget);
    });

    testWidgets('creates multiple review candidates from pasted notice', (
      tester,
    ) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await appState.addChild('長女');

      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(),
        ),
      );
      await _pumpUi(tester);

      await tester.tap(find.text('追加'));
      await _pumpUi(tester);

      // 相対日付を使い、ウォールクロック依存を排除（固定日付だと
      // 実行日が過ぎたときに期限確認表記に変わりテストが壊れる）
      await tester.enterText(
        find.byType(TextField).first,
        '明日までに水着、帽子、タオルを持参してください。\n'
        '集金袋に500円を入れて提出してください。\n'
        '申込書は明後日までに提出してください。',
      );
      await tester.tap(find.text('貼り付け文からTodo候補を作る'));
      await _pumpUi(tester);

      expect(find.text('3件の候補を確認'), findsOneWidget);
      expect(find.text('持ち物：水着・帽子・タオル'), findsOneWidget);
      expect(find.text('集金 500円'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await _pumpUi(tester);
      expect(find.text('申込書を提出'), findsOneWidget);

      await tester.tap(find.text('3件を登録'));
      await _pumpUi(tester);

      expect(appState.todos.map((todo) => todo.title), [
        '持ち物：水着・帽子・タオル',
        '集金 500円',
        '申込書を提出',
      ]);
      expect(appState.documents, hasLength(1));
      expect(appState.todos.map((todo) => todo.documentId).toSet(), {
        appState.documents.single.id,
      });
    });

    testWidgets('learns manually entered items for later pasted extraction', (
      tester,
    ) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await appState.addChild('長女');

      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(),
        ),
      );
      await _pumpUi(tester);

      await tester.tap(find.text('追加'));
      await _pumpUi(tester);

      await tester.tap(find.byIcon(Icons.edit_note));
      await _pumpUi(tester);

      // Scroll to reveal manual form fields
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await _pumpUi(tester);

      await tester.enterText(
        find.widgetWithText(TextField, '例：集金袋を提出'),
        '軍手を持参',
      );

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await _pumpUi(tester);

      await tester.enterText(
        find.widgetWithText(TextField, '水筒、体操着、集金袋'),
        '軍手',
      );

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await _pumpUi(tester);

      await tester.tap(find.widgetWithText(FilledButton, '登録'));
      await _pumpUi(tester);

      await tester.tap(find.text('追加'));
      await _pumpUi(tester);
      // 相対日付（ウォールクロック依存を排除）
      await tester.enterText(find.byType(TextField).first, '明日までに軍手を持参');
      await tester.tap(find.text('貼り付け文からTodo候補を作る'));
      await _pumpUi(tester);

      expect(find.text('持ち物：軍手'), findsOneWidget);
    });
  });

  group('HomeScreen search', () {
    testWidgets('filters todos by search query', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await appState.addChild('長女');
      await appState.addTodoFromDraft(
        draft: ExtractionDraft(
          title: '水筒を持参',
          category: TodoCategory.item,
          items: ['水筒'],
          dueDate: DateTime.now(),
        ),
      );
      await appState.addTodoFromDraft(
        draft: ExtractionDraft(
          title: '集金袋を提出',
          category: TodoCategory.submit,
          items: ['集金袋'],
          amount: 3000,
          dueDate: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(),
        ),
      );
      await _pumpUi(tester);

      expect(find.text('水筒を持参'), findsOneWidget);
      expect(find.text('集金袋を提出'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '水筒');
      await _pumpUi(tester);

      expect(find.text('水筒を持参'), findsOneWidget);
      expect(find.text('集金袋を提出'), findsNothing);
    });
  });

  group('HomeScreen todo completion', () {
    testWidgets('toggles todo completion via checkbox', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await appState.addChild('長女');
      await appState.addTodoFromDraft(
        draft: ExtractionDraft(
          title: '水筒を持参',
          category: TodoCategory.item,
          items: ['水筒'],
          dueDate: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        AshitaMotsumonoApp(
          appState: appState,
          settings: settings,
          purchaseProvider: _TestPurchaseProvider(),
        ),
      );
      await _pumpUi(tester);

      expect(find.text('水筒を持参'), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      await _pumpUi(tester);

      expect(appState.todos.first.isDone, isTrue);
    });
  });
}
