// lib/src/bootstrap_app.dart
// アプリ起動時の依存初期化、DB復旧境界、ルートProviderを管理する。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'repositories/drift_store.dart';
import 'repositories/store.dart';
import 'screens/home_screen_scope.dart';
import 'services/ad_service.dart';
import 'services/app_settings.dart';
import 'services/notification_service.dart';
import 'services/purchase_provider.dart';
import 'state/app_data_notifiers.dart';
import 'theme/app_theme.dart';

enum _BootstrapPhase { loading, ready, recoverableFailure, fatalFailure }

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  _BootstrapPhase _phase = _BootstrapPhase.loading;
  AppSettings? _settings;
  DriftStore? _store;
  AppState? _appState;
  PurchaseProvider? _purchaseProvider;
  StoreLoadException? _loadFailure;
  Object? _fatalError;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeFresh());
  }

  Future<void> _initializeFresh() async {
    if (_working) return;
    _working = true;
    if (mounted) {
      setState(() {
        _phase = _BootstrapPhase.loading;
        _fatalError = null;
        _loadFailure = null;
      });
    }

    AppState? createdState;
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = AppSettings(prefs);
      final store = await DriftStore.create();
      final notifications = NotificationService(
        settings: settings,
        notificationIds: store,
      );
      createdState = AppState(store: store, notifications: notifications);

      _settings = settings;
      _store = store;
      _appState = createdState;
      _purchaseProvider = AppPurchaseProvider(settings);

      await createdState.load();
      _markReady();
    } on StoreLoadException catch (error) {
      _loadFailure = error;
      if (mounted) {
        setState(() => _phase = _BootstrapPhase.recoverableFailure);
      }
    } on Object catch (error, stackTrace) {
      createdState?.dispose();
      _appState = null;
      _store = null;
      _settings = null;
      _purchaseProvider = null;
      _fatalError = error;
      if (kDebugMode) {
        debugPrint('Application bootstrap failed: $error\n$stackTrace');
      }
      if (mounted) {
        setState(() => _phase = _BootstrapPhase.fatalFailure);
      }
    } finally {
      _working = false;
    }
  }

  Future<void> _retryLoad() async {
    if (_working) return;
    final appState = _appState;
    if (appState == null) {
      await _initializeFresh();
      return;
    }

    _working = true;
    setState(() => _phase = _BootstrapPhase.loading);
    try {
      await appState.load();
      _markReady();
    } on StoreLoadException catch (error) {
      _loadFailure = error;
      if (mounted) {
        setState(() => _phase = _BootstrapPhase.recoverableFailure);
      }
    } on Object catch (error, stackTrace) {
      _fatalError = error;
      if (kDebugMode) {
        debugPrint('Database retry failed: $error\n$stackTrace');
      }
      if (mounted) {
        setState(() => _phase = _BootstrapPhase.fatalFailure);
      }
    } finally {
      _working = false;
    }
  }

  Future<void> _resetLocalDatabase() async {
    if (_working) return;
    final store = _store;
    final appState = _appState;
    if (store == null || appState == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('端末内データを初期化しますか？'),
        content: const Text(
          '退避コピーは残りますが、アプリが使用する現在のデータベースは新しく作り直されます。'
          'この操作は元に戻せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('初期化する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _working = true;
    setState(() => _phase = _BootstrapPhase.loading);
    try {
      await store.resetAfterLoadFailure();
      await appState.load();
      _markReady();
    } on Object catch (error, stackTrace) {
      _fatalError = error;
      if (kDebugMode) {
        debugPrint('Database reset failed: $error\n$stackTrace');
      }
      if (mounted) {
        setState(() => _phase = _BootstrapPhase.fatalFailure);
      }
    } finally {
      _working = false;
    }
  }

  void _markReady() {
    final appState = _appState;
    if (appState == null || !mounted) return;
    setState(() {
      _phase = _BootstrapPhase.ready;
      _loadFailure = null;
      _fatalError = null;
    });
    unawaited(appState.rescheduleAllNotifications());
    unawaited(AdService.initialize());
  }

  @override
  void dispose() {
    _appState?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _BootstrapPhase.ready) {
      return AshitaMotsumonoApp(
        appState: _appState!,
        settings: _settings!,
        purchaseProvider: _purchaseProvider!,
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'あしたもつもの',
      home: switch (_phase) {
        _BootstrapPhase.loading => const _BootstrapLoadingScreen(),
        _BootstrapPhase.recoverableFailure => _DatabaseRecoveryScreen(
            backupInfo:
                _loadFailure?.backupInfo ?? _store?.loadCorruptBackup(),
            onRetry: _retryLoad,
            onReset: _resetLocalDatabase,
          ),
        _BootstrapPhase.fatalFailure => _BootstrapFailureScreen(
            error: _fatalError,
            onRetry: () async {
              _appState?.dispose();
              _appState = null;
              _store = null;
              _settings = null;
              _purchaseProvider = null;
              await _initializeFresh();
            },
          ),
        _BootstrapPhase.ready => const SizedBox.shrink(),
      },
    );
  }
}

class _BootstrapLoadingScreen extends StatelessWidget {
  const _BootstrapLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('端末内データを確認しています…'),
          ],
        ),
      ),
    );
  }
}

class _DatabaseRecoveryScreen extends StatelessWidget {
  const _DatabaseRecoveryScreen({
    required this.backupInfo,
    required this.onRetry,
    required this.onReset,
  });

  final String? backupInfo;
  final Future<void> Function() onRetry;
  final Future<void> Function() onReset;

  @override
  Widget build(BuildContext context) {
    final details = backupInfo?.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('データを安全に復旧')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.warning_amber_rounded, size: 56),
            const SizedBox(height: 16),
            Text(
              '保存データを読み込めなかったため、通常操作を停止しました。',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'この状態ではデータを上書きしません。まず再試行し、改善しない場合のみ端末内データの初期化を選んでください。',
            ),
            if (details != null && details.isNotEmpty) ...[
              const SizedBox(height: 20),
              SelectableText(details),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: details));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('退避情報をコピーしました')),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('退避情報をコピー'),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('読み込みを再試行'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('端末内データを初期化'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BootstrapFailureScreen extends StatelessWidget {
  const _BootstrapFailureScreen({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56),
                const SizedBox(height: 16),
                Text(
                  'アプリを開始できませんでした。',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (kDebugMode && error != null) SelectableText('$error'),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('再試行'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
          title: 'あしたもつもの',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: currentSettings.themeMode,
          home: HomeScreenScope(settings: settings),
        );
      },
    );
  }
}
