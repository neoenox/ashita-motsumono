// lib/src/services/image_file_service.dart
// 撮影または選択した画像ファイルをアプリのドキュメントディレクトリにコピーする。
// 元ファイルが一時領域や content:// URI の場合があるため、確実に保持するために読み取りコピーする。
// このMVPは Android/iOS 専用。
// 関連: services/ocr_service.dart, screens/add_todo_screen.dart

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageFileService {
  ImageFileService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  Future<File> copyIntoAppDirectory(File source) async {
    final dir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(p.join(dir.path, 'document_images'));
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    final extension = p.extension(source.path).isEmpty ? '.jpg' : p.extension(source.path);
    final dest = File(p.join(imageDir.path, '${_uuid.v4()}$extension'));
    // content:// URI など File.copy が使えないケースに対応するため読み取りコピー
    try {
      return await source.copy(dest.path);
    } on FileSystemException {
      // content:// URI の場合など、copy が失敗したら読み取り→書き込みで対処
      final bytes = await source.readAsBytes();
      await dest.writeAsBytes(bytes);
      return dest;
    }
  }

  static Future<void> deleteIfExists(String path) async {
    if (path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
