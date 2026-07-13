// lib/src/repositories/drift_store.dart
// Drift（SQLite）を使った永続化ストア。Store インターフェース経由で AppState から使う。
// 関連: app_database.dart, store.dart, models/entities.dart

import '../models/entities.dart';
import '../services/notification_id_repository.dart';
import 'app_database.dart';
import 'store.dart';

class DriftStore implements Store {
  DriftStore(this._db);

  AppDatabase _db;

  bool _lastLoadHadCorruptData = false;
  bool _writesBlocked = false;
  String? _corruptBackupInfo;

  @override
  bool get lastLoadHadCorruptData => _lastLoadHadCorruptData;

  @override
  bool get writesBlockedAfterLoadFailure => _writesBlocked;

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
    try {
      final snapshot = await _db.loadSnapshot();
      _lastLoadHadCorruptData = false;
      _writesBlocked = false;
      _corruptBackupInfo = null;
      return snapshot;
    } on Object catch (error, stackTrace) {
      _lastLoadHadCorruptData = true;
      _writesBlocked = true;
      _corruptBackupInfo = 'SQLiteデータベースの読み込みに失敗しました。原因: $error';
      try {
        final path = await _db.backupDatabaseFile();
        if (path != null) {
          _corruptBackupInfo =
              'SQLiteデータベースの読み込みに失敗したため、退避コピーを作成しました。\n\n'
              '$path\n\n原因: $error';
        }
      } on Object {
        // 退避コピーに失敗しても、書き込み禁止状態は維持する。
      }
      throw StoreLoadException(
        cause: error,
        backupInfo: _corruptBackupInfo,
        stackTrace: stackTrace,
      );
    }
  }

  void _ensureWritable() {
    if (_writesBlocked) {
      throw StateError(
        'Database writes are blocked after a load failure. '
        'Retry loading or explicitly reset the local database first.',
      );
    }
  }

  @override
  Future<void> save(AppSnapshot snapshot) {
    _ensureWritable();
    return _db.saveSnapshot(snapshot);
  }

  @override
  Future<void> saveWithSideEffects(
    AppSnapshot snapshot, {
    Map<String, NotificationSyncOperation> notificationOperations = const {},
    Iterable<String> cleanupPaths = const [],
  }) {
    _ensureWritable();
    return _db.saveSnapshotWithSideEffects(
      snapshot,
      notificationOperations: notificationOperations,
      cleanupPaths: cleanupPaths,
    );
  }

  @override
  String? loadCorruptBackup() => _corruptBackupInfo;

  @override
  Future<void> clear() {
    _ensureWritable();
    return _db.clearAll();
  }

  @override
  Future<void> clearWithSideEffects({
    Iterable<String> notificationTodoIds = const [],
    Iterable<String> cleanupPaths = const [],
  }) {
    _ensureWritable();
    return _db.clearAllWithSideEffects(
      notificationTodoIds: notificationTodoIds,
      cleanupPaths: cleanupPaths,
    );
  }

  @override
  Future<void> resetAfterLoadFailure() async {
    if (!_writesBlocked) return;

    await _db.close();
    await AppDatabase.deleteDatabaseFiles();
    _db = await AppDatabase.createWithMigration(skipLegacyMigration: true);
    // DBを実際に開き、補助テーブル・トリガー作成まで成功したことを確認する。
    await _db.loadSnapshot();
    _lastLoadHadCorruptData = false;
    _writesBlocked = false;
    _corruptBackupInfo = null;
  }

  @override
  Future<NotificationIdPair> getOrCreateNotificationIds(String todoId) {
    _ensureWritable();
    return _db.getOrCreateNotificationIds(todoId);
  }

  @override
  Future<NotificationIdPair?> findNotificationIds(String todoId) {
    _ensureWritable();
    return _db.findNotificationIds(todoId);
  }

  @override
  Future<void> releaseNotificationIds(String todoId) {
    _ensureWritable();
    return _db.releaseNotificationIds(todoId);
  }

  @override
  Future<void> queueNotificationSync(
    String todoId,
    NotificationSyncOperation operation, {
    String? lastError,
  }) {
    _ensureWritable();
    return _db.queueNotificationSync(
      todoId,
      operation,
      lastError: lastError,
    );
  }

  @override
  Future<List<PendingNotificationSync>> loadPendingNotificationSync() {
    _ensureWritable();
    return _db.loadPendingNotificationSync();
  }

  @override
  Future<void> completeNotificationSync(
    String todoId, {
    bool releaseIds = false,
  }) {
    _ensureWritable();
    return _db.completeNotificationSync(todoId, releaseIds: releaseIds);
  }

  @override
  Future<void> enqueueFileCleanup(Iterable<String> paths) {
    _ensureWritable();
    return _db.enqueueFileCleanup(paths);
  }

  @override
  Future<List<String>> loadPendingFileCleanup() {
    _ensureWritable();
    return _db.loadPendingFileCleanup();
  }

  @override
  Future<void> markFileCleanupComplete(String path) {
    _ensureWritable();
    return _db.markFileCleanupComplete(path);
  }

  @override
  Future<void> markFileCleanupFailed(String path, Object error) {
    _ensureWritable();
    return _db.markFileCleanupFailed(path, error);
  }

  @override
  Future<void> close() => _db.close();
}
