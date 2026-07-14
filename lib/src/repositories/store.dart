// lib/src/repositories/store.dart
// 永続化ストアの共通インターフェース。DriftStore が実装する。
// 関連: drift_store.dart, app_state.dart

import 'package:flutter/foundation.dart';

import '../models/entities.dart';
import '../services/notification_id_repository.dart';

enum NotificationSyncOperation {
  schedule,
  cancel;

  static NotificationSyncOperation fromName(String? value) {
    return NotificationSyncOperation.values.firstWhere(
      (operation) => operation.name == value,
      orElse: () => NotificationSyncOperation.schedule,
    );
  }
}

@immutable
class PendingNotificationSync {
  const PendingNotificationSync({
    required this.todoId,
    required this.operation,
    required this.updatedAt,
    this.lastError,
  });

  final String todoId;
  final NotificationSyncOperation operation;
  final DateTime updatedAt;
  final String? lastError;
}

class StoreLoadException implements Exception {
  StoreLoadException({
    required this.cause,
    required this.backupInfo,
    this.stackTrace,
  });

  final Object cause;
  final String? backupInfo;
  final StackTrace? stackTrace;

  @override
  String toString() => 'StoreLoadException: $cause';
}

abstract class Store implements NotificationIdRepository {
  Future<AppSnapshot> load();

  Future<void> save(AppSnapshot snapshot);

  /// スナップショット更新と副作用キュー登録を同じ永続化境界で行う。
  /// DriftStore はトランザクションで実装し、簡易テストストアは既定実装を使える。
  Future<void> saveWithSideEffects(
    AppSnapshot snapshot, {
    Map<String, NotificationSyncOperation> notificationOperations = const {},
    Iterable<String> cleanupPaths = const [],
  }) async {
    await save(snapshot);
    for (final entry in notificationOperations.entries) {
      await queueNotificationSync(entry.key, entry.value);
    }
    await enqueueFileCleanup(cleanupPaths);
  }

  String? loadCorruptBackup();

  Future<void> clear();

  /// 全ユーザーデータ削除と、削除後に必要な通知取消・画像削除を永続化する。
  Future<void> clearWithSideEffects({
    Iterable<String> notificationTodoIds = const [],
    Iterable<String> cleanupPaths = const [],
  }) async {
    for (final todoId in notificationTodoIds) {
      await queueNotificationSync(todoId, NotificationSyncOperation.cancel);
    }
    await enqueueFileCleanup(cleanupPaths);
    await clear();
  }

  bool get lastLoadHadCorruptData;

  bool get writesBlockedAfterLoadFailure => false;

  Future<void> resetAfterLoadFailure();

  Future<void> queueNotificationSync(
    String todoId,
    NotificationSyncOperation operation, {
    String? lastError,
  });

  Future<List<PendingNotificationSync>> loadPendingNotificationSync();

  Future<void> completeNotificationSync(
    String todoId, {
    bool releaseIds = false,
  });

  Future<void> enqueueFileCleanup(Iterable<String> paths);

  Future<List<String>> loadPendingFileCleanup();

  Future<void> markFileCleanupComplete(String path);

  Future<void> markFileCleanupFailed(String path, Object error);

  Future<void> close() async {}
}
