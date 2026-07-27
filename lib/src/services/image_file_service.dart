import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageFileService {
  ImageFileService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  static const maxImageBytes = 5 * 1024 * 1024;

  final Uuid _uuid;

  Future<File> copyFromXFile(XFile source) async {
    final sourceLength = await source.length();
    if (sourceLength <= 0) throw StateError('画像ファイルが空です。');
    if (sourceLength > maxImageBytes) {
      throw StateError('画像サイズが5MBを超えています。');
    }
    final imageDir = await _documentImagesDirectory();
    final rawExtension = p.extension(source.path).toLowerCase();
    final extension = _normalizedExtension(rawExtension);
    final dest = File(p.join(imageDir.path, '${_uuid.v4()}$extension'));
    final bytes = await source.readAsBytes();
    if (bytes.isEmpty) throw StateError('画像ファイルが空です。');
    if (bytes.length > maxImageBytes) {
      throw StateError('画像サイズが5MBを超えています。');
    }
    await dest.writeAsBytes(bytes, flush: true);
    return dest;
  }

  Future<File> copyFromPath(
    String sourcePath, {
    Directory? destinationDirectory,
  }) async {
    final imageDir = destinationDirectory ?? await _documentImagesDirectory();
    await imageDir.create(recursive: true);
    final extension = _normalizedExtension(
      p.extension(sourcePath).toLowerCase(),
    );
    final dest = File(p.join(imageDir.path, '${_uuid.v4()}$extension'));

    if (sourcePath.startsWith('content://')) {
      final xFile = XFile(sourcePath);
      final bytes = await xFile.readAsBytes();
      if (bytes.isEmpty) throw StateError('画像ファイルが空です。');
      if (bytes.length > maxImageBytes) {
        throw StateError('画像サイズが5MBを超えています。');
      }
      await dest.writeAsBytes(bytes, flush: true);
      return dest;
    }

    final source = File(sourcePath);
    final sourceLength = await source.length();
    if (sourceLength <= 0) throw StateError('画像ファイルが空です。');
    if (sourceLength > maxImageBytes) {
      throw StateError('画像サイズが5MBを超えています。');
    }
    await source.copy(dest.path);
    return dest;
  }

  Future<Directory> _documentImagesDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(p.join(dir.path, 'document_images'));
    await imageDir.create(recursive: true);
    return imageDir;
  }

  String _normalizedExtension(String rawExtension) {
    return switch (rawExtension) {
      '.png' || '.jpg' || '.jpeg' || '.webp' => rawExtension,
      _ => '.jpg',
    };
  }

  static Future<void> deleteIfExistsStrict(String path) async {
    if (path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  static Future<void> deleteIfExists(String path) async {
    try {
      await deleteIfExistsStrict(path);
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'ImageFileService: failed to delete file: $error\n$stackTrace',
        );
      }
    }
  }
}
