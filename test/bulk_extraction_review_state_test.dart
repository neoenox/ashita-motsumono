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
    state.updateDraft(0, draft('編集済み一件目', [' 水筒 ', '', '   ', '連絡帳']));
    state.setSelected(1, false);

    expect(state.selectedCount, 1);
    expect(state.selectedDrafts.map((draft) => draft.title), ['編集済み一件目']);
    expect(state.selectedItemLabels, ['水筒', '連絡帳']);
  });

  test('constructor defensively copies the original draft list', () {
    final original = [
      draft('一件目', ['水筒']),
    ];
    final state = BulkExtractionReviewState(original);

    original.add(draft('後から追加', ['体操着']));

    expect(state.length, 1);
    expect(state.selectedCount, 1);
  });

  group('selectAll / toggleAll', () {
    test('selectAll(true) selects all drafts', () {
      final state = BulkExtractionReviewState([
        draft('a', []),
        draft('b', []),
        draft('c', []),
      ]);
      state.setSelected(1, false);
      expect(state.selectedCount, 2);

      state.selectAll(true);
      expect(state.selectedCount, 3);
      expect(state.allSelected, true);
    });

    test('selectAll(false) deselects all drafts', () {
      final state = BulkExtractionReviewState([
        draft('a', []),
        draft('b', []),
      ]);
      expect(state.selectedCount, 2);

      state.selectAll(false);
      expect(state.selectedCount, 0);
      expect(state.allSelected, false);
    });

    test('toggleAll switches between all/none', () {
      final state = BulkExtractionReviewState([
        draft('a', []),
        draft('b', []),
        draft('c', []),
      ]);
      expect(state.allSelected, true);

      state.toggleAll();
      expect(state.allSelected, false);
      expect(state.selectedCount, 0);

      state.toggleAll();
      expect(state.allSelected, true);
      expect(state.selectedCount, 3);
    });
  });

  group('removeSelected', () {
    test('removes only selected drafts', () {
      final state = BulkExtractionReviewState([
        draft('a', []),
        draft('b', []),
        draft('c', []),
      ]);
      state.setSelected(1, false);

      state.removeSelected();

      expect(state.length, 1);
      expect(state.draftAt(0).title, 'b');
    });

    test('removing all leaves empty state', () {
      final state = BulkExtractionReviewState([
        draft('only', ['水筒']),
      ]);
      state.removeSelected();
      expect(state.length, 0);
      expect(state.selectedCount, 0);
    });

    test('removing none leaves state unchanged', () {
      final state = BulkExtractionReviewState([
        draft('a', []),
        draft('b', []),
      ]);
      state.selectAll(false);
      state.removeSelected();

      expect(state.length, 2);
      expect(state.draftAt(0).title, 'a');
      expect(state.draftAt(1).title, 'b');
    });
  });

  group('batchReplace', () {
    test('batchReplaceTitle replaces in matching titles', () {
      final state = BulkExtractionReviewState([
        draft('水筒を持参', []),
        draft('体操着を準備', []),
        draft('水筒を補充', []),
      ]);

      final count = state.batchReplaceTitle('水筒', '飲み物');
      expect(count, 2);
      expect(state.draftAt(0).title, '飲み物を持参');
      expect(state.draftAt(1).title, '体操着を準備');
      expect(state.draftAt(2).title, '飲み物を補充');
    });

    test('batchReplaceItems replaces in matching items', () {
      final state = BulkExtractionReviewState([
        draft('a', ['赤い水筒', '青い水筒']),
        draft('b', ['体操着']),
        draft('c', ['水筒カバー']),
      ]);

      final count = state.batchReplaceItems('水筒', 'ボトル');
      expect(count, 2);
      expect(state.draftAt(0).items, ['赤いボトル', '青いボトル']);
      expect(state.draftAt(1).items, ['体操着']);
      expect(state.draftAt(2).items, ['ボトルカバー']);
    });

    test('batchReplace with no match returns 0 and changes nothing', () {
      final state = BulkExtractionReviewState([
        draft('水筒', []),
      ]);

      final count = state.batchReplaceTitle('存在しない', '何か');
      expect(count, 0);
      expect(state.draftAt(0).title, '水筒');
    });
  });
}
