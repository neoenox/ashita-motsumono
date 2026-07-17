import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CrashReporter {
  CrashReporter._();

  static const _maxBytes = 1024 * 1024;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final logFile = File('${dir.path}/crash.log');
    _rotateIfNeededSync(logFile);

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      try {
        _rotateIfNeededSync(logFile);
        logFile.writeAsStringSync(
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
        _rotateIfNeededSync(logFile);
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

  static void _rotateIfNeededSync(File file) {
    if (!file.existsSync() || file.lengthSync() <= _maxBytes) return;
    final previous = File('${file.parent.path}/crash.previous.log');
    if (previous.existsSync()) previous.deleteSync();
    file.renameSync(previous.path);
  }
}
