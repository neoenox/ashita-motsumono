// test/app_database_test.dart
// AppDatabase（Drift SQLite）のCRUD操作とスキーマをテストする。
// 関連: lib/src/repositories/app_database.dart, lib/src/models/entities.dart

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  group('legacy migration safety', () {
    test('migrates valid legacy snapshot', () async {
      SharedPreferences.setMockInitialValues({
        'ashita_motsumono_snapshot_v1': '''
        {
          "version": 1,
          "children": [],
          "todos": [
            {
              "id": "todo-1",
              "title": "水筒持参",
              "category": "item",
              "status": "active",
              "items": [],
              "notifyPreviousNight": true,
              "notifySameMorning": true,
              "createdAt": "2026-01-01T00:00:00.000",
              "updatedAt": "2026-01-01T00:00:00.000"
            }
          ],
          "documents": []
        }
        ''',
      });
      final prefs = await SharedPreferences.getInstance();
      final ok = await AppDatabase.tryMigration(prefs);
      expect(ok, isTrue);
    });

    test('preserves legacy childId through database migration', () async {
      SharedPreferences.setMockInitialValues({
        'ashita_motsumono_snapshot_v1': '''
        {
          "version": 1,
          "children": [],
          "todos": [
            {
              "id": "todo-legacy-child",
              "title": "体操着",
              "childId": "child-legacy",
              "category": "item",
              "status": "active",
              "items": [],
              "notifyPreviousNight": true,
              "notifySameMorning": true,
              "createdAt": "2026-01-01T00:00:00.000",
              "updatedAt": "2026-01-01T00:00:00.000"
            }
          ],
          "documents": []
        }
        ''',
      });
      final prefs = await SharedPreferences.getInstance();
      AppSnapshot? snapshot;
      final ok = await AppDatabase.tryMigration(
        prefs,
        onMigrated: (migrated) => snapshot = migrated,
      );

      expect(ok, isTrue);
      expect(snapshot, isNotNull);
      expect(snapshot!.todos.single.personId, 'child-legacy');
    });

    test('current personId takes precedence over legacy childId', () async {
      SharedPreferences.setMockInitialValues({
        'ashita_motsumono_snapshot_v1': '''
        {
          "version": 1,
          "children": [],
          "todos": [
            {
              "id": "todo-current-person",
              "title": "提出物",
              "personId": "person-current",
              "childId": "child-legacy",
              "category": "submission",
              "status": "active",
              "items": [],
              "notifyPreviousNight": true,
              "notifySameMorning": true,
              "createdAt": "2026-01-01T00:00:00.000",
              "updatedAt": "2026-01-01T00:00:00.000"
            }
          ],
          "documents": []
        }
        ''',
      });
      final prefs = await SharedPreferences.getInstance();
      AppSnapshot? snapshot;
      final ok = await AppDatabase.tryMigration(
        prefs,
        onMigrated: (migrated) => snapshot = migrated,
      );

      expect(ok, isTrue);
      expect(snapshot, isNotNull);
      expect(snapshot!.todos.single.personId, 'person-current');
    });

    test('marks migration done when no legacy data', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ok = await AppDatabase.tryMigration(prefs);
      expect(ok, isTrue);
    });

    test('does not mark migration done when legacy JSON is corrupt', () async {
      SharedPreferences.setMockInitialValues({
        'ashita_motsumono_snapshot_v1': 'not valid json at all',
      });
      final prefs = await SharedPreferences.getInstance();
      final ok = await AppDatabase.tryMigration(prefs);
      expect(ok, isFalse);
    });

    test('migrates todo with invalid dueDate gracefully', () async {
      SharedPreferences.setMockInitialValues({
        'ashita_motsumono_snapshot_v1': '''
        {
          "version": 1,
          "children": [],
          "todos": [
            {
              "id": "todo-1",
              "title": "Bad date",
              "category": "other",
              "status": "active",
              "items": [],
              "dueDate": "not-a-date",
              "notifyPreviousNight": true,
              "notifySameMorning": true,
              "createdAt": "2026-01-01T00:00:00.000",
              "updatedAt": "2026-01-01T00:00:00.000"
            }
          ],
          "documents": []
        }
        ''',
      });
      final prefs = await SharedPreferences.getInstance();
      final ok = await AppDatabase.tryMigration(prefs);
      // dueDate is invalid but DateTime.tryParse returns null gracefully
      expect(ok, isTrue);
    });
  });
}
