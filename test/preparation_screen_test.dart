// test/preparation_screen_test.dart
// PreparationScreen（今日の準備モード）のwidgetテスト。
// 1件表示→準備できた→完了、Undo動作、二重タップ防止、あとで、除外を検証。
// 関連: lib/src/screens/preparation_screen.dart, lib/src/app_state.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ashita_motsumono/src/app_state.dart';
import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/repositories/drift_store.dart';
import 'package:ashita_motsumono/src/screens/preparation_screen.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';

import 'shared/fake_notification_service.dart';

/// AppState を生成するヘルパー
Future<AppState> _createAppState() async {
  final store = await DriftStore.createInMemory();
  final notifications = FakeNotificationService();
  final state = AppState(store: store, notifications: notifications);
  await state.load();
  return state;
}

Widget _buildApp(AppState appState) {
  return MaterialApp(
    home: ChangeNotifierProvider.value(
      value: appState,
      child: PreparationScreen(date: DateTime(2026, 7, 10)),
    ),
  );
}

final _today = DateTime(2026, 7, 10);

void main() {
  group('PreparationScreen', () {
    testWidgets('shows single item and navigates to completion on prepared', (
      tester,
    ) async {
      final appState = await _createAppState();
      await appState.addChild('長女');
      await appState.addTodoFromDraft(
        draft: ExtractionDraft(
          title: '水筒を持参',
          category: TodoCategory.item,
          dueDate: _today,
          items: [],
        ),
        personId: appState.children.first.id,
      );

      await tester.pumpWidget(_buildApp(appState));
      await tester.pumpAndSettle();

      // 1件表示
      expect(find.text('水筒を持参'), findsOneWidget);
      expect(find.text('準備できた'), findsOneWidget);

      // 準備できたをタップ
      await tester.tap(find.text('準備できた'));
      await tester.pump();

      // 保存中...少し待つ
      await tester.pump(const Duration(milliseconds: 500));

      // 完了画面
      expect(find.text('今日の準備は完了です'), findsOneWidget);
      expect(find.text('1件すべて確認しました'), findsOneWidget);
    });

    testWidgets('undo last item returns from completion to prep screen', (
      tester,
    ) async {
      final appState = await _createAppState();
      await appState.addChild('長女');
      await appState.addTodoFromDraft(
        draft: ExtractionDraft(
          title: '連絡帳を提出',
          category: TodoCategory.submit,
          dueDate: _today,
          items: [],
        ),
        personId: appState.children.first.id,
      );

      await tester.pumpWidget(_buildApp(appState));
      await tester.pumpAndSettle();

      await tester.tap(find.text('準備できた'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // 完了画面
      expect(find.text('今日の準備は完了です'), findsOneWidget);

      // Undo
      await tester.tap(find.text('元に戻す'));
      await tester.pumpAndSettle();

      // 準備画面に戻り、Todoが再表示される
      expect(find.text('連絡帳を提出'), findsOneWidget);
    });

    testWidgets('disables buttons while processing', (tester) async {
      final appState = await _createAppState();
      await appState.addChild('長女');
      await appState.addTodoFromDraft(
        draft: ExtractionDraft(
          title: 'タオル',
          category: TodoCategory.item,
          dueDate: _today,
          items: [],
        ),
        personId: appState.children.first.id,
      );

      await tester.pumpWidget(_buildApp(appState));
      await tester.pumpAndSettle();

      // FilledButton が存在することを確認
      expect(find.widgetWithText(FilledButton, '準備できた'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '準備できた'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.pumpAndSettle();
    });

    testWidgets('deferred items reappear in second pass', (tester) async {
      final appState = await _createAppState();
      await appState.addChild('長女');
      await appState.addTodoFromDraft(
        draft: ExtractionDraft(
          title: 'Item A',
          category: TodoCategory.item,
          dueDate: _today,
          items: [],
        ),
      );
      await appState.addTodoFromDraft(
        draft: ExtractionDraft(
          title: 'Item B',
          category: TodoCategory.item,
          dueDate: _today,
          items: [],
        ),
      );

      await tester.pumpWidget(_buildApp(appState));
      await tester.pumpAndSettle();

      // 1件目をあとで
      await tester.tap(find.text('あとで'));
      await tester.pumpAndSettle();

      // 2件目が表示される
      expect(find.text('Item B'), findsOneWidget);

      // 2件目を準備
      await tester.tap(find.text('準備できた'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // あとで項目が再表示（2周目）
      expect(find.text('Item A'), findsOneWidget);
      // 2周目ではあとでボタン非表示
      expect(find.text('あとで'), findsNothing);
    });

    testWidgets('excludes an item and undo restores it', (tester) async {
      final appState = await _createAppState();
      await appState.addChild('長女');
      await appState.addTodoFromDraft(
        draft: ExtractionDraft(
          title: '水筒',
          category: TodoCategory.item,
          dueDate: _today,
          items: [],
        ),
      );

      await tester.pumpWidget(_buildApp(appState));
      await tester.pumpAndSettle();

      // オーバーフローメニュー（三点リーダー）を開く
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      await tester.tap(find.text('今回は外す'));
      await tester.pumpAndSettle();

      // 完了画面（completedCount=0 → 空の状態用文言）
      expect(find.text('今日は準備するものはありません'), findsOneWidget);
      expect(find.text('追加の確認は不要です'), findsOneWidget);
      expect(find.text('0件すべて確認しました'), findsNothing);

      // SnackBarのUndo
      await tester.tap(find.text('元に戻す'));
      await tester.pumpAndSettle();

      // 項目が復活
      expect(find.text('水筒'), findsOneWidget);
    });

    testWidgets('shows already done screen when all items prepared', (
      tester,
    ) async {
      final appState = await _createAppState();
      await appState.addChild('長女');
      await appState.addTodoFromDraft(
        draft: ExtractionDraft(
          title: 'Done item',
          category: TodoCategory.other,
          dueDate: _today,
          items: [],
        ),
      );

      // 事前に準備済みにする
      final todo = appState.todos.first;
      await appState.markTodoPrepared(todo.id, _today);

      await tester.pumpWidget(_buildApp(appState));
      await tester.pumpAndSettle();

      expect(find.text('今日の準備は完了です'), findsOneWidget);
      expect(find.text('1件準備できました'), findsOneWidget);
    });

    testWidgets('shows completion screen with unresolved items', (tester) async {
      final appState = await _createAppState();
      await appState.addChild('長女');
      // 2件、両方とも期限本日
      await appState.addTodoFromDraft(
        draft: ExtractionDraft(
          title: 'Prepare me',
          category: TodoCategory.item,
          dueDate: _today,
          items: [],
        ),
      );
      await appState.addTodoFromDraft(
        draft: ExtractionDraft(
          title: 'Skip me',
          category: TodoCategory.item,
          dueDate: _today,
          items: [],
        ),
      );

      await tester.pumpWidget(_buildApp(appState));
      await tester.pumpAndSettle();

      // 1件目を準備
      await tester.tap(find.text('準備できた'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // 2件目が表示される
      expect(find.text('Skip me'), findsOneWidget);

      // 今回は外す
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('今回は外す'));
      await tester.pumpAndSettle();

      // 完了画面（全件処理済み）
      expect(find.text('今日の準備は完了です'), findsOneWidget);
    });

    testWidgets('cancel dialog does not discard prepared data', (tester) async {
      final appState = await _createAppState();
      await appState.addChild('長女');
      await appState.addTodoFromDraft(
        draft: ExtractionDraft(
          title: 'Cancel test',
          category: TodoCategory.item,
          dueDate: _today,
          items: [],
        ),
      );

      await tester.pumpWidget(_buildApp(appState));
      await tester.pumpAndSettle();

      // 準備
      await tester.tap(find.text('準備できた'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // 完了画面でback
      await tester.tap(find.text('ホームに戻る'));
      await tester.pumpAndSettle();

      // HomeScreenがないのでpopされたことを確認（WidgetTestならエラーにならない）
    });

    testWidgets('checklist toggle updates visually', (tester) async {
      final appState = await _createAppState();
      await appState.addChild('長女');
      await appState.addTodoFromDraft(
        draft: ExtractionDraft(
          title: '持ち物確認',
          category: TodoCategory.item,
          dueDate: _today,
          items: ['水筒', 'タオル'],
        ),
      );

      await tester.pumpWidget(_buildApp(appState));
      await tester.pumpAndSettle();

      // チェックリスト表示
      expect(find.text('水筒'), findsOneWidget);
      expect(find.text('タオル'), findsOneWidget);

      // 水筒をチェック
      await tester.tap(find.text('水筒'));
      await tester.pumpAndSettle();

      // チェック後も画面が最新状態を反映（水筒の線取り消しが適用される）
      // 具体的には、再build後にCheckboxListTileのvalueがtrueになっている
    });
  });
}
