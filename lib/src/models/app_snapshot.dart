// lib/src/models/app_snapshot.dart
// アプリ全体の状態スナップショット（子ども一覧、Todo一覧、書類一覧＋マイグレーション）。
// 全データの保存・復元を一手に担うルートモデル。
// 関連: entities.dart, child_profile.dart, app_todo.dart, document_record.dart

import 'package:flutter/foundation.dart';
import 'person_profile.dart';
import 'app_todo.dart';
import 'document_record.dart';

@immutable
class AppSnapshot {
  const AppSnapshot({
    required this.children,
    required this.todos,
    required this.documents,
    this.version = currentVersion,
  });

  final List<PersonProfile> children;
  final List<AppTodo> todos;
  final List<DocumentRecord> documents;
  final int version;

  static const currentVersion = 1;
  static const empty = AppSnapshot(children: [], todos: [], documents: []);

  AppSnapshot migrate() {
    var migrated = this;
    if (version < 1) {
      // v0→v1: どのTodoからも参照されていない孤立ドキュメントを削除
      final activeDocIds = migrated.todos
          .map((t) => t.documentId)
          .whereType<String>()
          .toSet();
      migrated = AppSnapshot(
        children: migrated.children,
        todos: migrated.todos,
        documents: migrated.documents.where((d) => activeDocIds.contains(d.id)).toList(),
        version: 1,
      );
    }
    return migrated;
  }

  Map<String, dynamic> toJson() => {
        'version': currentVersion,
        'children': children.map((e) => e.toJson()).toList(),
        'todos': todos.map((e) => e.toJson()).toList(),
        'documents': documents.map((e) => e.toJson()).toList(),
      };

  factory AppSnapshot.fromJson(Map<String, dynamic> json) => AppSnapshot(
        version: json['version'] as int? ?? 0,
        children: (json['children'] as List<dynamic>? ?? const [])
            .map((e) => PersonProfile.fromJson(e as Map<String, dynamic>))
            .toList(),
        todos: (json['todos'] as List<dynamic>? ?? const [])
            .map((e) => AppTodo.fromJson(e as Map<String, dynamic>))
            .toList(),
        documents: (json['documents'] as List<dynamic>? ?? const [])
            .map((e) => DocumentRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
