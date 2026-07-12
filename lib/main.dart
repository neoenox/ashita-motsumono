// lib/main.dart
// アプリのエントリポイント。状態領域ごとのProviderを登録してMaterialAppを起動する。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app_state.dart';
import 'src/repositories/drift_store.dart';
import 'src/screens/home_screen.dart';
import 'src/services/ad_service.dart';
import 'src/services/app_settings.dart';
import 'src/services/crash_reporter.dart';
import 'src/services/notification_service.dart';
import 'src/services/purchase_provider.dart';
import 'src/state/app_data_notifiers.dart';
import 'src/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CrashReporter.init();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs);
  final store = await DriftStore.create();
  final notifications = NotificationService(settings: settings);
  final appState = AppState(store: store, notifications: notifications);
  await appState.load();
  unawaited(appState.rescheduleAllNotifications());
  unawaited(AdService.initialize());
  runApp(
    AshitaMotsumonoApp(
      appState: appState,
      settings: settings,
      purchaseProvider: AppPurchaseProvider(settings),
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
        ChangeNotifierProvider<ChildState>.value(value: appState.childState),
        ChangeNotifierProvider<TodoState>.value(value: appState.todoState),
        ChangeNotifierProvider<DocumentState>.value(
          value: appState.documentState,
        ),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: purchaseProvider),
      ],
      builder: (context, _) {
        final currentSettings = context.watch<AppSettings>();
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'あした持つもの',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: currentSettings.themeMode,
          home: HomeScreen(settings: settings),
        );
      },
    );
  }
}
