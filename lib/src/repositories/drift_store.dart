// lib/src/repositories/drift_store.dart
// Drift（SQLite）を使った永続化ストア。Store インターフェース経由で AppState から使う。
// 関連: app_database.dart, store.dart, models/entities.dart

import 'app_database.dart';
import 'store.dart';
import '../models/entities.dart';

class DriftStore implements Store {
  DriftStore(this._db);

  final AppDatabase _db;

  bool _lastLoadHadCorruptData = false;
  @override
  bool get lastLoadHadCorruptData => _lastLoadHadCorruptData;

  static Future<DriftStore> create() async {
    final db = await AppDatabase.createWithMigration();
    return DriftStore(db);
  }

  /// テスト用: インメモリDB
  static Future<DriftStore> createInMemory() async {
    final db = await AppDatabase.createInMemory();
    return DriftStore(db);
  }

  @override
  Future<AppSnapshot> load() async {
    _lastLoadHadCorruptData = false;
    try {
      return await _db.loadSnapshot();
    } on Object {
      _lastLoadHadCorruptData = true;
      return AppSnapshot.empty;
    }
  }

  @override
  Future<void> save(AppSnapshot snapshot) async {
    await _db.saveSnapshot(snapshot);
  }

  @override
  String? loadCorruptBackup() => null;

  @override
  Future<void> clear() => _db.clearAll();
}
