// lib/main.dart
// アプリのエントリポイント。Provider で AppState を DI し、MaterialApp を起動する。
// 関連: src/app_state.dart, src/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app_state.dart';
import 'src/repositories/local_store.dart';
import 'src/screens/home_screen.dart';
import 'src/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalStore.create();
  final notifications = NotificationService();
  final appState = AppState(store: store, notifications: notifications);
  await appState.load();
  runApp(AshitaMotsumonoApp(appState: appState));
}

class AshitaMotsumonoApp extends StatelessWidget {
  const AshitaMotsumonoApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'あした持つもの',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F7D6E)),
          useMaterial3: true,
          fontFamily: 'Noto Sans JP',
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
