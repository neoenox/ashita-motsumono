# Android通知受け入れ検証レポート

PR: [#111](https://github.com/kaenozu/ashita-motsumono/pull/111)
Branch: `agent/full-review-hardening`
Base: `master`

- CI-validated PR HEAD: `d40f591745051ad6feab82a86221eb0d648d7ead`
- CI-tested pull-request merge commit: `bd261d53e13e2585f1cfb3e521589666e2f3051f`
- Authoritative CI: Flutter CI #754, run id `29298500627`
- Evidence correction parent HEAD: `d40f591745051ad6feab82a86221eb0d648d7ead`
- Evidence correction commit: Git履歴で管理し、文書自身への自己参照SHAは埋め込まない

検証日: 2026-07-14

## 判定

**CONDITIONAL PASS — static and automated validation only**

静的コード確認および自動テストは完了。Androidランタイム上の通知受け入れ検証は未実施。

## 証跡の適用範囲

- Flutter CI #754はPR HEAD `d40f591745051ad6feab82a86221eb0d648d7ead`に対応するpull-request merge commit `bd261d53e13e2585f1cfb3e521589666e2f3051f`を検証した。
- GitHub Actionsの`analyze-and-test`ジョブ、Analyzeステップ、TestステップはいずれもSUCCESS。
- 以前コミットされていた`logs/flutter-test.txt`はFake導入前のローカル実行ログを含み、最終実装の証跡として不適切だったため、CI結果を示す正規化サマリーへ置換した。
- ローカル検証で使用した複数の中間SHAは一意に追跡できないため、権威ある検証基準には使用しない。

## 検証結果サマリー

| 検証項目 | 状態 | 根拠 |
|---|---|---|
| flutter analyze | AUTOMATED TEST PASS | Flutter CI #754 AnalyzeステップSUCCESS。ローカル結果はエラー0件、info 33件 |
| flutter test | AUTOMATED TEST PASS | Flutter CI #754 TestステップSUCCESS。263件通過 |
| dart format (PR変更対象) | AUTOMATED TEST PASS | PR変更Dartファイルはformat済み |
| dart format (全体) | BASE DEBT | Base由来の既存format負債46件。Issue #112で分離管理 |
| CI (Flutter CI) | AUTOMATED TEST PASS | run #754 / id `29298500627`、analyze-and-test SUCCESS |
| レビュー | 解決済み | 未解決スレッド0件 |
| 通常通知 (Androidランタイム) | NOT EXECUTED | 接続デバイスなし |
| 再起動後通知 (Androidランタイム) | NOT EXECUTED | 接続デバイスなし |
| adb install -r (Androidランタイム) | NOT EXECUTED | 接続デバイスなし |

## コードレベルで確認できた事実

### Manifest設定

- POST_NOTIFICATIONS 権限: 宣言済み
- RECEIVE_BOOT_COMPLETED 権限: 宣言済み
- ScheduledNotificationReceiver (exported=false): 登録済み
- ScheduledNotificationBootReceiver (exported=false): 登録済み
  - BOOT_COMPLETED, MY_PACKAGE_REPLACED, QUICKBOOT_POWERON を受信

### 通知スケジュール

- buildScheduleRequests(): 前日夜(20:00)と当日朝(07:00)の通知を構築
- _scheduleIfFuture(): 過去時刻をスキップ
- AndroidScheduleMode.inexactAllowWhileIdleを使用

### 再起動時リスケジュール

- ScheduledNotificationBootReceiver が BOOT_COMPLETED でプラグイン内Alarm復元
- bootstrap_app.dart の _markReady() で rescheduleAllNotifications() 呼出
- rescheduleAllNotifications() → retryPendingSideEffects() → rescheduleAll()

### 通知ID永続化

- notification_id_map テーブルに todo_id → (kind, notification_id) を保存
- 衝突時に使用済みID Set をメモリで探索 (最大 usedIds.length + 1 回)
- Todo削除時に releaseNotificationIds() でID解放

### DB永続化

- deleteDatabaseFiles(): 各ファイルを個別try-catchで削除、失敗を集約して報告
- backupDatabaseFile(): DB破損時に退避コピーを作成
- StoreLoadException 発生時は復旧UI表示、空データでの通常起動はしない

### テスト分離

- app_state_notifier_scope_test.dart と widget_test.dart はFakeNotificationServiceを使用
- initialize() / requestPermissions() / scheduleTodo() / cancelTodo()をFakeでオーバーライド
- 対象テストから実FlutterLocalNotificationsPluginへ到達しない

## 異常系の確認

| 項目 | 確認方法 | 状態 |
|---|---|---|
| 通知権限拒否時にクラッシュしない | 静的コード確認 | STATIC VERIFIED |
| 過去時刻の通知を登録しない | 静的コード確認 + テスト | AUTOMATED TEST PASS |
| 完了済みTodoを通知対象にしない | 静的コード確認 | STATIC VERIFIED |
| Todo削除後の通知取消を登録する | 静的コード確認 | STATIC VERIFIED |
| 通知取消失敗時に再試行キューへ残る | テスト | AUTOMATED TEST PASS |
| アプリ再起動後に再試行キューが処理される | テスト | AUTOMATED TEST PASS |
| 通知IDシード衝突時に別IDが割り当てられる | テスト | AUTOMATED TEST PASS |
| DB読み込み失敗時に空データで通常起動しない | テスト | AUTOMATED TEST PASS |
| DB初期化失敗時に復旧画面へ戻れる | テスト | AUTOMATED TEST PASS |
| DB部分削除失敗が適切に報告される | テスト | AUTOMATED TEST PASS |
| 通知プラグイン未初期化時のテスト安全性 | FakeNotificationServiceの注入 + CI | AUTOMATED TEST PASS |

## 未確認事項 (NOT EXECUTED — デバイスなし)

1. 通知権限の実際のプロンプト表示とGRANTED状態
2. zonedSchedule による実際の通知到着
3. ScheduledNotificationBootReceiver のBOOT_COMPLETED応答
4. MY_PACKAGE_REPLACED のbroadcast受信
5. dumpsys alarm でのAlarm登録確認
6. Dozeモードでの通知遅延

## 残存リスク

- AndroidScheduleMode.inexactAllowWhileIdle により通知時刻に誤差が生じる可能性
- OEM固有のバッテリ最適化により通知が抑制される可能性
- POST_NOTIFICATIONS 権限がAndroid 13+で拒否された場合のUX
- タイムゾーン自動検出のフォールバック (Asia/Tokyo) が端末設定と一致しない可能性
- Base由来のdart format負債46ファイルはIssue #112で分離管理中

## 次のゲート

PRをDraftから解除する前に、最新masterと同一Source SHAでIssue #60のnormal / reboot / install-r実測証跡を取得する。CI成功をAndroidランタイム通知成功として扱わない。
