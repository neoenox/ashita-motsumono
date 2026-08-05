// lib/src/models/image_intake_selection_state.dart
// 複数画像取り込み前の並び順と除外状態を、画面から独立して保持する。

import 'package:image_picker/image_picker.dart';

class ImageIntakePage {
  const ImageIntakePage({
    required this.id,
    required this.file,
    required this.originalIndex,
  });

  final String id;
  final XFile file;
  final int originalIndex;
}

class ImageIntakeSelectionState {
  ImageIntakeSelectionState(List<XFile> files)
    : _pages = [
        for (var index = 0; index < files.length; index++)
          ImageIntakePage(
            id: 'image-page-$index',
            file: files[index],
            originalIndex: index,
          ),
      ];

  final List<ImageIntakePage> _pages;

  int get length => _pages.length;

  bool get isEmpty => _pages.isEmpty;

  List<ImageIntakePage> get pages => List.unmodifiable(_pages);

  List<XFile> get files => [for (final page in _pages) page.file];

  ImageIntakePage pageAt(int index) => _pages[index];

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _pages.length) {
      throw RangeError.index(oldIndex, _pages, 'oldIndex');
    }
    if (newIndex < 0 || newIndex > _pages.length) {
      throw RangeError.range(newIndex, 0, _pages.length, 'newIndex');
    }

    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex == oldIndex) return;

    final page = _pages.removeAt(oldIndex);
    _pages.insert(newIndex, page);
  }

  ImageIntakePage removeAt(int index) {
    return _pages.removeAt(index);
  }
}
