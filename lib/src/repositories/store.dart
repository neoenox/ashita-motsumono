// lib/src/repositories/store.dart
// 永続化ストアの共通インターフェース。DriftStore が実装する。
// 関連: drift_store.dart, app_state.dart

import '../models/entities.dart';

abstract class Store {
  Future<AppSnapshot> load();
  Future<void> save(AppSnapshot snapshot);
  String? loadCorruptBackup();
  Future<void> clear();
  bool get lastLoadHadCorruptData;
}
