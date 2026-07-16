import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CrashReporter {
  CrashReporter._();

  static const _maxBytes = 1024 * 1024;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final logFile = File('${dir.path}/crash.log');
    await _rotateIfNeeded(logFile);

    FlutterError.onError = (FlutterErrorDetails details) async {
      FlutterError.presentError(details);
      try {
        await _rotateIfNeeded(logFile);
        await logFile.writeAsString(
          '${DateTime.now().toUtc().toIso8601String()} [FLUTTER] '
          '${details.exceptionAsString()}\n${details.stack ?? StackTrace.empty}\n\n',
          mode: FileMode.append,
        );
      } on Object {
        // Diagnostics must never crash the app.
      }
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      try {
        if (logFile.existsSync() && logFile.lengthSync() > _maxBytes) {
          final previous = File('${logFile.parent.path}/crash.previous.log');
          if (previous.existsSync()) previous.deleteSync();
          logFile.renameSync(previous.path);
        }
        logFile.writeAsStringSync(
          '${DateTime.now().toUtc().toIso8601String()} [DART] '
          '${error.runtimeType}: $error\n$stack\n\n',
          mode: FileMode.append,
        );
      } on Object {
        // Diagnostics must never crash the app.
      }
      return true;
    };
  }

  static Future<void> _rotateIfNeeded(File file) async {
    if (!await file.exists() || await file.length() <= _maxBytes) return;
    final previous = File('${file.parent.path}/crash.previous.log');
    if (await previous.exists()) await previous.delete();
    await file.rename(previous.path);
  }
}
