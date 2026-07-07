// lib/src/services/app_settings.dart
// SharedPreferences で通知時刻などのアプリ設定を管理する。
// 関連: settings_screen.dart, notification_service.dart, main.dart

import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  AppSettings(this._prefs);

  final SharedPreferences _prefs;

  int get previousNightHour => _prefs.getInt(_keyPreviousNightHour) ?? defaultPreviousNightHour;
  int get previousNightMinute => _prefs.getInt(_keyPreviousNightMinute) ?? defaultPreviousNightMinute;
  int get sameMorningHour => _prefs.getInt(_keySameMorningHour) ?? defaultSameMorningHour;
  int get sameMorningMinute => _prefs.getInt(_keySameMorningMinute) ?? defaultSameMorningMinute;

  /// 広告除去購入済みなら true
  bool get adRemoved => _prefs.getBool(_keyAdRemoved) ?? false;

  static const defaultPreviousNightHour = 20;
  static const defaultPreviousNightMinute = 0;
  static const defaultSameMorningHour = 7;
  static const defaultSameMorningMinute = 0;

  static const _keyPreviousNightHour = 'notification_previous_night_hour';
  static const _keyPreviousNightMinute = 'notification_previous_night_minute';
  static const _keySameMorningHour = 'notification_same_morning_hour';
  static const _keySameMorningMinute = 'notification_same_morning_minute';
  static const _keyAdRemoved = 'purchase_ad_removed';

  Future<void> setPreviousNightTime(int hour, int minute) async {
    await _prefs.setInt(_keyPreviousNightHour, hour);
    await _prefs.setInt(_keyPreviousNightMinute, minute);
  }

  Future<void> setSameMorningTime(int hour, int minute) async {
    await _prefs.setInt(_keySameMorningHour, hour);
    await _prefs.setInt(_keySameMorningMinute, minute);
  }

  Future<void> setAdRemoved(bool removed) async {
    await _prefs.setBool(_keyAdRemoved, removed);
  }
}
