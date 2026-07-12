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
    _replaceDocuments([...documents, record]);
    await _persist();
    return record;
  }

  Future<bool> deleteDocument(String id) async {
    if (todos.any((todo) => todo.documentId == id)) return false;

    final deleted = documents
        .where((document) => document.id == id)
        .toList();
    if (deleted.isEmpty) return false;

    _replaceDocuments(
      documents.where((document) => document.id != id),
    );
    await _persist();
    await _documentImageCleaner.deleteAll(deleted);
    return true;
  }

  List<DocumentRecord> _cleanupOrphanDocuments() {
    final usedDocumentIds = todos
        .map((todo) => todo.documentId)
        .whereType<String>()
        .toSet();
    final orphanDocuments = documents
        .where((document) => !usedDocumentIds.contains(document.id))
        .toList();
    _replaceDocuments(
      documents.where((document) => usedDocumentIds.contains(document.id)),
    );
    return orphanDocuments;
  }
}
