// lib/src/services/document_image_cleaner.dart
// ドキュメント画像ファイルの削除と失敗隔離を担当する。

import 'package:flutter/foundation.dart';

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
          .map(
            (path) => ImageFileService.deleteIfExists(path).catchError((_) {
              if (kDebugMode) {
                debugPrint('DocumentImageCleaner: failed to delete image');
              }
            }),
          ),
    );
  }
}
