// test/widget_test.dart
// アプリ起動直後の最低限のスモークテスト。

import 'package:ashita_motsumono/main.dart';
import 'package:ashita_motsumono/src/app_state.dart';
import 'package:ashita_motsumono/src/repositories/local_store.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows home screen and first run card', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.create();
    final appState = AppState(
      store: store,
      notifications: NotificationService(),
    );
    await appState.load();

    await tester.pumpWidget(AshitaMotsumonoApp(appState: appState));
    await tester.pumpAndSettle();

    expect(find.text('あした持つもの'), findsOneWidget);
    expect(find.text('まず子どもを登録'), findsOneWidget);
    expect(find.text('Todoは子ども別に整理できます。MVPではログインなし・端末内保存です。'), findsOneWidget);
  });
}
