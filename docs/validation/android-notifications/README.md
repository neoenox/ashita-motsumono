# Android通知受け入れ検証レポート

PR: [#111](https://github.com/kaenozu/ashita-motsumono/pull/111)
Branch: `agent/full-review-hardening`
Base: `master`
HEAD: `5a64ff35aa3eebf5f1682da6459560a2e1d4cbb7`
検証日: 2026-07-14

## 判定

**CONDITIONAL PASS**

コードレベル検証は完了。実機検証はデバイス/Emulator接続なしのため未実施。

## 検証結果サマリー

| 検証項目 | 状態 | 根拠 |
|---|---|---|
| flutter analyze | PASS | エラー0件 (info 33件のみ) |
| flutter test | PASS | 全263件通過 |
| CI (Flutter CI) | PASS | analyze-and-test SUCCESS |
| レビュー | 解決済み | 未解決スレッド0件 |
| 通常通知 (実機) | 未実施 | デバイスなし |
| 再起動後通知 (実機) | 未実施 | デバイスなし |
| adb install -r (実機) | 未実施 | デバイスなし |

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

## 異常系のコードレベル確認

| 項目 | テスト | 実機 |
|---|---|---|
| 通知権限拒否時にクラッシュしない | PASS (設計確認) | 未実施 |
| 過去時刻の通知を登録しない | PASS (_scheduleIfFuture() スキップ) | 未実施 |
| 完了済みTodoの通知を取消できる | PASS (buildScheduleRequests() が isDone スキップ) | 未実施 |
| Todo削除後に通知が残らない | PASS (deleteTodo() が cancel キュー登録) | 未実施 |
| 通知取消失敗時に再試行キューへ残る | PASS (_recordFailure() 確認) | 未実施 |
| アプリ再起動後に再試行キューが処理される | PASS (retryPendingSideEffects()) | 未実施 |
| 通知IDシード衝突時に別IDが割り当てられる | PASS (テスト: notification ID allocation skips occupied seed) | 未実施 |
| DB読み込み失敗時に空データで通常起動しない | PASS (_writesBlocked + 復旧UI) | 未実施 |
| DB初期化失敗時に復旧画面へ戻れる | PASS (BootstrapApp _phase 管理) | 未実施 |
| DB部分削除失敗が適切に報告される | PASS (deleteDatabaseFilesAtPath 失敗集約) | 未実施 |

## 未確認事項

1. 通知権限の実際のプロンプト表示とGRANTED状態 — デバイスなし
2. zonedSchedule による実際の通知到着 — デバイスなし
3. ScheduledNotificationBootReceiver のBOOT_COMPLETED応答 — デバイスなし
4. MY_PACKAGE_REPLACED のbroadcast受信 — デバイスなし
5. dumpsys alarm でのAlarm登録確認 — デバイスなし
6. Dozeモードでの通知遅延 — デバイスなし

## 残存リスク

- AndroidScheduleMode.inexactAllowWhileIdle により通知時刻に誤差が生じる可能性
- OEM固有のバッテリ最適化により通知が抑制される可能性
- POST_NOTIFICATIONS 権限がAndroid 13+で拒否された場合のUX
- タイムゾーン自動検出のフォールバック (Asia/Tokyo) が正しいか
