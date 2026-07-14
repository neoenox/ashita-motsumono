# Android通知受け入れ検証レポート

PR: [#111](https://github.com/kaenozu/ashita-motsumono/pull/111)
Branch: `agent/full-review-hardening`
Base: `master`

- Validated code HEAD: (テスト・format実行時点のSHA — 本文末尾参照)
- Evidence commit / current PR HEAD: (コミット後に再取得 — 本文末尾参照)

検証日: 2026-07-14

## 判定

**CONDITIONAL PASS — static and automated validation only**

静的コード確認および自動テストは完了。Androidランタイム上の通知受け入れ検証は未実施。

## 検証結果サマリー

| 検証項目 | 状態 | 根拠 |
|---|---|---|
| flutter analyze | AUTOMATED TEST PASS | エラー0件 (info 33件のみ) |
| flutter test | AUTOMATED TEST PASS | 全263件通過 |
| dart format (PR変更対象) | AUTOMATED TEST PASS | PR変更Dartファイルはformat済み |
| dart format (全体) | NOT APPLICABLE | Base由来の既存format負債46件あり — 本PRで一括整備しない |
| CI (Flutter CI) | AUTOMATED TEST PASS | analyze-and-test SUCCESS |
| レビュー | 解決済み | 未解決スレッド0件 |
| 通常通知 (実機) | NOT EXECUTED | デバイスなし |
| 再起動後通知 (実機) | NOT EXECUTED | デバイスなし |
| adb install -r (実機) | NOT EXECUTED | デバイスなし |

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
- AndroidScheduleMode.inexactAllowWhileIdle: Doze中でも通知許可

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

## 異常系の確認

| 項目 | 確認方法 | 状態 |
|---|---|---|
| 通知権限拒否時にクラッシュしない | 静的コード確認: 権限リクエストが例外を握り潰さない設計 | STATIC VERIFIED |
| 過去時刻の通知を登録しない | 静的コード確認 + テスト: _scheduleIfFuture() がスキップ | AUTOMATED TEST PASS |
| 完了済みTodoの通知を取消できる | 静的コード確認: buildScheduleRequests() が isDone スキップ | STATIC VERIFIED |
| Todo削除後に通知が残らない | 静的コード確認: deleteTodo() が cancel キュー登録 | STATIC VERIFIED |
| 通知取消失敗時に再試行キューへ残る | テスト: _recordFailure() で永続化を確認 | AUTOMATED TEST PASS |
| アプリ再起動後に再試行キューが処理される | テスト: retryPendingSideEffects() | AUTOMATED TEST PASS |
| 通知IDシード衝突時に別IDが割り当てられる | テスト: notification ID allocation skips occupied seed | AUTOMATED TEST PASS |
| DB読み込み失敗時に空データで通常起動しない | テスト: _writesBlocked + 復旧UI | AUTOMATED TEST PASS |
| DB初期化失敗時に復旧画面へ戻れる | テスト: BootstrapApp _phase 管理 | AUTOMATED TEST PASS |
| DB部分削除失敗が適切に報告される | テスト: deleteDatabaseFilesAtPath 失敗集約 | AUTOMATED TEST PASS |
| 通知プラグイン未初期化時のテスト安全性 | テスト: FakeNotificationService で実プラグイン到達を防止 | AUTOMATED TEST PASS |

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
- タイムゾーン自動検出のフォールバック (Asia/Tokyo) が正しいか
- Base由来のdart format負債 (46ファイル) がCIで未チェック — 本PRで一括整備しない
