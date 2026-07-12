part of 'app_state.dart';

extension CleanupAppStateOperations on AppState {
  Future<void> clearAllData() async {
    final documentsToDelete = List<DocumentRecord>.from(documents);
    final todosToCancel = List<AppTodo>.from(todos);
    _replaceChildren(const []);
    _replaceTodos(const []);
    _replaceDocuments(const []);
    await _store.clear();
    await _notificationCoordinator.cancelAll(todosToCancel);
    await _documentImageCleaner.deleteAll(documentsToDelete);
    notifyListeners();
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
