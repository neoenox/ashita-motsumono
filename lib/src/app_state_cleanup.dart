part of 'app_state.dart';

extension CleanupAppStateOperations on AppState {
  Future<void> clearAllData({bool awaitPostDeleteCleanup = false}) =>
      _runMutation(() async {
        final documentsToDelete = List<DocumentRecord>.from(documents);
        final todosToCancel = List<AppTodo>.from(todos);
        final todoIdsToCancel = todosToCancel
            .map((todo) => todo.id)
            .toList(growable: false);
        final cleanupPaths = _documentImageCleaner
            .pathsFor(documentsToDelete)
            .toList();

        // 主データと副作用キューの登録だけを削除成功の必須境界とする。
        await _store.clearWithSideEffects(
          notificationTodoIds: todoIdsToCancel,
          cleanupPaths: cleanupPaths,
        );
        _replaceChildren(const []);
        _replaceTodos(const []);
        _replaceDocuments(const []);

        // 通常UIでは設定削除や成功表示をブロックしない。
        // テストや保守処理など、副作用完了まで必要な呼び出し元は明示的に待機できる。
        // 削除開始時に捕捉したTodoだけを取り消し、後から作成されたTodoの通知には触れない。
        final cleanup = _runPostDeleteCleanup(todoIdsToCancel);
        if (awaitPostDeleteCleanup) {
          await cleanup;
        } else {
          unawaited(cleanup);
        }
      });

  Future<void> _runPostDeleteCleanup(Iterable<String> todoIds) async {
    await _runPostDeleteBestEffort('notification cancellation', () async {
      for (final todoId in todoIds) {
        await _notificationCoordinator.executeCanceledTodo(todoId);
      }
    });
    await _runPostDeleteBestEffort(
      'document image cleanup',
      _retryPendingFileCleanup,
    );
    await _runPostDeleteBestEffort(
      'residual file cleanup',
      _sensitiveDataCleaner.clearResidualFiles,
    );
  }

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

  /// DBから参照されない画像ファイルを起動時に一掃する。
  /// 画像保存とDB保存の間でクラッシュした際の取り残しを回復する。
  Future<void> deleteOrphanDocumentImages() async {
    final directory = await _documentImageCleaner.resolveImagesDirectory();
    final referencedPaths = _documentImageCleaner.pathsFor(documents).toSet();
    await _documentImageCleaner.deleteOrphans(
      directory: directory,
      referencedPaths: referencedPaths,
    );
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
