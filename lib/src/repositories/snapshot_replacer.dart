// lib/src/repositories/snapshot_replacer.dart
// AppSnapshotを全行読み込みなしでトランザクション内bulk replaceする。

import 'package:drift/drift.dart';

import '../models/entities.dart';
import 'app_database.dart';

class SnapshotReplacer {
  const SnapshotReplacer(this._db);

  final AppDatabase _db;

  Future<void> replace(AppSnapshot snapshot) async {
    await _db.transaction(() async {
      await _db.batch((batch) {
        // 参照元から先に消す。現在はFKを無効化しているが、順序を安全側に固定する。
        batch.deleteAll(_db.dbChecklistItem);
        batch.deleteAll(_db.dbTodo);
        batch.deleteAll(_db.dbChild);
        batch.deleteAll(_db.dbDocument);

        for (final child in snapshot.children) {
          batch.insert(_db.dbChild, _childCompanion(child));
        }
        for (final document in snapshot.documents) {
          batch.insert(_db.dbDocument, _documentCompanion(document));
        }
        for (final todo in snapshot.todos) {
          batch.insert(_db.dbTodo, _todoCompanion(todo));
          for (final item in todo.items) {
            batch.insert(
              _db.dbChecklistItem,
              _checklistCompanion(todo.id, item),
            );
          }
        }
      });
    });
  }

  DbChildCompanion _childCompanion(PersonProfile child) => DbChildCompanion(
    id: Value(child.id),
    name: Value(child.name),
    colorValue: Value(child.colorValue),
    createdAt: Value(child.createdAt),
    updatedAt: Value(child.updatedAt),
  );

  DbTodoCompanion _todoCompanion(AppTodo todo) => DbTodoCompanion(
    id: Value(todo.id),
    title: Value(todo.title),
    childId: Value(todo.personId),
    documentId: Value(todo.documentId),
    dueDate: Value(todo.dueDate),
    category: Value(todo.category.name),
    amount: Value(todo.amount),
    note: Value(todo.note),
    status: Value(todo.status.name),
    notifyPreviousNight: Value(todo.notifyPreviousNight),
    notifySameMorning: Value(todo.notifySameMorning),
    createdAt: Value(todo.createdAt),
    updatedAt: Value(todo.updatedAt),
  );

  DbChecklistItemCompanion _checklistCompanion(
    String todoId,
    ChecklistItem item,
  ) => DbChecklistItemCompanion(
    id: Value(item.id),
    todoId: Value(todoId),
    label: Value(item.label),
    isChecked: Value(item.isChecked),
  );

  DbDocumentCompanion _documentCompanion(DocumentRecord document) =>
      DbDocumentCompanion(
        id: Value(document.id),
        sourceType: Value(document.sourceType),
        localImagePath: Value(document.localImagePath),
        ocrText: Value(document.ocrText),
        createdAt: Value(document.createdAt),
        updatedAt: Value(document.updatedAt),
      );
}
