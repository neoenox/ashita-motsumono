part of 'app_state.dart';

extension CleanupAppStateOperations on AppState {
  Future<void> clearAllData() => _runMutation(() async {
        final documentsToDelete = List<DocumentRecord>.from(documents);
        final todosToCancel = List<AppTodo>.from(todos);
        final cleanupPaths = _documentImageCleaner
            .pathsFor(documentsToDelete)
            .toList();

        // 主データと副作用キューの登録だけを削除成功の必須境界とする。
        await _store.clearWithSideEffects(
          notificationTodoIds: todosToCancel.map((todo) => todo.id),
          cleanupPaths: cleanupPaths,
        );
        _replaceChildren(const []);
        _replaceTodos(const []);
        _replaceDocuments(const []);

        // OS通知取消、画像削除、残留ログ削除は再試行可能な後処理。
        // 主データ削除後の一時的なプラグイン/I/O障害で、削除済み操作を
        // ユーザーへ失敗扱いとして返さない。
        await _runPostDeleteBestEffort(
          'notification cancellation',
          () => _notificationCoordinator.retryPending(const <AppTodo>[]),
        );
        await _runPostDeleteBestEffort(
          'document image cleanup',
          _retryPendingFileCleanup,
        );
        await _runPostDeleteBestEffort(
          'residual file cleanup',
          _sensitiveDataCleaner.clearResidualFiles,
        );
      });

  Future<void> _runPostDeleteBestEffort(
    String operation,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Post-delete $operation failed and will remain best effort: '
          '$error\n$stackTrace',
        );
      }
    }
  }

  Future<void> tryDeleteDocumentOnDispose({
    required bool saved,
    required String? documentId,
  }) async {
    if (saved || documentId == null) return;
    try {
      final deleted = await deleteDocument(documentId);
      if (kDebugMode) {
        debugPrint('Document cleanup: ${deleted ? "deleted" : "still in use"}');
      }
    } on Object catch (error) {
      if (kDebugMode) debugPrint('Failed to clean up document: $error');
    }
  }
}
