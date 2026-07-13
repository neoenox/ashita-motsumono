# Issue #60 Android Emulator通知実測手順

対象：`kaenozu/ashita-motsumono` Issue #60  
Emulator：`emulator-5554`  
Application ID：`com.ashita_motsumono`

実測補助スクリプト：`tool/issue60_emulator_evidence.ps1`

## 1. 判定原則

- 静的確認、ビルド、インストール、起動成功は実通知のPASSではない。
- 通知権限が`DENIED`または`UNKNOWN`なら試験を開始しない。
- 各ケースで別の未来Todoを作る。
- 通知待機中にアプリを開かない。
- アプリデータ削除、強制停止、アンインストール、Emulatorデータ消去、コード・version変更は禁止。
- FAILは、予定時刻から既定20分後までEmulatorがオンラインで、権限・時刻・Alarm登録が正常だった場合に限る。
- 証跡不足はFAILではなく`INCONCLUSIVE`、環境条件崩壊は`BLOCKED`とする。
- `ScheduledNotificationBootReceiver`は`android:exported="false"`のまま維持する。

## 2. 検証用worktree

```powershell
git fetch origin
git worktree add C:\wt\a60 origin/master
cd C:\wt\a60

git rev-parse HEAD
git rev-parse origin/master
git status --short
```

スクリプトはリポジトリ内の`tool`から実行するが、証跡は既定でDocuments配下へ出力される。未追跡ファイルをworktreeへ生成しない。

```powershell
Set-ExecutionPolicy -Scope Process Bypass
$tool = '.\tool\issue60_emulator_evidence.ps1'
```

## 3. 環境Preflight

```powershell
& $tool -Action Preflight -CaseName SETUP_ENV
```

PASS条件：

- `get-state=device`
- `sys.boot_completed=1`
- `ro.kernel.qemu=1`
- `persist.sys.timezone=Asia/Tokyo`
- `HEAD == origin/master`
- 追跡対象ファイルに変更なし

`preflight-result.json`が`PASS`でなければ先へ進まない。

## 4. APKビルドと初期インストール

```powershell
flutter pub get
flutter build apk --debug

& $tool `
  -Action Install `
  -CaseName SETUP_INSTALL `
  -CaseType setup `
  -ApkPath .\build\app\outputs\flutter-apk\app-debug.apk
```

インストール後、アプリを手動で開き、通知権限を許可する。初期インストールはTodo作成前に完了させる。

```powershell
& $tool `
  -Action Preflight `
  -CaseName SETUP_APP `
  -RequireInstalledApp
```

`NotificationPermission=GRANTED`でなければ先へ進まない。

## 5. 通常通知

1. Emulator画面で新規Todoを作る。
2. タイトルを`NORMAL_HHMM`とする。
3. 当日通知のみ有効にし、通知予定を現在から10～15分後にする。
4. 保存後すぐHomeへ移動し、アプリを再度開かない。
5. `ExpectedTime`はISO 8601形式で指定する。

```powershell
& $tool `
  -Action BeginCase `
  -CaseName NORMAL_HHMM `
  -CaseType normal `
  -TodoTitle NORMAL_HHMM `
  -ExpectedTime '2026-07-13T15:30:00+09:00'
```

保存直後の`alarm-filtered.txt`に対象packageの未来Alarmがなければ、通知を待たず`INCONCLUSIVE`として設定を見直す。

待機監視を開始する。スクリプトは15秒間隔で接続、boot ID、タイムゾーン、通知権限、前面Activity、通知タイトルを確認し、通知検出時または予定時刻+20分で自動的に証跡を保存する。

```powershell
& $tool `
  -Action Wait `
  -CaseName NORMAL_HHMM `
  -CaseType normal `
  -PollSeconds 15
```

通知領域の自動展開に失敗した場合は、Emulator上で手動で通知領域を開き、次を実行する。

```powershell
& $tool `
  -Action Capture `
  -CaseName NORMAL_HHMM `
  -CaseType normal `
  -TodoTitle NORMAL_HHMM `
  -ExpandNotificationShade
```

PASSとして確定する場合：

```powershell
& $tool `
  -Action Finalize `
  -CaseName NORMAL_HHMM `
  -CaseType normal `
  -Verdict PASS `
  -Notes '通知領域でタイトルと本文を確認'
```

スクリプトは、通知権限、未来Alarm、通知タイトル、通知領域画面、notification dump、非前面状態、Git gateが揃わない場合、PASSを拒否する。UI階層からタイトルを取得できないが人がスクリーンショットを確認した場合のみ、Finalizeへ`-ManualScreenshotVerified`を付けて人手確認を明示する。

## 6. Emulator再起動後

通常通知がPASSしてから進む。

1. 別Todo`REBOOT_HHMM`を現在から20～25分後に作る。
2. 保存後Homeへ移動する。
3. `BeginCase`後に`Reboot`を実行する。

```powershell
& $tool `
  -Action BeginCase `
  -CaseName REBOOT_HHMM `
  -CaseType reboot `
  -TodoTitle REBOOT_HHMM `
  -ExpectedTime '2026-07-13T16:00:00+09:00'

& $tool `
  -Action Reboot `
  -CaseName REBOOT_HHMM `
  -CaseType reboot `
  -TodoTitle REBOOT_HHMM `
  -ExpectedTime '2026-07-13T16:00:00+09:00' `
  -ResetLogcatBeforeMutation
```

スクリプトは再起動前後のboot ID、再起動要求時刻、`sys.boot_completed=1`確認時刻、Alarm、Notification、Activity、logcatを保存し、アプリを起動しない。boot IDが変化しなければ`BLOCKED`とする。

```powershell
& $tool `
  -Action Wait `
  -CaseName REBOOT_HHMM `
  -CaseType reboot `
  -TodoTitle REBOOT_HHMM

& $tool `
  -Action Finalize `
  -CaseName REBOOT_HHMM `
  -CaseType reboot `
  -Verdict PASS `
  -Notes '再起動後にアプリを開かず通知を確認'
```

## 7. APK上書き後

Rebootケースの後に進む。

```powershell
& $tool `
  -Action BeginCase `
  -CaseName UPDATE_HHMM `
  -CaseType install-r `
  -TodoTitle UPDATE_HHMM `
  -ExpectedTime '2026-07-13T16:30:00+09:00'

& $tool `
  -Action Install `
  -CaseName UPDATE_HHMM `
  -CaseType install-r `
  -TodoTitle UPDATE_HHMM `
  -ExpectedTime '2026-07-13T16:30:00+09:00' `
  -ApkPath .\build\app\outputs\flutter-apk\app-debug.apk `
  -ResetLogcatBeforeMutation

& $tool `
  -Action Wait `
  -CaseName UPDATE_HHMM `
  -CaseType install-r `
  -TodoTitle UPDATE_HHMM
```

APK SHA-256、`install -r`結果、更新前後の`lastUpdateTime`、Alarm、Notification、Activity、logcatを保存する。同一APKのため`MY_PACKAGE_REPLACED`受信を一意に識別できない場合は、通知到着が確認できてもbroadcast検証を`INCONCLUSIVE`とする。

```powershell
& $tool `
  -Action Finalize `
  -CaseName UPDATE_HHMM `
  -CaseType install-r `
  -Verdict INCONCLUSIVE `
  -InstallBroadcastUnverified `
  -Notes 'install -rと通知到着は確認。broadcast受信の一意な証跡なし'
```

## 8. FAIL、BLOCKED、INCONCLUSIVE

- **FAIL**：通知権限、未来Alarm、接続、boot ID、時刻、非前面状態を維持し、予定時刻+20分まで通知タイトルがない。`Wait`の`TIMEOUT`証跡が必須。
- **BLOCKED**：ADB切断、Emulator停止、権限拒否、時刻変更、boot完了不能、PCスリープ相当のheartbeat欠落など、環境条件が崩れた。
- **INCONCLUSIVE**：Alarm、画面、時刻、待機継続性、broadcast因果関係などの証跡が不足する。

1回目のFAILではコード変更しない。同じmaster、別の未来Todoで1回だけ再現確認する。

## 9. Issueコメント生成

各ケースの`Finalize`は`case-result.json`と`issue-comment.md`を生成する。3ケース完了後、集約コメントを生成する。

```powershell
& $tool `
  -Action Aggregate `
  -CaseName ISSUE60_SUMMARY `
  -NormalCaseName NORMAL_HHMM `
  -RebootCaseName REBOOT_HHMM `
  -InstallCaseName UPDATE_HHMM
```

`ELIGIBLE_FOR_CLOSE_REVIEW`になる最低条件：NormalがPASS、RebootがPASS、install-rがPASSまたは`MY_PACKAGE_REPLACED`識別不能を明示したINCONCLUSIVE。最終Close前にIssue本文との整合を再確認する。

## 10. 禁止事項

- serial指定なしのADB
- `adb -d`
- 物理端末
- アプリの強制停止
- アプリデータ削除
- アンインストール
- Emulatorデータ消去
- 通知待機中のアプリ再オープン
- 検証目的のコード・version変更
- BootReceiverの`exported=true`化
