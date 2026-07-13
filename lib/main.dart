// lib/main.dart
// 公開名称「あしたもつもの」のエントリポイント。
// 初期化失敗をUIで復旧できるBootstrapAppを起動する。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/bootstrap_app.dart';
import 'src/services/crash_reporter.dart';

export 'src/bootstrap_app.dart' show AshitaMotsumonoApp, BootstrapApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await CrashReporter.init();
  } on Object catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('CrashReporter initialization failed: $error\n$stackTrace');
    }
  }
  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } on Object catch (error) {
    if (kDebugMode) debugPrint('System UI initialization failed: $error');
  }
  runApp(const BootstrapApp());
}
