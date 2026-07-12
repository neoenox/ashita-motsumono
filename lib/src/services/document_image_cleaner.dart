// lib/src/services/document_image_cleaner.dart
// ドキュメント画像ファイルの削除を担当する。

import '../models/entities.dart';
import 'image_file_service.dart';

class DocumentImageCleaner {
  const DocumentImageCleaner();

  Future<void> deleteAll(Iterable<DocumentRecord> documents) async {
    await Future.wait(
      documents
          .map((document) => document.localImagePath)
          .whereType<String>()
          .where((path) => path.isNotEmpty)
          .map(ImageFileService.deleteIfExists),
    );
  }
}
