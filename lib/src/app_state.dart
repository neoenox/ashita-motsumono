// lib/src/app_state.dart
// ChangeNotifier ベースのアプリ全体の状態管理。
// 子ども・Todo・ドキュメントの CRUD、通知スケジュール、永続化を統括する。
// 関連: models/entities.dart, repositories/local_store.dart, services/notification_service.dart

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'models/entities.dart';
import 'repositories/local_store.dart';
import 'services/image_file_service.dart';
import 'services/notification_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    required this._store,
    required this._notifications,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final LocalStore _store;
  final NotificationService _notifications;
  final Uuid _uuid;

  bool _loaded = false;
  bool get loaded => _loaded;

  List<ChildProfile> _children = [];
  List<AppTodo> _todos = [];
  List<DocumentRecord> _documents = [];

  List<ChildProfile> get children => List.unmodifiable(_children);
  List<AppTodo> get todos => List.unmodifiable(_todos);
  List<DocumentRecord> get documents => List.unmodifiable(_documents);

  Future<void> load() async {
    final snapshot = _store.load();
    _children = snapshot.children;
    _todos = snapshot.todos;
    _documents = snapshot.documents;
    _loaded = true;
    notifyListeners();
  }

  Future<void> requestNotificationPermissions() {
    return _notifications.requestPermissions();
  }

  List<AppTodo> todosForDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return _todos
        .where((todo) =>
            todo.status == TodoStatus.active &&
            todo.dueDate != null &&
            DateTime(todo.dueDate!.year, todo.dueDate!.month, todo.dueDate!.day) == d)
        .toList()
      ..sort(_sortTodo);
  }

  List<AppTodo> upcomingTodos() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return _todos
        .where((todo) =>
            todo.status == TodoStatus.active &&
            (todo.dueDate == null || !todo.dueDate!.isBefore(start)))
        .toList()
      ..sort(_sortTodo);
  }

  List<AppTodo> undatedTodos() {
    return _todos
        .where((todo) => todo.status == TodoStatus.active && todo.dueDate == null)
        .toList()
      ..sort(_sortTodo);
  }

  ChildProfile? childById(String? id) {
    if (id == null) return null;
    for (final child in _children) {
      if (child.id == id) return child;
    }
    return null;
  }

  DocumentRecord? documentById(String? id) {
    if (id == null) return null;
    for (final document in _documents) {
      if (document.id == id) return document;
    }
    return null;
  }

  Future<ChildProfile> addChild(String name) async {
    final now = DateTime.now();
    final child = ChildProfile(
      id: _uuid.v4(),
      name: name.trim(),
        colorValue: Colors.primaries[_children.length % Colors.primaries.length].toARGB32(),
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
    _todos = _todos
        .map((todo) => todo.childId == id ? todo.copyWith(clearChildId: true) : todo)
        .toList();
    await _persist();
    notifyListeners();
  }

  Future<void> updateChild(ChildProfile child) async {
    final updated = child.copyWith(updatedAt: DateTime.now());
    _children = _children.map((e) => e.id == updated.id ? updated : e).toList();
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

  Future<AppTodo> addTodoFromDraft({
    required ExtractionDraft draft,
    String? childId,
    String? documentId,
    bool notifyPreviousNight = true,
    bool notifySameMorning = true,
  }) async {
    final now = DateTime.now();
    final todo = AppTodo(
      id: _uuid.v4(),
      title: draft.title.trim().isEmpty ? 'プリントを確認' : draft.title.trim(),
      childId: childId,
      documentId: documentId,
      dueDate: draft.dueDate,
      category: draft.category,
      amount: draft.amount,
      note: draft.note,
      status: TodoStatus.active,
      items: draft.items
          .where((e) => e.trim().isNotEmpty)
          .map((label) => ChecklistItem(id: _uuid.v4(), label: label.trim()))
          .toList(),
      notifyPreviousNight: notifyPreviousNight,
      notifySameMorning: notifySameMorning,
      createdAt: now,
      updatedAt: now,
    );
    _todos = [..._todos, todo];
    await _persist();
    try {
      await _notifications.scheduleTodo(todo);
    } on Object {
      // Web など通知非対応環境では無視
    }
    notifyListeners();
    return todo;
  }

  Future<void> updateTodo(AppTodo todo) async {
    final updated = todo.copyWith(updatedAt: DateTime.now());
    _todos = _todos.map((e) => e.id == updated.id ? updated : e).toList();
    await _persist();
    try {
      await _notifications.scheduleTodo(updated);
    } on Object {
      // Web など通知非対応環境では無視
    }
    notifyListeners();
  }

  Future<void> toggleTodoDone(String id) async {
    final todo = _todos.where((e) => e.id == id).firstOrNull;
    if (todo == null) return;
    final updated = todo.copyWith(
      status: todo.status == TodoStatus.done ? TodoStatus.active : TodoStatus.done,
      updatedAt: DateTime.now(),
    );
    _todos = _todos.map((e) => e.id == id ? updated : e).toList();
    await _persist();
    try {
      if (updated.isDone) {
        await _notifications.cancelTodo(updated.id);
      } else {
        await _notifications.scheduleTodo(updated);
      }
    } on Object {
      // Web など通知非対応環境では無視
    }
    notifyListeners();
  }

  Future<void> toggleItem(String todoId, String itemId) async {
    final todo = _todos.where((e) => e.id == todoId).firstOrNull;
    if (todo == null) return;
    final items = todo.items
        .map((item) => item.id == itemId ? item.copyWith(isChecked: !item.isChecked) : item)
        .toList();
    await updateTodo(todo.copyWith(items: items));
  }

  Future<void> deleteTodo(String id) async {
    _todos = _todos.where((todo) => todo.id != id).toList();
    final orphanDocuments = _cleanupOrphanDocuments();
    await _persist();
    try {
      await _notifications.cancelTodo(id);
    } on Object {
      // Web など通知非対応環境では無視
    }
    await _deleteDocumentImages(orphanDocuments);
    notifyListeners();
  }

  List<DocumentRecord> _cleanupOrphanDocuments() {
    final usedDocIds = _todos.map((t) => t.documentId).whereType<String>().toSet();
    final orphanDocuments = _documents.where((d) => !usedDocIds.contains(d.id)).toList();
    _documents = _documents.where((d) => usedDocIds.contains(d.id)).toList();
    return orphanDocuments;
  }

  Future<void> _deleteDocumentImages(List<DocumentRecord> documents) async {
    for (final document in documents) {
      final path = document.localImagePath;
      if (path == null || path.isEmpty) continue;
      try {
        await ImageFileService.deleteIfExists(path);
      } on Object {
        // 画像削除に失敗してもTodo削除は成立させる
      }
    }
  }

  Future<void> _persist() {
    return _store.save(
      AppSnapshot(children: _children, todos: _todos, documents: _documents),
    );
  }

  int _sortTodo(AppTodo a, AppTodo b) {
    final ad = a.dueDate;
    final bd = b.dueDate;
    if (ad == null && bd == null) return a.createdAt.compareTo(b.createdAt);
    if (ad == null) return 1;
    if (bd == null) return -1;
    final d = ad.compareTo(bd);
    if (d != 0) return d;
    return a.createdAt.compareTo(b.createdAt);
  }
}
