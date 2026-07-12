// lib/src/repositories/drift_store.dart
// Drift（SQLite）を使った永続化ストア。Store インターフェース経由で AppState から使う。
// 関連: app_database.dart, snapshot_replacer.dart, store.dart, models/entities.dart

import 'app_database.dart';
import 'snapshot_replacer.dart';
import 'store.dart';
import '../models/entities.dart';

class DriftStore implements Store {
  DriftStore(AppDatabase db)
    : _db = db,
      _snapshotReplacer = SnapshotReplacer(db);

  final AppDatabase _db;
  final SnapshotReplacer _snapshotReplacer;

  bool _lastLoadHadCorruptData = false;
  String? _corruptBackupInfo;

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
    _corruptBackupInfo = null;
    try {
      return await _db.loadSnapshot();
    } on Object catch (e) {
      _lastLoadHadCorruptData = true;
      _corruptBackupInfo = 'SQLiteデータベースの読み込みに失敗しました。原因: $e';
      try {
        final path = await _db.backupDatabaseFile();
        if (path != null) {
          _corruptBackupInfo = 'SQLiteデータベースの読み込みに失敗したため、退避コピーを作成しました。\n\n$path\n\n原因: $e';
        }
      } on Object {
        // 退避コピーに失敗してもアプリ起動は継続する
      }
      return AppSnapshot.empty;
    }
  }

  @override
  Future<void> save(AppSnapshot snapshot) => _snapshotReplacer.replace(snapshot);

  @override
  String? loadCorruptBackup() => _corruptBackupInfo;

  @override
  Future<void> clear() => _db.clearAll();
}
