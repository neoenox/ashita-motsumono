// lib/src/services/document_image_cleaner.dart
// ドキュメント画像ファイルの削除を担当する。

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/entities.dart';
import 'image_file_service.dart';
import 'sensitive_data_cleaner.dart' show DocumentsDirectoryProvider;

class DocumentImageCleaner {
  DocumentImageCleaner({DocumentsDirectoryProvider? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationDocumentsDirectory;

  final DocumentsDirectoryProvider _directoryProvider;

  Iterable<String> pathsFor(Iterable<DocumentRecord> documents) sync* {
    for (final document in documents) {
      final path = document.localImagePath;
      if (path != null && path.isNotEmpty) {
        yield path;
      }
      for (final page in document.pages) {
        yield page.localImagePath;
      }
    }
  }

  Future<Directory> resolveImagesDirectory() async {
    final dir = await _directoryProvider();
    return Directory(p.join(dir.path, 'document_images'));
  }

  /// DBから参照されなくなった画像ファイルを一括削除する。
  /// 起動時の整合性回復用で、個別削除の失敗は握り潰して続行する。
  Future<void> deleteOrphans({
    required Directory directory,
    required Set<String> referencedPaths,
  }) async {
    if (!await directory.exists()) return;
    final referenced = referencedPaths.map(_canonicalize).toSet();
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      if (referenced.contains(_canonicalize(entity.path))) continue;
      try {
        await entity.delete();
      } on Object catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint(
            'DocumentImageCleaner: failed to delete orphan image: '
            '$error\n$stackTrace',
          );
        }
      }
    }
  }

  Future<void> deletePath(String path) {
    return ImageFileService.deleteIfExistsStrict(path);
  }

  Future<void> deletePaths(Iterable<String> paths) async {
    await Future.wait(
      paths
          .where((path) => path.isNotEmpty)
          .toSet()
          .map(ImageFileService.deleteIfExistsStrict),
    );
  }

  Future<void> deleteAll(Iterable<DocumentRecord> documents) {
    return deletePaths(pathsFor(documents));
  }

  String _canonicalize(String path) {
    return p.normalize(path).replaceAll(r'\', '/').toLowerCase();
  }
}
