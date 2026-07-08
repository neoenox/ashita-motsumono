// lib/src/services/crash_reporter.dart
// エラーを端末内ログファイルに記録する。
// クラウド送信なし。マニュアルエクスポートで確認可能。
// 関連: main.dart, app_settings.dart

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CrashReporter {
  CrashReporter._();

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final logFile = File('${dir.path}/crash.log');

    FlutterError.onError = (FlutterErrorDetails details) async {
      FlutterError.presentError(details);
      await _write(logFile, details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _writeSync(logFile, error, stack);
      return true;
    };
  }

  static Future<void> _write(File file, FlutterErrorDetails details) async {
    try {
      await file.writeAsString(
        '${DateTime.now()} [FLUTTER] ${details.exception}\n${details.stack}\n\n',
        mode: FileMode.append,
      );
    } catch (_) {}
  }

  static void _writeSync(File file, Object error, StackTrace stack) {
    try {
      file.writeAsStringSync(
        '${DateTime.now()} [DART] $error\n$stack\n\n',
        mode: FileMode.append,
      );
    } catch (_) {}
  }
}
