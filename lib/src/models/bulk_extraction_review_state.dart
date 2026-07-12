// lib/src/models/bulk_extraction_review_state.dart
// 複数OCR候補の編集済み下書きと選択状態を、画面の入力元から独立して保持する。

import 'extraction_draft.dart';

class BulkExtractionReviewState {
  BulkExtractionReviewState(List<ExtractionDraft> drafts)
    : _drafts = List<ExtractionDraft>.of(drafts),
      _selected = List<bool>.filled(drafts.length, true);

  final List<ExtractionDraft> _drafts;
  final List<bool> _selected;

  int get length => _drafts.length;

  int get selectedCount => _selected.where((selected) => selected).length;

  List<ExtractionDraft> get drafts => List.unmodifiable(_drafts);

  ExtractionDraft draftAt(int index) => _drafts[index];

  bool isSelected(int index) => _selected[index];

  void updateDraft(int index, ExtractionDraft draft) {
    _drafts[index] = draft;
  }

  void setSelected(int index, bool selected) {
    _selected[index] = selected;
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
