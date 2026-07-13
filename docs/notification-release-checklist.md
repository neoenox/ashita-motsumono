# 通知リリース確認チェックリスト

対象：Android Emulator `emulator-5554`。  
推奨入口：`tool/release_validation_session.ps1`。  
低レベル手順：`docs/ISSUE60_ANDROID_EMULATOR_VALIDATION.md`。

## 共通ゲート

- [ ] 最新`origin/master`から専用worktreeを作成した
- [ ] hostのUTC offsetが`+09:00`
- [ ] `HEAD == origin/master`
- [ ] 追跡対象ファイルにローカル変更がない
- [ ] すべてのADB操作が`-s emulator-5554`経由
- [ ] `ro.kernel.qemu=1`
- [ ] AVD名、Androidバージョン、APIレベル、端末モデルを記録した
- [ ] Emulatorのタイムゾーンが`Asia/Tokyo`
- [ ] `sys.boot_completed=1`
- [ ] Application IDが`com.ashita_motsumono`
- [ ] 通知権限が`GRANTED`
- [ ] APK初期インストールと権限確認後にRelease sessionを開始した
- [ ] Issue #60の集約までmasterへ別PRをマージしない
- [ ] 証跡ルートを`Documents\ashita-release-evidence`へ統一した
- [ ] 各ケースで別の未来Todoを作成した
- [ ] TodoタイトルはASCIIの`NORMAL_*`、`REBOOT_*`、`UPDATE_*`
- [ ] 通知待機中にアプリを再度開いていない

## 各ケースの必須順序

- [ ] Todo作成前に`PlanCase`を実行した
- [ ] Todo作成前のAlarm snapshotを保存した
- [ ] EmulatorでTodoを作成してHomeへ移動した
- [ ] Todo作成後に`BeginCase`を実行した
- [ ] Todo作成後のAlarm snapshotを保存した
- [ ] `alarm-registration.json`を生成した
- [ ] `alarm-registration.json`の`Result=PASS`
- [ ] `AddedLineCount > 0`
- [ ] Todo作成前後のAlarm登録差分を確認した

Alarm登録差分が確認できなければ通知を待たず`INCONCLUSIVE`にする。既存Todoや無関係なAlarmが存在するだけではPASSにしない。

## 必須証跡

各ケースで次を保存する。

- [ ] Todoタイトルと通知設定
- [ ] Source SHA
- [ ] 予定時刻と実到着時刻
- [ ] Todo作成前の`dumpsys alarm`
- [ ] Todo作成後の`dumpsys alarm`
- [ ] `alarm-registration.json`
- [ ] `dumpsys notification --noredact`
- [ ] 通知領域スクリーンショット
- [ ] UI Automator階層またはnotification dump上のTodoタイトル
- [ ] foreground Activity
- [ ] boot ID
- [ ] logcat
- [ ] 待機heartbeat
- [ ] 禁止操作を使用していないこと

## 1. 通常通知

- [ ] Normal用の未来Todoを作成した
- [ ] Alarm登録差分を確認した
- [ ] アプリを開かず通知領域へ表示された
- [ ] タイトル、本文、到着時刻を記録した

判定：

- **PASS**：権限、Alarm登録差分、通知タイトル、通知領域画面、Notification dump、非前面状態、Git gateが揃う
- **FAIL**：予定時刻+20分まで条件を維持したが通知タイトルがない
- **BLOCKED**：ADB切断、PCスリープ、Emulator停止、権限無効、時刻変更などで条件が崩れた
- **INCONCLUSIVE**：Alarm登録差分、時刻、画面、待機継続性などの証跡が不足する

NormalがPASSしなければRebootへ進まない。1回目のFAILではコード変更せず、同じSource SHAの別Todoで1回だけ再現確認する。

## 2. Android Emulator再起動後

- [ ] NormalがPASS済み
- [ ] 別の未来Todoを作成した
- [ ] Alarm登録差分を確認した
- [ ] 再起動前のboot ID、Alarm、時刻を保存した
- [ ] `adb -s emulator-5554 reboot`を実行した
- [ ] `sys.boot_completed=1`まで待った
- [ ] 再起動後のboot IDが変化した
- [ ] 再起動後にアプリを開いていない
- [ ] 再起動後のAlarmを保存した
- [ ] 保存済みTodoの通知が表示された

NormalがPASS済みで、再起動後だけ復元されないことを十分な証跡で示せた場合のみFAILにする。

## 3. APK上書き後

- [ ] RebootがPASS済み
- [ ] 別の未来Todoを作成した
- [ ] Alarm登録差分を確認した
- [ ] 同一application IDのAPK SHA-256を記録した
- [ ] `adb -s emulator-5554 install -r <apk>`が`Success`
- [ ] 更新前後の`lastUpdateTime`を記録した
- [ ] 上書き後にアプリを開いていない
- [ ] 上書き後のAlarmを保存した
- [ ] 保存済みTodoの通知が表示された

判定：

- **PASS**：通知証跡がすべて揃い、`MY_PACKAGE_REPLACED`受信を一意に確認し、Finalizeへ`-InstallBroadcastVerified`を指定した
- **INCONCLUSIVE**：通知到着とinstall成功は確認できたが、同一APKのためbroadcast受信を一意に識別できず、Finalizeへ`-InstallBroadcastUnverified`を指定した
- 通知未到着、Alarm登録差分なし、画面不足などを`InstallBroadcastUnverified`だけでClose候補にしてはいけない

## 4. Issue #60報告

- [ ] 各ケースで`case-result.json`と`issue-comment.md`を生成した
- [ ] 3ケースを`Aggregate`した
- [ ] `issue60-summary.json`と`issue60-summary.md`を生成した
- [ ] 確認済み、未確認、推測、反証、検証範囲、判定根拠を分離した
- [ ] 3ケースのSource SHAが同一
- [ ] `git fetch origin`後も3ケースのSource SHAが最新clean `origin/master`と一致
- [ ] NormalがPASS
- [ ] RebootがPASS
- [ ] install-rがbroadcast確認付きPASS、または通知証跡完備・broadcast識別不能の理由付きINCONCLUSIVE
- [ ] Issue本文との整合を再確認した
- [ ] `release-readiness.json`を途中評価として生成した

## 禁止事項

- serial指定なしのADB
- `adb -d`
- 物理端末
- アプリの強制停止
- アプリデータ削除
- アンインストール
- Emulatorデータ消去
- 通知待機中のアプリ再オープン
- Release session中のコード・version変更
- Issue #60集約前の別PRマージ
- `ScheduledNotificationBootReceiver`の`android:exported="true"`化
