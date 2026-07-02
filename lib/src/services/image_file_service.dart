// lib/src/services/image_file_service.dart
// 撮影または選択した画像ファイルをアプリのドキュメントディレクトリにコピーする。
// 元ファイルが一時領域にある場合があるため、確実に保持するためにコピーする。
// Web 版では path_provider が未実装のため、元ファイルをそのまま返す。
// 関連: services/ocr_service.dart, screens/add_todo_screen.dart

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageFileService {
  ImageFileService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  Future<File> copyIntoAppDirectory(File source) async {
    if (kIsWeb) {
      return source;
    }
    final dir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(p.join(dir.path, 'document_images'));
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    final extension = p.extension(source.path).isEmpty ? '.jpg' : p.extension(source.path);
    final dest = File(p.join(imageDir.path, '${_uuid.v4()}$extension'));
    return source.copy(dest.path);
  }
}
