// lib/src/services/export_service.dart
// データエクスポート用のヘルパー。画像パスを除外して JSON 化可能なスナップショットを生成する。
// 関連: screens/home_screen.dart, models/entities.dart

import '../app_state.dart';
import '../models/entities.dart';

AppSnapshot createExportSnapshot(AppState state) {
  return AppSnapshot(
    children: state.children,
    todos: state.todos,
    documents: state.documents
        .map((d) => d.copyWith(clearLocalImagePath: true))
        .toList(),
  );
}
