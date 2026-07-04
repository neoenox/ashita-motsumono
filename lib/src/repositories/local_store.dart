// lib/src/repositories/local_store.dart
// SharedPreferences を使った JSON 永続化。AppSnapshot 全体を1つのキーに保存する。
// v0.2 で Drift/SQLite に差し替える想定。
// 関連: models/entities.dart, app_state.dart

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/entities.dart';

class LocalStore {
  LocalStore(this._preferences);

  static const _key = 'ashita_motsumono_snapshot_v1';
  static const _corruptBackupKey = 'ashita_motsumono_snapshot_corrupt_backup_v1';
  final SharedPreferences _preferences;

  bool _lastLoadHadCorruptData = false;
  bool get lastLoadHadCorruptData => _lastLoadHadCorruptData;

  static Future<LocalStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    return LocalStore(preferences);
  }

  AppSnapshot load() {
    _lastLoadHadCorruptData = false;
    final raw = _preferences.getString(_key);
    if (raw == null || raw.trim().isEmpty) {
      return AppSnapshot.empty;
    }
    try {
      final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
      return AppSnapshot.fromJson(jsonMap).migrate();
    } on Object {
      _lastLoadHadCorruptData = true;
      unawaited(_preferences.setString(_corruptBackupKey, raw));
      return AppSnapshot.empty;
    }
  }

  Future<void> save(AppSnapshot snapshot) async {
    await _preferences.setString(_key, jsonEncode(snapshot.toJson()));
  }

  String? loadCorruptBackup() => _preferences.getString(_corruptBackupKey);

  Future<void> clear() => _preferences.remove(_key);
}
