import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

typedef DocumentsDirectoryProvider = Future<Directory> Function();

class SensitiveDataCleaner {
  SensitiveDataCleaner({DocumentsDirectoryProvider? directoryProvider})
      : _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory;

  final DocumentsDirectoryProvider _directoryProvider;

  static final _residualName = RegExp(
    r'^(crash(?:\.previous)?\.log|ashita_motsumono_(?:legacy_backup_.*\.json|corrupt_.*\.db))$',
  );

  Future<void> clearResidualFiles() async {
    final directory = await _directoryProvider();
    var failures = 0;
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!_residualName.hasMatch(name)) continue;
      try {
        await entity.delete();
      } on Object {
        failures++;
      }
    }
    if (failures > 0 && kDebugMode) {
      debugPrint('SensitiveDataCleaner: $failures files could not be removed');
    }
  }
}
