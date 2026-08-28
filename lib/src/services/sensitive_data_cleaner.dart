import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

typedef DocumentsDirectoryProvider = Future<Directory> Function();

class SensitiveDataCleanupException implements Exception {
  const SensitiveDataCleanupException(this.failures);

  final int failures;

  @override
  String toString() =>
      'Sensitive data cleanup failed for $failures operation(s)';
}

class SensitiveDataCleaner {
  SensitiveDataCleaner({DocumentsDirectoryProvider? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationDocumentsDirectory;

  final DocumentsDirectoryProvider _directoryProvider;

  static final _residualName = RegExp(
    r'^(crash(?:\.previous)?\.log|ashita_motsumono_(?:legacy_backup_.*\.json|corrupt_.*\.db(?:-(?:wal|shm|journal))?))$',
  );
  static const _retryMarkerName = 'ashita_motsumono_cleanup_retry.marker';

  /// 補助ログや退避ファイルを削除する。
  /// 失敗時は再試行マーカーを残し、削除成功を報告する呼び出し元へ通知する。
  Future<void> clearResidualFiles() async {
    var failures = 0;
    Directory? directory;
    try {
      directory = await _directoryProvider();
      for (final entity in directory.listSync()) {
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
    if (failures > 0) {
      await _writeRetryMarker(directory);
      throw SensitiveDataCleanupException(failures);
    }
    await _removeRetryMarker(directory);
  }

  Future<void> _writeRetryMarker(Directory? directory) async {
    if (directory == null) return;
    try {
      await File(
        '${directory.path}/$_retryMarkerName',
      ).writeAsString('retry-required\n', flush: true);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('SensitiveDataCleaner: marker write failed: $error');
      }
    }
  }

  Future<void> _removeRetryMarker(Directory? directory) async {
    if (directory == null) return;
    try {
      final marker = File('${directory.path}/$_retryMarkerName');
      if (await marker.exists()) await marker.delete();
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('SensitiveDataCleaner: marker cleanup failed: $error');
      }
    }
  }
}
