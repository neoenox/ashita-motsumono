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

  /// 補助ログや退避ファイルを可能な範囲で削除する。
  /// 主データ削除が完了した後の後処理なので、プラグイン未初期化やI/O障害を
  /// 呼び出し元へ再送出して削除済み状態を失敗扱いにはしない。
  Future<void> clearResidualFiles() async {
    var failures = 0;
    try {
      final directory = await _directoryProvider();
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
    } on Object catch (error, stackTrace) {
      failures++;
      if (kDebugMode) {
        debugPrint(
          'SensitiveDataCleaner: residual cleanup could not be started: '
          '$error\n$stackTrace',
        );
      }
    }
    if (failures > 0 && kDebugMode) {
      debugPrint('SensitiveDataCleaner: $failures cleanup operations failed');
    }
  }
}
