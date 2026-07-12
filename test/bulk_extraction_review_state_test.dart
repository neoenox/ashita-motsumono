// test/bulk_extraction_review_state_test.dart
// 複数OCR候補で編集済み値と選択状態が保存対象へ反映されることを検証する。

import 'package:ashita_motsumono/src/models/bulk_extraction_review_state.dart';
import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ExtractionDraft draft(String title, List<String> items) => ExtractionDraft(
    title: title,
    category: TodoCategory.item,
    dueDate: DateTime(2026, 7, 20),
    amount: 500,
    items: items,
    note: '元のメモ',
    rawText: 'OCR全文',
  );

  test('editing a candidate replaces the value used for registration', () {
    final state = BulkExtractionReviewState([
      draft('元の候補', ['水筒']),
      draft('二件目', ['体操着']),
    ]);
    final edited = ExtractionDraft(
      title: '編集後の候補',
      category: TodoCategory.submit,
      dueDate: DateTime(2026, 7, 22),
      amount: 900,
      items: const ['上履き', '上履き袋'],
      note: '編集後のメモ',
      rawText: 'OCR全文',
    );

    state.updateDraft(0, edited);

    expect(state.draftAt(0), same(edited));
    expect(state.selectedDrafts.first, same(edited));
    expect(state.selectedDrafts.first.title, '編集後の候補');
    expect(state.selectedDrafts.first.category, TodoCategory.submit);
    expect(state.selectedDrafts.first.dueDate, DateTime(2026, 7, 22));
    expect(state.selectedDrafts.first.amount, 900);
    expect(state.selectedDrafts.first.items, ['上履き', '上履き袋']);
    expect(state.selectedDrafts.first.note, '編集後のメモ');
  });

  test('registration payload contains only selected edited drafts', () {
    final state = BulkExtractionReviewState([
      draft('一件目', ['水筒']),
      draft('二件目', ['体操着']),
    ]);
    state.updateDraft(
      0,
      draft('編集済み一件目', [' 水筒 ', '', '   ', '連絡帳']),
    );
    state.setSelected(1, false);

    expect(state.selectedCount, 1);
    expect(state.selectedDrafts.map((draft) => draft.title), ['編集済み一件目']);
    expect(state.selectedItemLabels, ['水筒', '連絡帳']);
  });

  test('constructor defensively copies the original draft list', () {
    final original = [draft('一件目', ['水筒'])];
    final state = BulkExtractionReviewState(original);

    original.add(draft('後から追加', ['体操着']));

    expect(state.length, 1);
    expect(state.selectedCount, 1);
  });
}
