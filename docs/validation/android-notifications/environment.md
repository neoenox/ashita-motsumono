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

- 接続数: 0 (2026-07-14確認)
- adb devices -l 出力: 空
- 実機/Emulator検証は実施不可

## リポジトリ情報

- Clone先: <WORKTREE>
- Branch: agent/full-review-hardening
- Base at validation: `f4fe4fadd774e6448cb08a751586579f70403a34`
- CI-validated PR HEAD: `d40f591745051ad6feab82a86221eb0d648d7ead`
- CI-tested pull-request merge commit: `bd261d53e13e2585f1cfb3e521589666e2f3051f`
- Flutter CI #754, run id: `29298500627`
- Application ID: com.ashita_motsumono
- pubspec version: 0.6.3+2
- minSdk: 24
- targetSdk: flutter.targetSdkVersion
- compileSdk: flutter.compileSdkVersion

## CI結果 (Flutter CI #754)

- analyze-and-test: SUCCESS
- Analyze step: SUCCESS
- Test step: SUCCESS
- release-build: SKIPPED (PR向け)
- GitGuardian Security Checks: SUCCESS

GitHub Actionsのpull_request実行はPR HEADそのものではなく、Baseとの一時merge commitをcheckoutする。本証跡ではPR HEADと実際にテストされたmerge commitを分離して記録する。

## テスト結果

- flutter test: 263件通過
- flutter analyze: エラー0件 (info 33件のみ)
- dart format (PR変更対象): PASS — 変更Dartファイルはformat済み
- dart format (全体): 50ファイルに差分 — うち46件はBase由来の既存format負債
- Base format負債: Issue #112で分離管理

## テスト証跡の扱い

- 以前の`logs/flutter-test.txt`はFakeNotificationService導入前のローカルログを含んでいたため、最終実装の証跡から除外した。
- 置換後のファイルはFlutter CI #754のジョブ・ステップ結果を示す正規化サマリーであり、GitHub Actionsの生ログ全文の複製ではない。
- FakeNotificationService導入後の実装は、対象テストからプラットフォーム通知プラグインへの到達を防止する。

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
