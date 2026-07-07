// lib/main.dart
// アプリのエントリポイント。Provider で AppState と PurchaseProvider を DI し、MaterialApp を起動する。
// 関連: src/app_state.dart, src/screens/home_screen.dart, src/services/purchase_provider.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'src/app_state.dart';
import 'src/theme/app_theme.dart';
import 'src/repositories/drift_store.dart';
import 'src/screens/home_screen.dart';
import 'src/services/ad_service.dart';
import 'src/services/app_settings.dart';
import 'src/services/notification_service.dart';
import 'src/services/purchase_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs);
  final store = await DriftStore.create();
  final notifications = NotificationService(settings: settings);
  final appState = AppState(store: store, notifications: notifications);
  await appState.load();
  unawaited(AdService.initialize());
  runApp(
    AshitaMotsumonoApp(
      appState: appState,
      settings: settings,
      purchaseProvider: PurchaseProvider(settings),
    ),
  );
}

class AshitaMotsumonoApp extends StatelessWidget {
  const AshitaMotsumonoApp({
    super.key,
    required this.appState,
    required this.settings,
    required this.purchaseProvider,
  });

  final AppState appState;
  final AppSettings settings;
  final PurchaseProvider purchaseProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        Provider.value(value: settings),
        ChangeNotifierProvider.value(value: purchaseProvider),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'あした持つもの',
        theme: AppTheme.light(),
        home: HomeScreen(settings: settings),
      ),
    );
  }
}
