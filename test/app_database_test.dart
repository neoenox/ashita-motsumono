// test/app_database_test.dart
// AppDatabase（Drift SQLite）のCRUD操作とスキーマをテストする。
// 関連: lib/src/repositories/app_database.dart, lib/src/models/entities.dart

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/repositories/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = await AppDatabase.createInMemory();
  });

  tearDown(() async {
    await db.close();
  });

  test('schema version is 1', () {
    expect(db.schemaVersion, 1);
  });

  test('saves and loads a child', () async {
    final child = PersonProfile(
      id: 'test1',
      name: '太郎',
      colorValue: 0xFF0000FF,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final snapshot = AppSnapshot(children: [child], todos: [], documents: []);
    await db.saveSnapshot(snapshot);
    final loaded = await db.loadSnapshot();
    expect(loaded.children.length, 1);
    expect(loaded.children.first.name, '太郎');
  });

  test('saves and loads a todo with items', () async {
    final todo = AppTodo(
      id: 'todo1',
      title: '集金500円',
      items: [
        ChecklistItem(id: 'item1', label: '集金袋', isChecked: false),
        ChecklistItem(id: 'item2', label: 'お釣り', isChecked: true),
      ],
      category: TodoCategory.payment,
      status: TodoStatus.active,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final snapshot = AppSnapshot(children: [], todos: [todo], documents: []);
    await db.saveSnapshot(snapshot);
    final loaded = await db.loadSnapshot();
    expect(loaded.todos.length, 1);
    expect(loaded.todos.first.title, '集金500円');
    expect(loaded.todos.first.items.length, 2);
    expect(loaded.todos.first.items.last.isChecked, isTrue);
  });

  test('saves and loads a document', () async {
    final doc = DocumentRecord(
      id: 'doc1',
      sourceType: 'camera',
      localImagePath: '/tmp/test.png',
      ocrText: '7月10日まで',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final snapshot = AppSnapshot(children: [], todos: [], documents: [doc]);
    await db.saveSnapshot(snapshot);
    final loaded = await db.loadSnapshot();
    expect(loaded.documents.length, 1);
    expect(loaded.documents.first.ocrText, '7月10日まで');
  });

  test('clearAll removes all data', () async {
    final todo = AppTodo(
      id: 'todo1',
      title: 'Test',
      items: [ChecklistItem(id: 'item1', label: 'L', isChecked: false)],
      category: TodoCategory.other,
      status: TodoStatus.active,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    await db.saveSnapshot(
      AppSnapshot(children: [], todos: [todo], documents: []),
    );
    await db.clearAll();
    final loaded = await db.loadSnapshot();
    expect(loaded.todos, isEmpty);
    expect(loaded.children, isEmpty);
    expect(loaded.documents, isEmpty);
  });

  test('backupDatabaseFile returns null for in-memory db', () async {
    expect(await db.backupDatabaseFile(), isNull);
  });
}
