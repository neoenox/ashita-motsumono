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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ashita_motsumono/src/screens/todo_detail_screen.dart';

/// 現在のモック SharedPreferences から AppSettings を生成する。
Future<AppSettings> _createSettings() async {
  final prefs = await SharedPreferences.getInstance();
  return AppSettings(prefs);
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

      await tester.pumpWidget(AshitaMotsumonoApp(appState: appState, settings: settings));
      await tester.pumpAndSettle();

      expect(find.text('あした持つもの'), findsOneWidget);
      expect(find.text('まず子どもを登録'), findsOneWidget);
      expect(
        find.text('Todoは子ども別に整理できます。MVPではログインなし・端末内保存です。'),
        findsOneWidget,
      );
    });

    testWidgets('shows empty state when children exist but no todos', (tester) async {
      final appState = await _createAppState();
      final settings = await _createSettings();
      await appState.addChild('長女');

      await tester.pumpWidget(AshitaMotsumonoApp(appState: appState, settings: settings));
      await tester.pumpAndSettle();

      expect(find.text('まず子どもを登録'), findsNothing);
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

      await tester.pumpWidget(AshitaMotsumonoApp(appState: appState, settings: settings));
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
      await tester.pumpWidget(AshitaMotsumonoApp(appState: appState, settings: settings));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.child_care));
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
      await tester.pumpWidget(AshitaMotsumonoApp(appState: appState, settings: settings));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.child_care));
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

      await tester.pumpWidget(AshitaMotsumonoApp(appState: appState, settings: settings));
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
      await tester.pumpWidget(AshitaMotsumonoApp(appState: appState, settings: settings));
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
}
