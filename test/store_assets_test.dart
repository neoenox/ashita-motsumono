// test/store_assets_test.dart
// Google Play提出用ストア画像が生成済みであることを検証する。
// 関連: tool/generate_store_screenshots.py, assets/store/

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('store icon and screenshots are present as PNG assets', () {
    final files = [
      File('assets/store/icon-512.png'),
      File('assets/store/screenshots/01-home.png'),
      File('assets/store/screenshots/02-add-todo.png'),
      File('assets/store/screenshots/03-review-candidates.png'),
      File('assets/store/screenshots/04-todo-detail.png'),
      File('assets/store/screenshots/05-settings-supporter.png'),
    ];

    for (final file in files) {
      expect(file.existsSync(), isTrue, reason: file.path);
      expect(file.lengthSync(), greaterThan(10000), reason: file.path);
      final header = file.openSync().readSync(8);
      expect(header, [137, 80, 78, 71, 13, 10, 26, 10], reason: file.path);
    }
  });
}
