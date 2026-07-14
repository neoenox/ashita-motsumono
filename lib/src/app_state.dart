// lib/src/app_state.dart
// アプリ状態ファサード。状態別Notifierと永続化順序を統括する。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'models/entities.dart';
import 'repositories/store.dart';
import 'services/document_image_cleaner.dart';
import 'services/notification_coordinator.dart';
import 'services/notification_service.dart';
import 'services/todo_factory.dart';
import 'state/app_data_notifiers.dart';

part 'app_state_children.dart';
part 'app_state_documents.dart';
part 'app_state_todos.dart';
part 'app_state_cleanup.dart';

int _sortTodo(AppTodo a, AppTodo b) {
  final firstDate = a.dueDate;
  final secondDate = b.dueDate;
  if (firstDate == null && secondDate == null) {
    return a.createdAt.compareTo(b.createdAt);
  }
  if (firstDate == null) return 1;
  if (secondDate == null) return -1;
  final dateOrder = firstDate.compareTo(secondDate);
  if (dateOrder != 0) return dateOrder;
  return a.createdAt.compareTo(b.createdAt);
}

class AppState extends ChangeNotifier {
  AppState({
    required Store store,
    required NotificationService notifications,
    Uuid? uuid,
  }) : _store = store,
       _notifications = notifications,
       _uuid = uuid ?? const Uuid() {
    // 既存のcontext.watch<AppState>()は人物選択UIとの互換用に限定する。
    childState.addListener(notifyListeners);
  }

  final Store _store;
  final NotificationService _notifications;
  final Uuid _uuid;

  final ChildState childState = ChildState();
  final TodoState todoState = TodoState();
  final DocumentState documentState = DocumentState();

  late final TodoFactory _todoFactory = TodoFactory(_uuid);
  late final NotificationCoordinator _notificationCoordinator =
      NotificationCoordinator(_notifications, _store);
  final DocumentImageCleaner _documentImageCleaner =
      const DocumentImageCleaner();

  bool _loaded = false;
  Future<void>? _closeFuture;

  bool get loaded => _loaded;
  bool get lastLoadHadCorruptData => _store.lastLoadHadCorruptData;

  List<PersonProfile> get children => childState.children;
  List<AppTodo> get todos => todoState.todos;
  List<DocumentRecord> get documents => documentState.documents;

  Future<void> load() async {
    final snapshot = await _store.load();
    childState.replace(snapshot.children);
    todoState.replace(snapshot.todos);
    documentState.replace(snapshot.documents);
    _loaded = true;
    notifyListeners();
  }

  Future<void> requestNotificationPermissions() {
    return _notificationCoordinator.requestPermissions();
  }

  String? loadCorruptBackup() => _store.loadCorruptBackup();

  List<AppTodo> todosForDate(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    return todos
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
    return todos
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
    return todos
        .where(
          (todo) => todo.status == TodoStatus.active && todo.dueDate == null,
        )
        .toList()
      ..sort(_sortTodo);
  }

  PersonProfile? personById(String? id) {
    if (id == null) return null;
    return children.where((child) => child.id == id).firstOrNull;
  }

  DocumentRecord? documentById(String? id) {
    if (id == null) return null;
    return documents.where((document) => document.id == id).firstOrNull;
  }

  void _replaceChildren(Iterable<PersonProfile> values) {
    childState.replace(values);
  }

  void _replaceTodos(Iterable<AppTodo> values) {
    todoState.replace(values);
  }

  void _replaceDocuments(Iterable<DocumentRecord> values) {
    documentState.replace(values);
  }

  Future<void> _persistSnapshot({
    Iterable<PersonProfile>? nextChildren,
    Iterable<AppTodo>? nextTodos,
    Iterable<DocumentRecord>? nextDocuments,
    Map<String, NotificationSyncOperation> notificationOperations = const {},
    Iterable<String> cleanupPaths = const [],
  }) {
    return _store.saveWithSideEffects(
      AppSnapshot(
        children: List<PersonProfile>.of(nextChildren ?? children),
        todos: List<AppTodo>.of(nextTodos ?? todos),
        documents: List<DocumentRecord>.of(nextDocuments ?? documents),
      ),
      notificationOperations: notificationOperations,
      cleanupPaths: cleanupPaths,
    );
  }

  Future<void> _retryPendingFileCleanup() async {
    final paths = await _store.loadPendingFileCleanup();
    for (final path in paths) {
      try {
        await _documentImageCleaner.deletePath(path);
        await _store.markFileCleanupComplete(path);
      } on Object catch (error, stackTrace) {
        try {
          await _store.markFileCleanupFailed(path, error);
        } on Object catch (queueError, queueStackTrace) {
          if (kDebugMode) {
            debugPrint(
              'File cleanup: failed to persist retry state: '
              '$queueError\n$queueStackTrace',
            );
          }
        }
        if (kDebugMode) {
          debugPrint('File cleanup failed: $error\n$stackTrace');
        }
      }
    }
  }

  Future<void> retryPendingSideEffects() async {
    await _notificationCoordinator.retryPending(todos);
    await _retryPendingFileCleanup();
  }

  /// DBを一度だけ閉じる。再初期化前はこのFutureを待ってclose/open競合を防ぐ。
  Future<void> close() {
    return _closeFuture ??= _store.close();
  }

  @override
  void dispose() {
    childState.removeListener(notifyListeners);
    childState.dispose();
    todoState.dispose();
    documentState.dispose();
    unawaited(close());
    super.dispose();
  }
}
