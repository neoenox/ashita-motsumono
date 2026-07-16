import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class SensitiveDataCleaner {
  const SensitiveDataCleaner._();

  static final _residualName = RegExp(
    r'^(crash(?:\.previous)?\.log|ashita_motsumono_(?:legacy_backup_.*\.json|corrupt_.*\.db))$',
  );

  static Future<void> clearResidualFiles() async {
    final directory = await getApplicationDocumentsDirectory();
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
