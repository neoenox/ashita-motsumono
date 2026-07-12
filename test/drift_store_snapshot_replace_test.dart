// test/drift_store_snapshot_replace_test.dart
// DriftStore.saveが既存行を完全に置換し、孤立データを残さないことを検証する。

import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/repositories/drift_store.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final now = DateTime(2026, 7, 12, 12);

  PersonProfile child(String id, String name) => PersonProfile(
    id: id,
    name: name,
    colorValue: 0xff123456,
    createdAt: now,
    updatedAt: now,
  );

  DocumentRecord document(String id) => DocumentRecord(
    id: id,
    sourceType: 'paste',
    localImagePath: '/tmp/$id.png',
    ocrText: 'OCR $id',
    createdAt: now,
    updatedAt: now,
  );

  AppTodo todo({
    required String id,
    required String childId,
    required String documentId,
    required List<ChecklistItem> items,
  }) => AppTodo(
    id: id,
    title: 'Todo $id',
    personId: childId,
    documentId: documentId,
    dueDate: DateTime(2026, 7, 20),
    category: TodoCategory.item,
    amount: 500,
    note: 'note $id',
    status: TodoStatus.open,
    items: items,
    notifyPreviousNight: true,
    notifySameMorning: false,
    createdAt: now,
    updatedAt: now,
  );

  test('second save completely replaces previous children, todos, items and documents', () async {
    final store = await DriftStore.createInMemory();
    final first = AppSnapshot(
      children: [child('child-old', '旧データ')],
      documents: [document('doc-old')],
      todos: [
        todo(
          id: 'todo-old',
          childId: 'child-old',
          documentId: 'doc-old',
          items: const [
            ChecklistItem(id: 'item-old-1', label: '水筒'),
            ChecklistItem(id: 'item-old-2', label: '体操着'),
          ],
        ),
      ],
    );
    await store.save(first);

    final replacement = AppSnapshot(
      children: [child('child-new', '新データ')],
      documents: [document('doc-new')],
      todos: [
        todo(
          id: 'todo-new',
          childId: 'child-new',
          documentId: 'doc-new',
          items: const [
            ChecklistItem(id: 'item-new', label: '上履き袋', isChecked: true),
          ],
        ),
      ],
    );
    await store.save(replacement);

    final loaded = await store.load();
    expect(loaded.children.map((value) => value.id), ['child-new']);
    expect(loaded.documents.map((value) => value.id), ['doc-new']);
    expect(loaded.todos.map((value) => value.id), ['todo-new']);
    expect(loaded.todos.single.items.map((value) => value.id), ['item-new']);
    expect(loaded.todos.single.items.single.isChecked, isTrue);
  });

  test('saving an empty snapshot clears every table', () async {
    final store = await DriftStore.createInMemory();
    await store.save(
      AppSnapshot(
        children: [child('child', '子ども')],
        documents: [document('doc')],
        todos: [
          todo(
            id: 'todo',
            childId: 'child',
            documentId: 'doc',
            items: const [ChecklistItem(id: 'item', label: '水筒')],
          ),
        ],
      ),
    );

    await store.save(AppSnapshot.empty);

    final loaded = await store.load();
    expect(loaded.children, isEmpty);
    expect(loaded.todos, isEmpty);
    expect(loaded.documents, isEmpty);
  });
}
