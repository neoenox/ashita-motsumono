// test/image_intake_selection_state_test.dart
// 複数画像の並べ替え・除外状態を検証する。

import 'package:ashita_motsumono/src/models/image_intake_selection_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test('reorders selected images using ReorderableListView semantics', () {
    final state = ImageIntakeSelectionState([
      XFile('/tmp/page-a.jpg'),
      XFile('/tmp/page-b.jpg'),
      XFile('/tmp/page-c.jpg'),
    ]);

    state.reorder(0, 2);

    expect(state.files.map((file) => file.path), [
      '/tmp/page-b.jpg',
      '/tmp/page-c.jpg',
      '/tmp/page-a.jpg',
    ]);
  });

  test(
    'removes excluded image without mutating the original order of others',
    () {
      final state = ImageIntakeSelectionState([
        XFile('/tmp/page-a.jpg'),
        XFile('/tmp/page-b.jpg'),
        XFile('/tmp/page-c.jpg'),
      ]);

      final removed = state.removeAt(1);

      expect(removed.file.path, '/tmp/page-b.jpg');
      expect(state.files.map((file) => file.path), [
        '/tmp/page-a.jpg',
        '/tmp/page-c.jpg',
      ]);
    },
  );

  test('allows all images to be excluded', () {
    final state = ImageIntakeSelectionState([XFile('/tmp/page-a.jpg')]);

    state.removeAt(0);

    expect(state.isEmpty, isTrue);
    expect(state.files, isEmpty);
  });
}
