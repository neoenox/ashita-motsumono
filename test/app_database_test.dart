// test/app_database_test.dart
// AppDatabase（Drift SQLite）のCRUD操作とスキーマをテストする。
// 関連: lib/src/repositories/app_database.dart, lib/src/models/entities.dart

import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
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

  test('schema version is 2', () {
    expect(db.schemaVersion, 2);
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

  test('v2 schema migration preserves existing todo with preparedDate null', () async {
    // v1相当のスキーマでTodoを保存 → DBを閉じる → v2で開くをシミュレート
    // インメモリDBではmigrationが走らないため、直接preparedDateがnullで読み込めることを確認
    final todo = AppTodo(
      id: 'todo-mig',
      title: '移行テスト',
      items: [],
      category: TodoCategory.other,
      status: TodoStatus.active,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    await db.saveSnapshot(
      AppSnapshot(children: [], todos: [todo], documents: []),
    );
    final loaded = await db.loadSnapshot();
    expect(loaded.todos.length, 1);
    expect(loaded.todos.first.title, '移行テスト');
    expect(loaded.todos.first.preparedDate, isNull);
  });

  test('v2 schema saves and loads preparedDate', () async {
    final todo = AppTodo(
      id: 'todo-prep',
      title: '準備済みテスト',
      items: [],
      category: TodoCategory.other,
      status: TodoStatus.active,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      preparedDate: DateTime(2026, 7, 10),
    );
    await db.saveSnapshot(
      AppSnapshot(children: [], todos: [todo], documents: []),
    );
    final loaded = await db.loadSnapshot();
    expect(loaded.todos.length, 1);
    expect(loaded.todos.first.preparedDate, DateTime(2026, 7, 10));
  });

  group('real v1 to v2 migration via file', () {
    late Directory tempDir;
    late File dbFile;
    late AppDatabase appDb;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('drift_migration_test');
      dbFile = File(p.join(tempDir.path, 'test.db'));
    });

    tearDown(() async {
      await appDb.close();
      await Future.delayed(const Duration(milliseconds: 100));
      tempDir.deleteSync(recursive: true);
    });

    int _ms(int y, int m, int d) =>
        DateTime(y, m, d).millisecondsSinceEpoch;

    void _createV1Schema(Database rawDb) {
      rawDb.execute('PRAGMA user_version = 1');
      rawDb.execute('''
        CREATE TABLE db_child (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          color_value INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      rawDb.execute('''
        CREATE TABLE db_todo (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          child_id TEXT,
          document_id TEXT,
          due_date TEXT,
          category TEXT NOT NULL,
          amount INTEGER,
          note TEXT,
          status TEXT NOT NULL,
          notify_previous_night INTEGER NOT NULL,
          notify_same_morning INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      rawDb.execute('''
        CREATE TABLE db_checklist_item (
          id TEXT NOT NULL PRIMARY KEY,
          todo_id TEXT NOT NULL,
          label TEXT NOT NULL,
          is_checked INTEGER NOT NULL
        )
      ''');
      rawDb.execute('''
        CREATE TABLE db_document (
          id TEXT NOT NULL PRIMARY KEY,
          source_type TEXT NOT NULL,
          local_image_path TEXT,
          ocr_text TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
    }

    test('migrates v1 schema, preserves existing todo, preparedDate null', () async {
      final rawDb = sqlite3.open(dbFile.path);
      _createV1Schema(rawDb);
      rawDb.execute(
        "INSERT INTO db_todo (id, title, category, status, notify_previous_night, notify_same_morning, created_at, updated_at) "
        "VALUES ('v1-todo-1', '水筒持参', 'item', 'active', 1, 1, ${_ms(2026,1,1)}, ${_ms(2026,1,1)})",
      );
      rawDb.dispose();

      appDb = AppDatabase(NativeDatabase(dbFile), databaseFile: dbFile);
      await appDb.customStatement('PRAGMA foreign_keys = OFF');

      expect(appDb.schemaVersion, 2);
      final snapshot = await appDb.loadSnapshot();
      expect(snapshot.todos.length, 1);
      expect(snapshot.todos.first.id, 'v1-todo-1');
      expect(snapshot.todos.first.title, '水筒持参');
      expect(snapshot.todos.first.preparedDate, isNull);
    });

    test('v1 migrated todo can save and reload preparedDate', () async {
      final rawDb = sqlite3.open(dbFile.path);
      _createV1Schema(rawDb);
      rawDb.execute(
        "INSERT INTO db_todo (id, title, category, status, notify_previous_night, notify_same_morning, created_at, updated_at) "
        "VALUES ('v1-todo-2', '連絡帳', 'submit', 'active', 1, 1, ${_ms(2026,1,2)}, ${_ms(2026,1,2)})",
      );
      rawDb.dispose();

      appDb = AppDatabase(NativeDatabase(dbFile), databaseFile: dbFile);
      await appDb.customStatement('PRAGMA foreign_keys = OFF');
      var snapshot = await appDb.loadSnapshot();
      expect(snapshot.todos.length, 1);

      final updated = snapshot.todos.first.copyWith(
        preparedDate: DateTime(2026, 7, 10),
        updatedAt: DateTime(2026, 7, 10),
      );
      await appDb.saveSnapshot(AppSnapshot(
        children: [], todos: [updated], documents: [],
      ));
      await appDb.close();

      appDb = AppDatabase(NativeDatabase(dbFile), databaseFile: dbFile);
      await appDb.customStatement('PRAGMA foreign_keys = OFF');
      snapshot = await appDb.loadSnapshot();
      expect(snapshot.todos.length, 1);
      expect(snapshot.todos.first.id, 'v1-todo-2');
      expect(snapshot.todos.first.title, '連絡帳');
      expect(snapshot.todos.first.preparedDate, DateTime(2026, 7, 10));
    });

    test('migration does not lose checklist items', () async {
      final rawDb = sqlite3.open(dbFile.path);
      _createV1Schema(rawDb);
      rawDb.execute(
        "INSERT INTO db_todo (id, title, category, status, notify_previous_night, notify_same_morning, created_at, updated_at) "
        "VALUES ('v1-todo-3', '集金500円', 'payment', 'active', 1, 1, ${_ms(2026,1,3)}, ${_ms(2026,1,3)})",
      );
      rawDb.execute(
        "INSERT INTO db_checklist_item (id, todo_id, label, is_checked) "
        "VALUES ('ci-1', 'v1-todo-3', '集金袋', 1)",
      );
      rawDb.execute(
        "INSERT INTO db_checklist_item (id, todo_id, label, is_checked) "
        "VALUES ('ci-2', 'v1-todo-3', 'お釣り', 0)",
      );
      rawDb.dispose();

      appDb = AppDatabase(NativeDatabase(dbFile), databaseFile: dbFile);
      await appDb.customStatement('PRAGMA foreign_keys = OFF');
      final snapshot = await appDb.loadSnapshot();
      expect(snapshot.todos.length, 1);
      expect(snapshot.todos.first.items.length, 2);
      expect(snapshot.todos.first.items[0].label, '集金袋');
      expect(snapshot.todos.first.items[0].isChecked, isTrue);
      expect(snapshot.todos.first.items[1].label, 'お釣り');
      expect(snapshot.todos.first.items[1].isChecked, isFalse);
    });
  });
}
