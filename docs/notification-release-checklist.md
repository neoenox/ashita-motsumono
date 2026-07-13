# 通知リリース確認チェックリスト

対象：Android Emulator `emulator-5554`。詳細手順は`docs/ISSUE60_ANDROID_EMULATOR_VALIDATION.md`、補助スクリプトは`tool/issue60_emulator_evidence.ps1`を使用する。

## 共通ゲート

- [ ] 最新`origin/master`から専用worktreeを作成した
- [ ] `HEAD == origin/master`
- [ ] 追跡対象ファイルにローカル変更がない
- [ ] すべてのADB操作が`-s emulator-5554`経由
- [ ] `ro.kernel.qemu=1`
- [ ] AVD名、Androidバージョン、APIレベル、端末モデルを記録した
- [ ] Emulatorのタイムゾーンが`Asia/Tokyo`
- [ ] `sys.boot_completed=1`
- [ ] Application IDが`com.ashita_motsumono`
- [ ] 通知権限が`GRANTED`
- [ ] 各ケースで別の未来Todoを作成した
- [ ] TodoタイトルはASCIIの`NORMAL_HHMM`、`REBOOT_HHMM`、`UPDATE_HHMM`
- [ ] 通知待機中にアプリを再度開いていない

## 必須証跡

各ケースで次を保存する。

- [ ] Todoタイトルと通知設定
- [ ] Source SHA
- [ ] 予定時刻と実到着時刻
- [ ] 保存直後の`dumpsys alarm`
- [ ] `dumpsys notification --noredact`
- [ ] 通知領域スクリーンショット
- [ ] UI Automator階層またはnotification dump上のTodoタイトル
- [ ] foreground Activity
- [ ] logcat
- [ ] 禁止操作を使用していないこと

## 1. 通常通知

- [ ] 当日通知または前日通知の未来Alarmが保存直後に存在する
- [ ] アプリを開かず通知領域へ表示された
- [ ] タイトル、本文、到着時刻を記録した

判定：

- **PASS**：権限、未来Alarm、通知タイトル、通知領域画面、Notification dump、非前面状態が揃う
- **FAIL**：予定時刻+20分まで条件を維持したが通知タイトルがない
- **BLOCKED**：ADB切断、PCスリープ、Emulator停止、権限無効、時刻変更などで条件が崩れた
- **INCONCLUSIVE**：Alarm、時刻、画面、待機継続性などの証跡が不足する

通常通知がPASSしなければ再起動後検証へ進まない。

## 2. Android Emulator再起動後

- [ ] 別の未来Todoを作成した
- [ ] 再起動前のboot ID、Alarm、時刻を保存した
- [ ] `adb -s emulator-5554 reboot`を実行した
- [ ] `sys.boot_completed=1`まで待った
- [ ] 再起動後のboot IDが変化した
- [ ] 再起動後にアプリを開いていない
- [ ] 再起動後の未来Alarmを確認した
- [ ] 保存済みTodoの通知が表示された

通常通知がPASS済みで、再起動後だけ復元されないことを十分な証跡で示せた場合のみFAILとする。

## 3. APK上書き後

- [ ] 別の未来Todoを作成した
- [ ] 同一application IDのAPK SHA-256を記録した
- [ ] `adb -s emulator-5554 install -r <apk>`が`Success`
- [ ] 更新前後の`lastUpdateTime`を記録した
- [ ] 上書き後にアプリを開いていない
- [ ] 上書き後の未来Alarmを確認した
- [ ] 保存済みTodoの通知が表示された

判定：

- **PASS**：通知証跡がすべて揃い、`MY_PACKAGE_REPLACED`受信を一意に確認してFinalizeへ`-InstallBroadcastVerified`を指定した
- **INCONCLUSIVE**：通知到着とinstall成功は確認できたが、同一APKのためbroadcast受信を一意に識別できず、Finalizeへ`-InstallBroadcastUnverified`を指定した
- 通知未到着、Alarm不足、画面不足などを`InstallBroadcastUnverified`だけでClose候補にしてはいけない

## 4. Issue #60報告

- [ ] 各ケースで`case-result.json`と`issue-comment.md`を生成した
- [ ] 3ケースを`Aggregate`し、`issue60-summary.md`を生成した
- [ ] 確認済み、未確認、推測、反証、検証範囲、判定根拠を分離した
- [ ] 3ケースのSource SHAが同一
- [ ] 3ケースのSource SHAが集約時点の最新`origin/master`と一致
- [ ] NormalがPASS
- [ ] RebootがPASS
- [ ] install-rがbroadcast確認付きPASS、または通知証跡完備・broadcast識別不能の理由付きINCONCLUSIVE
- [ ] Issue本文との整合を再確認した

## 禁止事項

- serial指定なしのADB
- `adb -d`
- 物理端末
- アプリの強制停止
- アプリデータ削除
- アンインストール
- Emulatorデータ消去
- 通知待機中のアプリ再オープン
- 検証目的のコード・version変更
- `ScheduledNotificationBootReceiver`の`android:exported="true"`化
