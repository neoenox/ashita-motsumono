// lib/src/services/document_image_cleaner.dart
// ドキュメント画像ファイルの削除を担当する。

import '../models/entities.dart';
import 'image_file_service.dart';

class DocumentImageCleaner {
  const DocumentImageCleaner();

  Iterable<String> pathsFor(Iterable<DocumentRecord> documents) sync* {
    for (final document in documents) {
      final path = document.localImagePath;
      if (path != null && path.isNotEmpty) {
        yield path;
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
}
