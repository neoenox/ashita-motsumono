// lib/src/app_state.dart
// ChangeNotifier ベースのアプリ状態ファサード。
// 状態遷移と永続化順序を統括し、生成・通知・画像削除は専用サービスへ委譲する。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'models/entities.dart';
import 'repositories/store.dart';
import 'services/document_image_cleaner.dart';
import 'services/notification_coordinator.dart';
import 'services/notification_service.dart';
import 'services/todo_factory.dart';

int _sortTodo(AppTodo a, AppTodo b) {
  final ad = a.dueDate;
  final bd = b.dueDate;
  if (ad == null && bd == null) return a.createdAt.compareTo(b.createdAt);
  if (ad == null) return 1;
  if (bd == null) return -1;
  final dateOrder = ad.compareTo(bd);
  if (dateOrder != 0) return dateOrder;
  return a.createdAt.compareTo(b.createdAt);
}

class AppState extends ChangeNotifier {
  AppState({required this._store, required this._notifications, Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final Store _store;
  final NotificationService _notifications;
  final Uuid _uuid;

  late final TodoFactory _todoFactory = TodoFactory(_uuid);
  late final NotificationCoordinator _notificationCoordinator =
      NotificationCoordinator(_notifications);
  final DocumentImageCleaner _documentImageCleaner =
      const DocumentImageCleaner();

  bool _loaded = false;
  bool get loaded => _loaded;
  bool get lastLoadHadCorruptData => _store.lastLoadHadCorruptData;

  List<PersonProfile> _children = [];
  List<AppTodo> _todos = [];
  List<DocumentRecord> _documents = [];

  List<PersonProfile> get children => List.unmodifiable(_children);
  List<AppTodo> get todos => List.unmodifiable(_todos);
  List<DocumentRecord> get documents => List.unmodifiable(_documents);

  Future<void> load() async {
    final snapshot = await _store.load();
    _children = snapshot.children;
    _todos = snapshot.todos;
    _documents = snapshot.documents;
    _loaded = true;
    notifyListeners();
  }

  Future<void> requestNotificationPermissions() {
    return _notificationCoordinator.requestPermissions();
  }

  String? loadCorruptBackup() => _store.loadCorruptBackup();

  List<AppTodo> todosForDate(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    return _todos
        .where(
          (todo) =>
              todo.status == TodoStatus.active &&
              todo.dueDate != null &&
              DateTime(
                    todo.dueDate!.year,
                    todo.dueDate!.month,
                    todo.dueDate!.day,
                  ) ==
                  targetDate,
        )
        .toList()
      ..sort(_sortTodo);
  }

  List<AppTodo> futureTodos() {
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(const Duration(days: 2));
    return _todos
        .where(
          (todo) =>
              todo.status == TodoStatus.active &&
              todo.dueDate != null &&
              !todo.dueDate!.isBefore(start),
        )
        .toList()
      ..sort(_sortTodo);
  }

  List<AppTodo> undatedTodos() {
    return _todos
        .where(
          (todo) => todo.status == TodoStatus.active && todo.dueDate == null,
        )
        .toList()
      ..sort(_sortTodo);
  }

  PersonProfile? personById(String? id) {
    if (id == null) return null;
    return _children.where((child) => child.id == id).firstOrNull;
  }

  DocumentRecord? documentById(String? id) {
    if (id == null) return null;
    return _documents.where((document) => document.id == id).firstOrNull;
  }

  static const _personColors = <Color>[
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF00ACC1),
    Color(0xFFD81B60),
    Color(0xFF3949AB),
    Color(0xFF6D4C41),
    Color(0xFF546E7A),
  ];

  int _assignPersonColor() {
    final usedColors = _children.map((child) => child.colorValue).toSet();
    for (final color in _personColors) {
      if (!usedColors.contains(color.toARGB32())) return color.toARGB32();
    }
    return _personColors[_children.length % _personColors.length].toARGB32();
  }

  Future<PersonProfile> addChild(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }

    final now = DateTime.now();
    final child = PersonProfile(
      id: _uuid.v4(),
      name: trimmedName,
      colorValue: _assignPersonColor(),
      createdAt: now,
      updatedAt: now,
    );
    _children = [..._children, child];
    await _persist();
    notifyListeners();
    return child;
  }

  Future<void> deleteChild(String id) async {
    _children = _children.where((child) => child.id != id).toList();
    final now = DateTime.now();
    _todos = _todos
        .map(
          (todo) => todo.personId == id
              ? todo.copyWith(clearPersonId: true, updatedAt: now)
              : todo,
        )
        .toList();
    await _persist();
    notifyListeners();
  }

  Future<void> updateChild(PersonProfile child) async {
    final updated = child.copyWith(updatedAt: DateTime.now());
    _children = _children
        .map((existing) => existing.id == updated.id ? updated : existing)
        .toList();
    await _persist();
    notifyListeners();
  }

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
    _documents = [..._documents, record];
    await _persist();
    notifyListeners();
    return record;
  }

  Future<bool> deleteDocument(String id) async {
    final used = _todos.any((todo) => todo.documentId == id);
    if (used) return false;

    final deleted = _documents
        .where((document) => document.id == id)
        .toList();
    if (deleted.isEmpty) return false;

    _documents = _documents.where((document) => document.id != id).toList();
    await _persist();
    await _documentImageCleaner.deleteAll(deleted);
    notifyListeners();
    return true;
  }

  Future<AppTodo> addTodoFromDraft({
    required ExtractionDraft draft,
    String? personId,
    String? documentId,
    bool notifyPreviousNight = true,
    bool notifySameMorning = true,
  }) async {
    final todo = _todoFactory.fromDraft(
      draft: draft,
      personId: personId,
      documentId: documentId,
      notifyPreviousNight: notifyPreviousNight,
      notifySameMorning: notifySameMorning,
    );
    _todos = [..._todos, todo];
    await _persist();
    await _notificationCoordinator.schedule(todo);
    notifyListeners();
    return todo;
  }

  Future<void> updateTodo(AppTodo todo) async {
    final updated = todo.copyWith(updatedAt: DateTime.now());
    await _updateTodo(updated);
  }

  Future<void> _updateTodo(
    AppTodo updated, {
    bool rescheduleNotification = true,
  }) async {
    _todos = _todos
        .map((existing) => existing.id == updated.id ? updated : existing)
        .toList();
    await _persist();
    if (rescheduleNotification) {
      await _notificationCoordinator.schedule(updated);
    }
    notifyListeners();
  }

  Future<void> toggleTodoDone(String id) async {
    final todo = _todos.where((existing) => existing.id == id).firstOrNull;
    if (todo == null) return;
    final updated = todo.copyWith(
      status: todo.status == TodoStatus.done
          ? TodoStatus.active
          : TodoStatus.done,
      updatedAt: DateTime.now(),
    );
    _todos = _todos
        .map((existing) => existing.id == id ? updated : existing)
        .toList();
    await _persist();
    if (updated.isDone) {
      await _notificationCoordinator.cancel(updated.id);
    } else {
      await _notificationCoordinator.schedule(updated);
    }
    notifyListeners();
  }

  Future<void> toggleItem(String todoId, String itemId) async {
    final todo = _todos.where((existing) => existing.id == todoId).firstOrNull;
    if (todo == null) return;
    final items = todo.items
        .map(
          (item) => item.id == itemId
              ? item.copyWith(isChecked: !item.isChecked)
              : item,
        )
        .toList();
    await _updateTodo(
      todo.copyWith(items: items, updatedAt: DateTime.now()),
      rescheduleNotification: false,
    );
  }

  Future<void> deleteTodo(String id) async {
    _todos = _todos.where((todo) => todo.id != id).toList();
    final orphanDocuments = _cleanupOrphanDocuments();
    await _persist();
    await _notificationCoordinator.cancel(id);
    await _documentImageCleaner.deleteAll(orphanDocuments);
    notifyListeners();
  }

  Future<List<AppTodo>> addTodosFromDrafts({
    required List<ExtractionDraft> drafts,
    String? personId,
    String? documentId,
    bool notifyPreviousNight = true,
    bool notifySameMorning = true,
  }) async {
    final todos = _todoFactory.fromDrafts(
      drafts: drafts,
      personId: personId,
      documentId: documentId,
      notifyPreviousNight: notifyPreviousNight,
      notifySameMorning: notifySameMorning,
    );
    _todos = [..._todos, ...todos];
    await _persist();
    await _notificationCoordinator.rescheduleAll(todos);
    notifyListeners();
    return todos;
  }

  Future<void> rescheduleAllNotifications() {
    return _notificationCoordinator.rescheduleAll(_todos);
  }

  Future<void> clearAllData() async {
    final documentsToDelete = List<DocumentRecord>.from(_documents);
    final todosToCancel = List<AppTodo>.from(_todos);
    _children = [];
    _todos = [];
    _documents = [];
    await _store.clear();
    await _notificationCoordinator.cancelAll(todosToCancel);
    await _documentImageCleaner.deleteAll(documentsToDelete);
    notifyListeners();
  }

  List<DocumentRecord> _cleanupOrphanDocuments() {
    final usedDocumentIds = _todos
        .map((todo) => todo.documentId)
        .whereType<String>()
        .toSet();
    final orphanDocuments = _documents
        .where((document) => !usedDocumentIds.contains(document.id))
        .toList();
    _documents = _documents
        .where((document) => usedDocumentIds.contains(document.id))
        .toList();
    return orphanDocuments;
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

  Future<void> _persist() {
    return _store.save(
      AppSnapshot(
        children: _children,
        todos: _todos,
        documents: _documents,
      ),
    );
  }
}
