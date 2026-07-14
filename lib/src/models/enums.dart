// lib/src/models/enums.dart
// Todoのカテゴリ（持ち物/提出/集金/予定/その他）とステータス（未了/完了/アーカイブ）を定義する列挙型。
// AppTodo・ExtractionDraft で使用するため分離。
// 関連: entities.dart, app_todo.dart, extraction_draft.dart

enum TodoCategory {
  item,
  submit,
  payment,
  event,
  other;

  String get label => switch (this) {
    TodoCategory.item => '持ち物',
    TodoCategory.submit => '提出',
    TodoCategory.payment => '集金',
    TodoCategory.event => '予定',
    TodoCategory.other => 'その他',
  };

  static TodoCategory fromName(String? value) {
    return TodoCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TodoCategory.other,
    );
  }
}

enum TodoStatus {
  active,
  done,
  archived;

  static TodoStatus fromName(String? value) {
    return TodoStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TodoStatus.active,
    );
  }
}
