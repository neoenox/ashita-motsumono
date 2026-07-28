// lib/src/models/bulk_extraction_review_state.dart
// 複数OCR候補の編集済み下書きと選択状態を、画面の入力元から独立して保持する。

import 'extraction_draft.dart';

class BulkExtractionReviewState {
  BulkExtractionReviewState(List<ExtractionDraft> drafts)
    : _drafts = List<ExtractionDraft>.of(drafts),
      _selected = List<bool>.generate(drafts.length, (_) => true);

  final List<ExtractionDraft> _drafts;
  final List<bool> _selected;

  int get length => _drafts.length;

  int get selectedCount => _selected.where((selected) => selected).length;

  bool get allSelected => selectedCount == _drafts.length;

  int get unselectedCount => _drafts.length - selectedCount;

  bool get canBatchFix => _drafts.isNotEmpty && selectedCount > 0;

  String get firstNonEmptyRawText {
    for (final draft in _drafts) {
      final rawText = draft.rawText?.trim();
      if (rawText != null && rawText.isNotEmpty) return rawText;
    }
    return '';
  }

  List<ExtractionDraft> get drafts => List.unmodifiable(_drafts);

  ExtractionDraft draftAt(int index) => _drafts[index];

  bool isSelected(int index) => _selected[index];

  void updateDraft(int index, ExtractionDraft draft) {
    _drafts[index] = draft;
  }

  void setSelected(int index, bool selected) {
    _selected[index] = selected;
  }

  void selectAll(bool selected) {
    for (var index = 0; index < _selected.length; index++) {
      _selected[index] = selected;
    }
  }

  void toggleAll() => selectAll(!allSelected);

  void removeSelected() {
    var writeIndex = 0;
    for (var readIndex = 0; readIndex < _drafts.length; readIndex++) {
      if (!_selected[readIndex]) {
        _drafts[writeIndex] = _drafts[readIndex];
        _selected[writeIndex] = _selected[readIndex];
        writeIndex++;
      }
    }
    _drafts.length = writeIndex;
    _selected.length = writeIndex;
  }

  int batchReplaceTitle(String find, String replace) {
    if (find.isEmpty) return 0;

    var count = 0;
    for (var index = 0; index < _drafts.length; index++) {
      final draft = _drafts[index];
      if (draft.title.contains(find)) {
        _drafts[index] = draft.copyWith(
          title: draft.title.replaceAll(find, replace),
        );
        count++;
      }
    }
    return count;
  }

  int batchReplaceItems(String find, String replace) {
    if (find.isEmpty) return 0;

    var count = 0;
    for (var index = 0; index < _drafts.length; index++) {
      final draft = _drafts[index];
      final newItems = <String>[];
      var changed = false;
      for (final item in draft.items) {
        if (item.contains(find)) {
          newItems.add(item.replaceAll(find, replace));
          changed = true;
        } else {
          newItems.add(item);
        }
      }
      if (changed) {
        _drafts[index] = draft.copyWith(items: newItems);
        count++;
      }
    }
    return count;
  }

  List<ExtractionDraft> get selectedDrafts => [
    for (var index = 0; index < _drafts.length; index++)
      if (_selected[index]) _drafts[index],
  ];

  List<String> get selectedItemLabels => [
    for (final draft in selectedDrafts)
      for (final item in draft.items)
        if (item.trim().isNotEmpty) item.trim(),
  ];
}
