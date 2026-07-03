// lib/src/repositories/local_store.dart
// SharedPreferences を使った JSON 永続化。AppSnapshot 全体を1つのキーに保存する。
// v0.2 で Drift/SQLite に差し替える想定。
// 関連: models/entities.dart, app_state.dart

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/entities.dart';

class LocalStore {
  LocalStore(this._preferences);

  static const _key = 'ashita_motsumono_snapshot_v1';
  final SharedPreferences _preferences;

  static Future<LocalStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    return LocalStore(preferences);
  }

  AppSnapshot load() {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.trim().isEmpty) {
      return AppSnapshot.empty;
    }
    try {
      final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
      return AppSnapshot.fromJson(jsonMap).migrate();
    } on Object {
      return AppSnapshot.empty;
    }
  }

  Future<void> save(AppSnapshot snapshot) async {
    await _preferences.setString(_key, jsonEncode(snapshot.toJson()));
  }

  Future<void> clear() => _preferences.remove(_key);
}
