part of 'app_state.dart';

extension CleanupAppStateOperations on AppState {
  Future<void> clearAllData() => _runMutation(() async {
        final documentsToDelete = List<DocumentRecord>.from(documents);
        final todosToCancel = List<AppTodo>.from(todos);
        final cleanupPaths = _documentImageCleaner
            .pathsFor(documentsToDelete)
            .toList();

        await _store.clearWithSideEffects(
          notificationTodoIds: todosToCancel.map((todo) => todo.id),
          cleanupPaths: cleanupPaths,
        );
        _replaceChildren(const []);
        _replaceTodos(const []);
        _replaceDocuments(const []);

        await _notificationCoordinator.retryPending(const <AppTodo>[]);
        await _retryPendingFileCleanup();
        await SensitiveDataCleaner.clearResidualFiles();
      });

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
