// test/todo_factory_test.dart
// TodoFactoryが下書き正規化と一括生成を担当することを検証する。

import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/services/todo_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  final factory = TodoFactory(const Uuid());
  final now = DateTime(2026, 7, 12, 12);

  test('normalizes title and checklist labels', () {
    final todo = factory.fromDraft(
      draft: ExtractionDraft(
        title: '   ',
        category: TodoCategory.item,
        dueDate: DateTime(2026, 7, 20),
        amount: 500,
        items: const [' 水筒 ', '', '   ', '連絡帳'],
        note: 'メモ',
        rawText: 'OCR',
      ),
      personId: 'child',
      documentId: 'document',
      notifyPreviousNight: false,
      notifySameMorning: true,
      now: now,
    );

    expect(todo.title, 'プリントを確認');
    expect(todo.items.map((item) => item.label), ['水筒', '連絡帳']);
    expect(todo.personId, 'child');
    expect(todo.documentId, 'document');
    expect(todo.notifyPreviousNight, isFalse);
    expect(todo.notifySameMorning, isTrue);
    expect(todo.createdAt, now);
    expect(todo.updatedAt, now);
  });

  test('batch creation shares one timestamp and creates independent ids', () {
    final todos = factory.fromDrafts(
      drafts: [
        const ExtractionDraft(
          title: '一件目',
          category: TodoCategory.item,
          items: ['水筒'],
          rawText: 'OCR1',
        ),
        const ExtractionDraft(
          title: '二件目',
          category: TodoCategory.submit,
          items: ['申込書'],
          rawText: 'OCR2',
        ),
      ],
      now: now,
    );

    expect(todos, hasLength(2));
    expect(todos.map((todo) => todo.createdAt).toSet(), {now});
    expect(todos.map((todo) => todo.id).toSet(), hasLength(2));
    expect(
      todos.expand((todo) => todo.items).map((item) => item.id).toSet(),
      hasLength(2),
    );
  });
}
