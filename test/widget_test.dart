// test/widget_test.dart
// アプリ起動直後と主要画面遷移のウィジェットテスト。
// 関連: main.dart, src/screens/home_screen.dart, src/screens/add_child_screen.dart,
//       src/screens/todo_detail_screen.dart, src/app_state.dart

import 'package:ashita_motsumono/main.dart';
import 'package:ashita_motsumono/src/app_state.dart';
import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/repositories/drift_store.dart';
import 'package:ashita_motsumono/src/services/app_settings.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';
import 'package:ashita_motsumono/src/services/purchase_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ashita_motsumono/src/screens/review_extraction_screen.dart';
import 'package:ashita_motsumono/src/screens/todo_detail_screen.dart';

/// 現在のモック SharedPreferences から AppSettings を生成する。
Future<AppSettings> _createSettings() async {
  final prefs = await SharedPreferences.getInstance();
  return AppSettings(prefs);
}

/// テスト用の PurchaseProvider（実際の課金処理は行わない）。
class _TestPurchaseProvider extends ChangeNotifier
    implements PurchaseProvider {
  @override
  bool get adRemoved => false;

  @override
  bool get busy => false;

  @override
  Future<void> purchase() async {}
}

/// 通知説明ダイアログをスキップした AppState を生成する。
Future<AppState> _createAppState() async {
  SharedPreferences.setMockInitialValues({'notification_info_shown_v1': true});
  final store = await DriftStore.createInMemory();
  final appState = AppState(
    store: store,
    notifications: NotificationService(timezoneName: 'Asia/Tokyo'),
  );
  await appState.load();
  return appState;
}

void main() {
  // 各テストが独立したインメモリDBを使うため、複数インスタンス警告は抑制
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('HomeScreen', () {
    testWidgets('shows home screen and first run card', (tester) async {
      // 初回起動（通知フラグなし）→ ダイアログが出るがcardは見えている
      SharedPreferences.setMockInitialValues({});
      final settings = await _createSettings();
      final store = await DriftStore.createInMemory();
      final appState = AppState(
        store: store,
        notifications: NotificationService(timezoneName: 'Asia/Tokyo'),
      );
      await appState.load();

      await tester.pumpWidget(AshitaMotsumonoApp(appState: appState, settings: settings, purchaseProvider: _TestPurchaseProvider()));
      await tester.pumpAndSettle();

      expect(find.text('あした持つもの'), findsOneWidget);
      expect(find.text('まず人物を登録'), findsOneWidget);
      expect(
        find.text('Todoは人物別に整理できます。\nログイン不要・端末内保存です。'),
        findsOneWidget,
      );
    });

    testWidgets('shows empty state when children exist but no todos', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await appState.addChild('長女');

      await tester.pumpWidget(AshitaMotsumonoApp(appState: appState, settings: settings, purchaseProvider: _TestPurchaseProvider()));
      await tester.pumpAndSettle();

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

      await tester.pumpWidget(AshitaMotsumonoApp(appState: appState, settings: settings, purchaseProvider: _TestPurchaseProvider()));
      await tester.pumpAndSettle();

      expect(find.text('今日やること'), findsOneWidget);
      expect(find.text('水筒を持参'), findsOneWidget);
    });

    testWidgets('reports no corrupt data on normal load', (tester) async {
      final appState = await _createAppState();
      expect(appState.lastLoadHadCorruptData, isFalse);
    });
  });

  group('AddChildScreen', () {
    testWidgets('shows empty state and can add a child', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await tester.pumpWidget(AshitaMotsumonoApp(appState: appState, settings: settings, purchaseProvider: _TestPurchaseProvider()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pumpAndSettle();

      expect(find.text('まだ登録されていません。'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '長女');
      await tester.tap(find.text('追加'));
      await tester.pumpAndSettle();

      expect(find.text('まだ登録されていません。'), findsNothing);
      expect(find.text('長女'), findsOneWidget);
    });

    testWidgets('prevents duplicate name', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await appState.addChild('長女');
      await tester.pumpWidget(AshitaMotsumonoApp(appState: appState, settings: settings, purchaseProvider: _TestPurchaseProvider()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '長女');
      await tester.tap(find.text('追加'));
      await tester.pumpAndSettle();

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

      await tester.pumpWidget(AshitaMotsumonoApp(appState: appState, settings: settings, purchaseProvider: _TestPurchaseProvider()));
      await tester.pumpAndSettle();

      expect(find.text('今日やること'), findsOneWidget);
      await tester.tap(find.text('集金袋を提出'));
      await tester.pumpAndSettle();

      expect(find.text('Todo詳細'), findsOneWidget);
      expect(find.text('種類：提出'), findsOneWidget);
      expect(find.text('金額：3000円'), findsOneWidget);
    });

    testWidgets('shows not found when todo is missing', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await tester.pumpWidget(AshitaMotsumonoApp(appState: appState, settings: settings, purchaseProvider: _TestPurchaseProvider()));
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: appState,
            child: const TodoDetailScreen(todoId: 'nonexistent'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Todoが見つかりませんでした'), findsOneWidget);
    });
  });

  group('ReviewExtractionScreen', () {
    testWidgets('deletes document when cancelled without save', (tester) async {
      final appState = await _createAppState();
      await appState.addChild('長女');
      final doc = await appState.addDocument(
        sourceType: 'paste',
        ocrText: '明日までに水筒を持参',
      );
      final docId = doc.id;

      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: appState,
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
      await tester.pumpAndSettle();

      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();

      expect(find.text('読み取り結果の確認'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(appState.documents.where((d) => d.id == docId), isEmpty);
    });
  });

  group('SettingsScreen', () {
    testWidgets('shows notification time tiles', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();

      await tester.pumpWidget(AshitaMotsumonoApp(
        appState: appState,
        settings: settings,
        purchaseProvider: _TestPurchaseProvider(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('設定'), findsOneWidget);
      expect(find.text('通知時刻'), findsOneWidget);
      expect(find.textContaining('前日（夜）'), findsOneWidget);
      expect(find.textContaining('当日（朝）'), findsOneWidget);
      expect(find.text('広告'), findsOneWidget);
    });

    testWidgets('shows purchase section', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();

      await tester.pumpWidget(AshitaMotsumonoApp(
        appState: appState,
        settings: settings,
        purchaseProvider: _TestPurchaseProvider(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('広告を除去する'), findsOneWidget);
      expect(find.text('買い切り 190円（税込）'), findsOneWidget);
    });
  });

  group('AddTodoScreen', () {
    testWidgets('shows add screen with OCR and paste options', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await appState.addChild('長女');

      await tester.pumpWidget(AshitaMotsumonoApp(
        appState: appState,
        settings: settings,
        purchaseProvider: _TestPurchaseProvider(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('追加'));
      await tester.pumpAndSettle();

      expect(find.text('画像・スクショから登録'), findsOneWidget);
      expect(find.text('写真を撮る'), findsOneWidget);
      expect(find.text('画像を選ぶ'), findsOneWidget);
      expect(find.text('OCRテキストを貼り付けて抽出'), findsOneWidget);
      expect(find.text('手動で入力する'), findsOneWidget);
    });

    testWidgets('shows manual input form when toggled', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await appState.addChild('長女');

      await tester.pumpWidget(AshitaMotsumonoApp(
        appState: appState,
        settings: settings,
        purchaseProvider: _TestPurchaseProvider(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('追加'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('手動で入力する'));
      await tester.pumpAndSettle();

      expect(find.text('手入力'), findsOneWidget);
      expect(find.text('タイトル'), findsOneWidget);
    });

    testWidgets('validates empty title on manual save', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await appState.addChild('長女');

      await tester.pumpWidget(AshitaMotsumonoApp(
        appState: appState,
        settings: settings,
        purchaseProvider: _TestPurchaseProvider(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('追加'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('手動で入力する'));
      await tester.pumpAndSettle();

      // Scroll to find the register button
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Tap register with empty title
      await tester.tap(find.text('登録'));
      await tester.pumpAndSettle();

      expect(find.text('タイトルを入力してください'), findsOneWidget);
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

      await tester.pumpWidget(AshitaMotsumonoApp(
        appState: appState,
        settings: settings,
        purchaseProvider: _TestPurchaseProvider(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('水筒を持参'), findsOneWidget);
      expect(find.text('集金袋を提出'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '水筒');
      await tester.pumpAndSettle();

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

      await tester.pumpWidget(AshitaMotsumonoApp(
        appState: appState,
        settings: settings,
        purchaseProvider: _TestPurchaseProvider(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('水筒を持参'), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(appState.todos.first.isDone, isTrue);
    });
  });
}
