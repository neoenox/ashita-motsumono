// test/image_file_service_test.dart
// ImageFileService の画像ファイル操作をテストする。
// 関連: lib/src/services/image_file_service.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:ashita_motsumono/src/services/image_file_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageFileService', () {
    test('deleteIfExists does not throw for non-existent file', () async {
      final path = p.join(Directory.current.path, 'non_existent_file.jpg');
      expect(() => ImageFileService.deleteIfExists(path), returnsNormally);
    });

    test('deleteIfExists does not throw for empty path', () async {
      expect(() => ImageFileService.deleteIfExists(''), returnsNormally);
    });

    test('deleteIfExists deletes existing file', () async {
      final file = File(p.join(Directory.current.path, 'test_delete.txt'));
      await file.writeAsString('test');
      expect(await file.exists(), isTrue);

      await ImageFileService.deleteIfExists(file.path);
      expect(await file.exists(), isFalse);
    });
  });
}
