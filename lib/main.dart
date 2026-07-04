// lib/main.dart
// アプリのエントリポイント。Provider で AppState を DI し、MaterialApp を起動する。
// 関連: src/app_state.dart, src/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'src/app_state.dart';
import 'src/repositories/drift_store.dart';
import 'src/screens/home_screen.dart';
import 'src/services/app_settings.dart';
import 'src/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs);
  final store = await DriftStore.create();
  final notifications = NotificationService(settings: settings);
  final appState = AppState(store: store, notifications: notifications);
  await appState.load();
  runApp(AshitaMotsumonoApp(appState: appState, settings: settings));
}

class AshitaMotsumonoApp extends StatelessWidget {
  const AshitaMotsumonoApp({super.key, required this.appState, required this.settings});

  final AppState appState;
  final AppSettings settings;

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
        ),
        home: HomeScreen(settings: settings),
      ),
    );
  }
}
