// lib/src/services/image_file_service.dart
// 撮影または選択した画像ファイルをアプリのドキュメントディレクトリにコピーする。
// image_picker が返す XFile (content:// URI の場合がある) を読み取り、ローカルファイルに保存する。
// このMVPは Android/iOS 専用。
// 関連: services/ocr_service.dart, screens/add_todo_screen.dart

import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageFileService {
  ImageFileService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  Future<File> copyFromXFile(XFile source) async {
    final dir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(p.join(dir.path, 'document_images'));
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    final extension = p.extension(source.path).isEmpty ? '.jpg' : p.extension(source.path);
    final dest = File(p.join(imageDir.path, '${_uuid.v4()}$extension'));
    final bytes = await source.readAsBytes();
    await dest.writeAsBytes(bytes);
    return dest;
  }

  static Future<void> deleteIfExists(String path) async {
    if (path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } on Object {
      // 削除に失敗しても呼び出し元に影響させない
    }
  }
}
