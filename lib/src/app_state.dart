// lib/src/app_state.dart
// ChangeNotifier ベースのアプリ全体の状態管理。
// 子ども・Todo・ドキュメントの CRUD、通知スケジュール、永続化を統括する。
// 関連: models/entities.dart, repositories/store.dart, services/notification_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'models/entities.dart';
import 'repositories/store.dart';
import 'services/image_file_service.dart';
import 'services/notification_service.dart';

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

class AppState extends ChangeNotifier {
  AppState({required this._store, required this._notifications, Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final Store _store;
  final NotificationService _notifications;
  final Uuid _uuid;

  // ── 状態 ──────────────────────────────────────────────

  bool _loaded = false;
  bool get loaded => _loaded;
  bool get lastLoadHadCorruptData => _store.lastLoadHadCorruptData;

  List<PersonProfile> _children = [];
  List<AppTodo> _todos = [];
  List<DocumentRecord> _documents = [];

  List<PersonProfile> get children => List.unmodifiable(_children);
  List<AppTodo> get todos => List.unmodifiable(_todos);
  List<DocumentRecord> get documents => List.unmodifiable(_documents);

  // ── 初期化 ──────────────────────────────────────────────

  Future<void> load() async {
    final snapshot = await _store.load();
    _children = snapshot.children;
    _todos = snapshot.todos;
    _documents = snapshot.documents;
    _loaded = true;
    notifyListeners();
  }

  Future<void> requestNotificationPermissions() {
    return _notifications.requestPermissions();
  }

  String? loadCorruptBackup() => _store.loadCorruptBackup();

  // ── クエリ ──────────────────────────────────────────────

  List<AppTodo> todosForDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
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
                  d,
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

  /// 指定日の準備対象Todoを返す。
  /// 条件: status==active, dueDate!=null, dueDate<=指定日, preparedDate!=指定日
  List<AppTodo> todosForPreparation(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return _todos
        .where((todo) {
          if (todo.status != TodoStatus.active) return false;
          if (todo.dueDate == null) return false;
          final dd = DateTime(
            todo.dueDate!.year, todo.dueDate!.month, todo.dueDate!.day,
          );
          if (dd.isAfter(d)) return false;
          if (todo.preparedDate != null) {
            final pd = DateTime(
              todo.preparedDate!.year,
              todo.preparedDate!.month,
              todo.preparedDate!.day,
            );
            if (pd == d) return false;
          }
          return true;
        })
        .toList()
      ..sort(_prepSort);
  }

  /// 今日すでに準備済みのTodo（preparedDate == 今日）を返す。
  List<AppTodo> todosPreparedToday(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return _todos.where((todo) {
      if (todo.preparedDate == null) return false;
      final pd = DateTime(
        todo.preparedDate!.year,
        todo.preparedDate!.month,
        todo.preparedDate!.day,
      );
      return pd == d;
    }).toList();
  }

  /// 準備対象の子どもの表示名リスト（最大2名＋「他N人」）。
  /// 子どもの登録順に返す。
  List<String> prepChildNames(DateTime date) {
    final todos = todosForPreparation(date);
    final ids = todos.map((t) => t.personId).whereType<String>().toSet();
    final names = <String>[];
    // 子どもの登録順に表示
    for (final child in _children) {
      if (ids.contains(child.id)) {
        names.add(child.name);
      }
    }
    // 削除済みなど_childrenに存在しないpersonIdのTodoがあれば末尾に追加
    final orphanIds = ids.difference(_children.map((c) => c.id).toSet());
    if (orphanIds.isNotEmpty) {
      names.addAll(orphanIds.map((_) => '?'));
    }
    return names;
  }

  PersonProfile? personById(String? id) {
    if (id == null) return null;
    return _children.where((c) => c.id == id).firstOrNull;
  }

  DocumentRecord? documentById(String? id) {
    if (id == null) return null;
    return _documents.where((d) => d.id == id).firstOrNull;
  }

  // preparedDate付きのソート: 子ども登録順→personId nullは最後→期限順→作成日順
  int _prepSort(AppTodo a, AppTodo b) {
    final aIdx = a.personId != null
        ? _children.indexWhere((c) => c.id == a.personId)
        : -1;
    final bIdx = b.personId != null
        ? _children.indexWhere((c) => c.id == b.personId)
        : -1;
    if (a.personId == null && b.personId != null) return 1;
    if (a.personId != null && b.personId == null) return -1;
    if (aIdx != bIdx) return aIdx.compareTo(bIdx);
    final ad = a.dueDate;
    final bd = b.dueDate;
    if (ad == null && bd == null) return a.createdAt.compareTo(b.createdAt);
    if (ad == null) return 1;
    if (bd == null) return -1;
    final d = ad.compareTo(bd);
    if (d != 0) return d;
    return a.createdAt.compareTo(b.createdAt);
  }

  // 人物に割り当てる色のパレット（視覚的に離れた色）
  static const _personColors = <Color>[
    Color(0xFFE53935), // 赤
    Color(0xFF1E88E5), // 青
    Color(0xFF43A047), // 緑
    Color(0xFFFB8C00), // 橙
    Color(0xFF8E24AA), // 紫
    Color(0xFF00ACC1), // シアン
    Color(0xFFD81B60), // ピンク
    Color(0xFF3949AB), // インジゴ
    Color(0xFF6D4C41), // 茶
    Color(0xFF546E7A), // 青灰
  ];

  // ── 人物 CRUD ──────────────────────────────────────────

  int _assignPersonColor() {
    final usedColors = _children.map((c) => c.colorValue).toSet();
    for (final color in _personColors) {
      if (!usedColors.contains(color.toARGB32())) return color.toARGB32();
    }
    // 全色使用中 → パレットをローテーション
    return _personColors[_children.length % _personColors.length].toARGB32();
  }

  Future<PersonProfile> addChild(String name) async {
    final now = DateTime.now();
    final child = PersonProfile(
      id: _uuid.v4(),
      name: name.trim(),
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
    _children = _children.map((e) => e.id == updated.id ? updated : e).toList();
    await _persist();
    notifyListeners();
  }

  // ── ドキュメント CRUD ──────────────────────────────────

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

    final deleted = _documents.where((document) => document.id == id).toList();
    if (deleted.isEmpty) return false;

    _documents = _documents.where((document) => document.id != id).toList();
    await _persist();
    await _deleteDocumentImages(deleted);
    notifyListeners();
    return true;
  }

  // ── Todo CRUD ──────────────────────────────────────────

  Future<AppTodo> addTodoFromDraft({
    required ExtractionDraft draft,
    String? personId,
    String? documentId,
    bool notifyPreviousNight = true,
    bool notifySameMorning = true,
  }) async {
    final now = DateTime.now();
    final todo = AppTodo(
      id: _uuid.v4(),
      title: draft.title.trim().isEmpty ? 'プリントを確認' : draft.title.trim(),
      personId: personId,
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
    await _safeSchedule(todo);
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
    _todos = _todos.map((e) => e.id == updated.id ? updated : e).toList();
    await _persist();
    if (rescheduleNotification) {
      await _safeSchedule(updated);
    }
    notifyListeners();
  }

  Future<void> toggleTodoDone(String id) async {
    final todo = _todos.where((e) => e.id == id).firstOrNull;
    if (todo == null) return;
    final updated = todo.copyWith(
      status: todo.status == TodoStatus.done
          ? TodoStatus.active
          : TodoStatus.done,
      updatedAt: DateTime.now(),
    );
    _todos = _todos.map((e) => e.id == id ? updated : e).toList();
    await _persist();
    if (updated.isDone) {
      await _safeCancel(updated.id);
    } else {
      await _safeSchedule(updated);
    }
    notifyListeners();
  }

  /// Todoを準備済みにする。
  /// statusは変更せず、通知もキャンセルしない。
  Future<void> markTodoPrepared(String todoId, DateTime date) async {
    final todo = _todos.where((e) => e.id == todoId).firstOrNull;
    if (todo == null) return;
    final d = DateTime(date.year, date.month, date.day);
    await _updateTodo(
      todo.copyWith(preparedDate: d, updatedAt: DateTime.now()),
      rescheduleNotification: false,
    );
  }

  /// Todoの準備済みを解除する。
  Future<void> clearTodoPrepared(String todoId) async {
    final todo = _todos.where((e) => e.id == todoId).firstOrNull;
    if (todo == null) return;
    await _updateTodo(
      todo.copyWith(clearPreparedDate: true, updatedAt: DateTime.now()),
      rescheduleNotification: false,
    );
  }

  Future<void> toggleItem(String todoId, String itemId) async {
    final todo = _todos.where((e) => e.id == todoId).firstOrNull;
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
    await _safeCancel(id);
    await _deleteDocumentImages(orphanDocuments);
    notifyListeners();
  }

  /// 複数の ExtractionDraft を一括追加する。
  ///
  /// メモリ上の更新と DB 保存を1回にまとめ、N+1 問題を回避する。
  /// 通知は各 Todo に対して個別に予約する。
  Future<List<AppTodo>> addTodosFromDrafts({
    required List<ExtractionDraft> drafts,
    String? personId,
    String? documentId,
    bool notifyPreviousNight = true,
    bool notifySameMorning = true,
  }) async {
    final now = DateTime.now();
    final todos = <AppTodo>[];
    for (final draft in drafts) {
      final todo = AppTodo(
        id: _uuid.v4(),
        title: draft.title.trim().isEmpty ? 'プリントを確認' : draft.title.trim(),
        personId: personId,
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
      todos.add(todo);
    }
    _todos = [..._todos, ...todos];
    await _persist();
    for (final todo in todos) {
      await _safeSchedule(todo);
    }
    notifyListeners();
    return todos;
  }

  // ── 通知 ──────────────────────────────────────────────

  Future<void> rescheduleAllNotifications() async {
    for (final todo in _todos) {
      await _safeSchedule(todo);
    }
  }

  // ── 全データクリア ──────────────────────────────────────

  Future<void> clearAllData() async {
    final documentsToDelete = List<DocumentRecord>.from(_documents);
    final todosToCancel = List<AppTodo>.from(_todos);
    _children = [];
    _todos = [];
    _documents = [];
    await _store.clear();
    for (final todo in todosToCancel) {
      await _safeCancel(todo.id);
    }
    await _deleteDocumentImages(documentsToDelete);
    notifyListeners();
  }

  // ── 内部ヘルパー ──────────────────────────────────────

  List<DocumentRecord> _cleanupOrphanDocuments() {
    final usedDocIds = _todos
        .map((t) => t.documentId)
        .whereType<String>()
        .toSet();
    final orphanDocuments = _documents
        .where((d) => !usedDocIds.contains(d.id))
        .toList();
    _documents = _documents.where((d) => usedDocIds.contains(d.id)).toList();
    return orphanDocuments;
  }

  Future<void> _deleteDocumentImages(List<DocumentRecord> documents) async {
    await Future.wait(
      documents.where((d) => d.localImagePath != null && d.localImagePath!.isNotEmpty).map(
        (d) => ImageFileService.deleteIfExists(d.localImagePath!).catchError((_) {
          if (kDebugMode) debugPrint('AppState error: failed to delete document image');
        }),
      ),
    );
  }

  /// 未保存状態で画面破棄時にドキュメントを削除する。
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
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to clean up document: $e');
    }
  }

  Future<void> _persist() {
    return _store.save(
      AppSnapshot(children: _children, todos: _todos, documents: _documents),
    );
  }

  Future<void> _safeSchedule(AppTodo todo) async {
    try {
      await _notifications.scheduleTodo(todo);
    } on Object catch (e, s) {
      if (kDebugMode) debugPrint('AppState: failed to schedule notification: $e\n$s');
    }
  }

  Future<void> _safeCancel(String todoId) async {
    try {
      await _notifications.cancelTodo(todoId);
    } on Object catch (e, s) {
      if (kDebugMode) debugPrint('AppState: failed to cancel notification: $e\n$s');
    }
  }
}
