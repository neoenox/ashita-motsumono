// lib/src/repositories/app_database.dart
// Drift（SQLite）データベース定義。テーブル定義とCRUDを一括管理。
// 関連: drift_store.dart, models/entities.dart, repositories/store.dart

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entities.dart';

part 'app_database.g.dart';

// ── テーブル定義 ──────────────────────────────────────────────

class DbChild extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorValue => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class DbTodo extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get childId => text().nullable()();
  TextColumn get documentId => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get category => text()();
  IntColumn get amount => integer().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get status => text()();
  BoolColumn get notifyPreviousNight => boolean()();
  BoolColumn get notifySameMorning => boolean()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get preparedDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class DbChecklistItem extends Table {
  TextColumn get id => text()();
  TextColumn get todoId => text()();
  TextColumn get label => text()();
  BoolColumn get isChecked => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

class DbDocument extends Table {
  TextColumn get id => text()();
  TextColumn get sourceType => text()();
  TextColumn get localImagePath => text().nullable()();
  TextColumn get ocrText => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ── データベース ──────────────────────────────────────────────

@DriftDatabase(tables: [DbChild, DbTodo, DbChecklistItem, DbDocument])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e, {this.databaseFile});

  final File? databaseFile;

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from == 1) {
            await m.addColumn(dbTodo, dbTodo.preparedDate);
          }
        },
      );

  /// SharedPreferences から JSON データを SQLite に移行する。
  static Future<AppDatabase> createWithMigration() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'ashita_motsumono.db'));
    final db = AppDatabase(NativeDatabase(file), databaseFile: file);
    // foreign_keys OFF: アプリ内では論理削除を使わず参照整合性をコード側で担保
    await db.customStatement('PRAGMA foreign_keys = OFF');

    final prefs = await SharedPreferences.getInstance();
    final migrated = prefs.getBool(_migrationDoneKey) ?? false;
    if (!migrated) {
      final ok = await db._migrateFromPrefs(prefs);
      if (ok) {
        await prefs.setBool(_migrationDoneKey, true);
      }
      // ok == false の場合、レガシーデータは存在するがパースに失敗。
      // 生JSONはバックアップ済み。次回起動時に再試行する。
    }
    return db;
  }

  /// レガシーSharedPreferences からデータを移行する。
  /// 戻り値: true=移行成功または移行不要 / false=データ存在→パース失敗（再試行必要）
  Future<bool> _migrateFromPrefs(SharedPreferences prefs) async {
    const key = 'ashita_motsumono_snapshot_v1';
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return true; // 移行不要

    await _backupRawSnapshot(raw);

    try {
      final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
      final snapshot = AppSnapshot.fromJson(jsonMap).migrate();
      await saveSnapshot(snapshot);
      return true;
    } on Object {
      return false; // パース失敗 → migrationDone はセットしない
    }
  }

  /// レガシー JSON をファイルに退避してからパースを試みる。
  Future<void> _backupRawSnapshot(String rawJson) async {
    try {
      final dir = databaseFile?.parent ?? await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final backup = File(p.join(dir.path, 'ashita_motsumono_legacy_backup_$stamp.json'));
      await backup.writeAsString(rawJson);
    } on Object {
      // バックアップ失敗は移行をブロックしない
    }
  }

  static const _migrationDoneKey = 'ashita_motsumono_drift_migrated_v1';

  /// テスト用: 空のインメモリDB
  static Future<AppDatabase> createInMemory() async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = OFF');
    return db;
  }

  /// テスト用: 与えられた SharedPreferences で移行を試行する（インメモリDB）。
  /// 戻り値: true=移行成功または不要 / false=レガシーデータが存在→パース失敗
  @visibleForTesting
  static Future<bool> tryMigration(SharedPreferences prefs) async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      return await db._migrateFromPrefs(prefs);
    } finally {
      await db.close();
    }
  }

  Future<String?> backupDatabaseFile() async {
    final source = databaseFile;
    if (source == null || !await source.exists()) return null;

    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final backup = File(p.join(source.parent.path, 'ashita_motsumono_corrupt_$stamp.db'));
    await source.copy(backup.path);
    return backup.path;
  }

  // ── CRUD ──────────────────────────────────────────────

  Future<AppSnapshot> loadSnapshot() async {
    final childRows = await select(dbChild).get();
    final todoRows = await select(dbTodo).get();
    final itemRows = await select(dbChecklistItem).get();
    final docRows = await select(dbDocument).get();

    final itemsByTodo = <String, List<DbChecklistItemData>>{};
    for (final item in itemRows) {
      itemsByTodo.putIfAbsent(item.todoId, () => []).add(item);
    }

    return AppSnapshot(
      children: childRows.map(_toPersonProfile).toList(),
      todos: todoRows.map((r) => _toAppTodo(r, itemsByTodo[r.id] ?? [])).toList(),
      documents: docRows.map(_toDocumentRecord).toList(),
    );
  }

  Future<void> saveSnapshot(AppSnapshot snapshot) async {
    await transaction(() async {
      // 現在のデータを取得
      final currentChildren = await select(dbChild).get();
      final currentTodos = await select(dbTodo).get();
      final currentDocs = await select(dbDocument).get();

      final currentChildIds = currentChildren.map((c) => c.id).toSet();
      final currentTodoIds = currentTodos.map((t) => t.id).toSet();
      final currentDocIds = currentDocs.map((d) => d.id).toSet();

      final newChildIds = snapshot.children.map((c) => c.id).toSet();
      final newTodoIds = snapshot.todos.map((t) => t.id).toSet();
      final newDocIds = snapshot.documents.map((d) => d.id).toSet();

      await batch((b) {
        // 削除: 新しいデータに存在しないもの
        for (final id in currentChildIds.difference(newChildIds)) {
          b.deleteWhere(dbChild, (t) => t.id.equals(id));
        }
        for (final id in currentTodoIds.difference(newTodoIds)) {
          b.deleteWhere(dbTodo, (t) => t.id.equals(id));
          b.deleteWhere(dbChecklistItem, (t) => t.todoId.equals(id));
        }
        for (final id in currentDocIds.difference(newDocIds)) {
          b.deleteWhere(dbDocument, (t) => t.id.equals(id));
        }

        // 追加・更新
        for (final child in snapshot.children) {
          b.insert(dbChild, _fromPersonProfile(child), mode: InsertMode.replace);
        }
        for (final todo in snapshot.todos) {
          b.insert(dbTodo, _fromAppTodo(todo), mode: InsertMode.replace);
          // 既存のチェックリスト項目を削除して再挿入
          b.deleteWhere(dbChecklistItem, (t) => t.todoId.equals(todo.id));
          for (final item in todo.items) {
            b.insert(dbChecklistItem, _fromChecklistItem(todo.id, item));
          }
        }
        for (final doc in snapshot.documents) {
          b.insert(dbDocument, _fromDocumentRecord(doc), mode: InsertMode.replace);
        }
      });
    });
  }

  Future<void> clearAll() async {
    await batch((b) {
      b.deleteAll(dbChild);
      b.deleteAll(dbTodo);
      b.deleteAll(dbChecklistItem);
      b.deleteAll(dbDocument);
    });
  }

  // ── 変換 ─────────────────────────────────────────────

  PersonProfile _toPersonProfile(DbChildData c) => PersonProfile(
        id: c.id,
        name: c.name,
        colorValue: c.colorValue,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
      );

  DbChildCompanion _fromPersonProfile(PersonProfile c) => DbChildCompanion(
        id: Value(c.id),
        name: Value(c.name),
        colorValue: Value(c.colorValue),
        createdAt: Value(c.createdAt),
        updatedAt: Value(c.updatedAt),
      );

  AppTodo _toAppTodo(DbTodoData r, List<DbChecklistItemData> items) => AppTodo(
        id: r.id,
        title: r.title,
        personId: r.childId,
        documentId: r.documentId,
        dueDate: r.dueDate,
        category: TodoCategory.fromName(r.category),
        amount: r.amount,
        note: r.note,
        status: TodoStatus.fromName(r.status),
        items: items
            .map((i) => ChecklistItem(id: i.id, label: i.label, isChecked: i.isChecked))
            .toList(),
        notifyPreviousNight: r.notifyPreviousNight,
        notifySameMorning: r.notifySameMorning,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        preparedDate: r.preparedDate,
      );

  DbTodoCompanion _fromAppTodo(AppTodo t) => DbTodoCompanion(
        id: Value(t.id),
        title: Value(t.title),
        childId: Value(t.personId),
        documentId: Value(t.documentId),
        dueDate: Value(t.dueDate),
        category: Value(t.category.name),
        amount: Value(t.amount),
        note: Value(t.note),
        status: Value(t.status.name),
        notifyPreviousNight: Value(t.notifyPreviousNight),
        notifySameMorning: Value(t.notifySameMorning),
        createdAt: Value(t.createdAt),
        updatedAt: Value(t.updatedAt),
        preparedDate: Value(t.preparedDate),
      );

  DbChecklistItemCompanion _fromChecklistItem(String todoId, ChecklistItem item) =>
      DbChecklistItemCompanion(
        id: Value(item.id),
        todoId: Value(todoId),
        label: Value(item.label),
        isChecked: Value(item.isChecked),
      );

  DocumentRecord _toDocumentRecord(DbDocumentData d) => DocumentRecord(
        id: d.id,
        sourceType: d.sourceType,
        localImagePath: d.localImagePath,
        ocrText: d.ocrText,
        createdAt: d.createdAt,
        updatedAt: d.updatedAt,
      );

  DbDocumentCompanion _fromDocumentRecord(DocumentRecord d) => DbDocumentCompanion(
        id: Value(d.id),
        sourceType: Value(d.sourceType),
        localImagePath: Value(d.localImagePath),
        ocrText: Value(d.ocrText),
        createdAt: Value(d.createdAt),
        updatedAt: Value(d.updatedAt),
      );

}
