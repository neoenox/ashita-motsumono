// lib/src/services/app_settings.dart
// SharedPreferences で通知時刻などのアプリ設定を管理する。
// 関連: settings_screen.dart, notification_service.dart, main.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs)
    : _learnedItemLabels = List<String>.of(
        _prefs.getStringList(_keyLearnedItemLabels) ?? const <String>[],
      );

  final SharedPreferences _prefs;
  List<String> _learnedItemLabels;

  int get previousNightHour =>
      _prefs.getInt(_keyPreviousNightHour) ?? defaultPreviousNightHour;
  int get previousNightMinute =>
      _prefs.getInt(_keyPreviousNightMinute) ?? defaultPreviousNightMinute;
  int get sameMorningHour =>
      _prefs.getInt(_keySameMorningHour) ?? defaultSameMorningHour;
  int get sameMorningMinute =>
      _prefs.getInt(_keySameMorningMinute) ?? defaultSameMorningMinute;

  ThemeMode get themeMode => switch (_prefs.getString(_keyThemeMode)) {
    'dark' => ThemeMode.dark,
    'light' => ThemeMode.light,
    _ => ThemeMode.system,
  };

  /// 広告除去購入済みなら true
  bool get adRemoved => _prefs.getBool(_keyAdRemoved) ?? false;

  /// AI分析購入済みなら true
  bool get aiAccess => _prefs.getBool(_keyAiAccess) ?? false;

  /// ロック画面を含む通知本文にTodoの詳細を表示するか。
  /// プライバシー保護のため既定値は false。
  bool get showNotificationDetails =>
      _prefs.getBool(_keyShowNotificationDetails) ?? false;

  List<String> get learnedItemLabels =>
      List<String>.unmodifiable(_learnedItemLabels);

  static const defaultPreviousNightHour = 20;
  static const defaultPreviousNightMinute = 0;
  static const defaultSameMorningHour = 7;
  static const defaultSameMorningMinute = 0;

  static const _keyThemeMode = 'theme_mode';
  static const _keyPreviousNightHour = 'notification_previous_night_hour';
  static const _keyPreviousNightMinute = 'notification_previous_night_minute';
  static const _keySameMorningHour = 'notification_same_morning_hour';
  static const _keySameMorningMinute = 'notification_same_morning_minute';
  static const _keyShowNotificationDetails = 'notification_show_details';
  static const _keyAdRemoved = 'purchase_ad_removed';
  static const _keyAiAccess = 'purchase_ai_access';
  static const _keyLearnedItemLabels = 'learned_item_labels_v1';

  Future<void> setPreviousNightTime(int hour, int minute) async {
    await _prefs.setInt(_keyPreviousNightHour, hour);
    await _prefs.setInt(_keyPreviousNightMinute, minute);
    notifyListeners();
  }

  Future<void> setSameMorningTime(int hour, int minute) async {
    await _prefs.setInt(_keySameMorningHour, hour);
    await _prefs.setInt(_keySameMorningMinute, minute);
    notifyListeners();
  }

  Future<void> setShowNotificationDetails(bool enabled) async {
    await _prefs.setBool(_keyShowNotificationDetails, enabled);
    notifyListeners();
  }

  Future<void> setAdRemoved(bool removed) async {
    await _prefs.setBool(_keyAdRemoved, removed);
    notifyListeners();
  }

  Future<void> setAiAccess(bool enabled) async {
    await _prefs.setBool(_keyAiAccess, enabled);
    notifyListeners();
  }

  Future<void> addLearnedItemLabels(Iterable<String> labels) async {
    final incoming = labels
        .map((label) => label.trim())
        .where(_isUsefulItemLabel);
    final merged = <String>{
      ...incoming,
      ..._learnedItemLabels,
    }.take(100).toList(growable: false);
    await _prefs.setStringList(_keyLearnedItemLabels, merged);
    _learnedItemLabels = merged;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final raw = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    };
    await _prefs.setString(_keyThemeMode, raw);
    notifyListeners();
  }

  Future<void> clearLearnedItemLabels() async {
    final previous = _learnedItemLabels;
    _learnedItemLabels = const <String>[];
    notifyListeners();
    try {
      await _prefs.setStringList(_keyLearnedItemLabels, const <String>[]);
    } on Object {
      _learnedItemLabels = previous;
      notifyListeners();
      rethrow;
    }
  }

  static bool _isUsefulItemLabel(String label) {
    if (label.isEmpty) return false;
    if (label.length > 32) return false;
    return true;
  }
}
