# 検証環境

## ホスト

- OS: Windows (MSYS2/Git Bash)
- Flutter: 3.44.0 (stable)
- Dart: included in Flutter 3.44.0
- Git: available
- GitHub CLI: 2.76.0

## Android SDK

- パス: <ANDROID_SDK>
- adb: <ANDROID_SDK>\platform-tools\adb.exe

## Androidデバイス/Emulator

- 接続数: 0 (2026-07-14 17:00 JST確認)
- adb devices -l 出力: 空
- 実機/Emulator検証は実施不可

## リポジトリ情報

- Clone先: <WORKTREE>
- Branch: agent/full-review-hardening
- Validated code HEAD: (テスト・format実行時点のSHA — 本文末尾参照)
- Current PR HEAD at final verification: (コミット後に再取得 — 本文末尾参照)
- Application ID: com.ashita_motsumono
- pubspec version: 0.6.3+2
- minSdk: 24
- targetSdk: flutter.targetSdkVersion
- compileSdk: flutter.compileSdkVersion

## CI結果 (Flutter CI)

- analyze-and-test: SUCCESS
- release-build: SKIPPED (PR向け)
- GitGuardian Security Checks: SUCCESS

## テスト結果

- flutter test: 263件通過 (LateInitializationErrorなし)
- flutter analyze: エラー0件 (info 33件のみ)
- dart format (PR変更対象): PASS — 変更Dartファイルはformat済み
- dart format (全体): 50ファイルに差分 — うち46件はBase由来の既存format負債

## 通知関連の設定

### AndroidManifest.xml

権限:
- POST_NOTIFICATIONS: 宣言済み
- RECEIVE_BOOT_COMPLETED: 宣言済み

Receiver:
- ScheduledNotificationReceiver (exported=false)
- ScheduledNotificationBootReceiver (exported=false)
  - BOOT_COMPLETED, MY_PACKAGE_REPLACED, QUICKBOOT_POWERON

### 通知プラグイン

- flutter_local_notifications: ^22.0.1
- flutter_timezone: ^5.1.0
- timezone: ^0.11.1

### 通知スケジュール設定

- デフォルト前日夜通知: 20:00
- デフォルト当日朝通知: 07:00
- タイムゾーン: 端末自動検出、フォールバック Asia/Tokyo
- スケジュールモード: AndroidScheduleMode.inexactAllowWhileIdle
