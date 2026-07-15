part of 'app_state.dart';

extension DocumentAppStateOperations on AppState {
  Future<DocumentRecord> addDocument({
    required String sourceType,
    String? localImagePath,
    String? ocrText,
  }) async {
    final now = DateTime.now();
    final record = DocumentRecord(
      id: _uuid.v4(),
      sourceType: sourceType,
      localImagePath: localImagePath,
      ocrText: ocrText,
      createdAt: now,
      updatedAt: now,
    );
    final nextDocuments = [...documents, record];
    await _persistSnapshot(nextDocuments: nextDocuments);
    _replaceDocuments(nextDocuments);
    return record;
  }

  Future<bool> deleteDocument(String id) async {
    if (todos.any((todo) => todo.documentId == id)) return false;

    final deleted = documents
        .where((document) => document.id == id)
        .toList();
    if (deleted.isEmpty) return false;

    final nextDocuments = documents
        .where((document) => document.id != id)
        .toList();
    final cleanupPaths = _documentImageCleaner.pathsFor(deleted).toList();
    await _persistSnapshot(
      nextDocuments: nextDocuments,
      cleanupPaths: cleanupPaths,
    );
    _replaceDocuments(nextDocuments);
    await _retryPendingFileCleanup();
    return true;
  }

  List<DocumentRecord> _orphanDocumentsAfter(Iterable<AppTodo> nextTodos) {
    final usedDocumentIds = nextTodos
        .map((todo) => todo.documentId)
        .whereType<String>()
        .toSet();
    return documents
        .where((document) => !usedDocumentIds.contains(document.id))
        .toList();
  }

  List<DocumentRecord> _documentsReferencedBy(Iterable<AppTodo> nextTodos) {
    final usedDocumentIds = nextTodos
        .map((todo) => todo.documentId)
        .whereType<String>()
        .toSet();
    return documents
        .where((document) => usedDocumentIds.contains(document.id))
        .toList();
  }
}
