# Issue #60 Android Emulator通知実測手順

対象：`kaenozu/ashita-motsumono` Issue #60  
Emulator：`emulator-5554`  
Application ID：`com.ashita_motsumono`

推奨入口：`tool/release_validation_session.ps1`  
低レベル証跡ツール：`tool/issue60_emulator_evidence.ps1`

Release全体を通して実行する場合は`docs/RELEASE_VALIDATION_SESSION.md`を優先します。この文書はIssue #60の低レベル操作と判定根拠を定義します。

## 1. 判定原則

- 静的確認、ビルド、インストール、起動成功は実通知のPASSではない。
- 通知権限が`DENIED`または`UNKNOWN`なら試験を開始しない。
- 各ケースで別の未来Todoを作る。
- `PlanCase`をTodo作成前に実行し、作成前Alarmを保存する。
- Todo保存後に`BeginCase`を実行し、作成後Alarmとの差分を`alarm-registration.json`へ保存する。
- 新しいAlarm登録差分を確認できない場合は、通知到着を待たず`INCONCLUSIVE`とする。
- 通知待機中にアプリを開かない。
- アプリデータ削除、強制停止、アンインストール、Emulatorデータ消去、コード・version変更は禁止。
- FAILは、予定時刻+20分までEmulatorがオンラインで、権限・時刻・Alarm登録差分が正常だった場合に限る。
- 証跡不足はFAILではなく`INCONCLUSIVE`、環境条件崩壊は`BLOCKED`とする。
- `ScheduledNotificationBootReceiver`は`android:exported="false"`のまま維持する。
- 3ケースのSource SHAは同一で、集約時点の最新`origin/master`と一致しなければClose候補にしない。

## 2. 検証用worktreeと証跡ルート

```powershell
git fetch origin
git worktree add C:\wt\release origin/master
cd C:\wt\release

git rev-parse HEAD
git rev-parse origin/master
git status --short

Set-ExecutionPolicy -Scope Process Bypass

$tool = '.\tool\issue60_emulator_evidence.ps1'
$evidence = Join-Path $HOME 'Documents\ashita-release-evidence'
New-Item -ItemType Directory -Force $evidence | Out-Null
```

証跡は`$evidence`配下へ保存し、worktree内へ生成しません。Release session、Issue #60、Play Console、正式Release、内部テストの証跡を別ルートへ分散させません。

## 3. 環境Preflight

```powershell
& $tool `
  -Action Preflight `
  -CaseName SETUP_ENV `
  -OutputRoot $evidence
```

PASS条件：

- `get-state=device`
- `sys.boot_completed=1`
- `ro.kernel.qemu=1`
- `persist.sys.timezone=Asia/Tokyo`
- `HEAD == origin/master`
- 追跡対象ファイルに変更なし

`preflight-result.json`が`PASS`でなければ先へ進みません。

## 4. APKビルドと初期インストール

```powershell
flutter pub get
flutter build apk --debug

& $tool `
  -Action Install `
  -CaseName SETUP_INSTALL `
  -CaseType setup `
  -ApkPath .\build\app\outputs\flutter-apk\app-debug.apk `
  -OutputRoot $evidence
```

アプリを手動で一度だけ開き、通知権限を許可します。Homeへ戻った後に確認します。

```powershell
& $tool `
  -Action Preflight `
  -CaseName SETUP_APP `
  -RequireInstalledApp `
  -OutputRoot $evidence
```

`Permission=GRANTED`でなければ先へ進みません。Release全体の検証では、この確認後に`release_validation_session.ps1 -Action StartSession`でSource SHAを固定します。

## 5. 通常通知

### 5.1 Todo作成前の計画

現在から10～15分後のISO 8601日時を決めます。

```powershell
& $tool `
  -Action PlanCase `
  -CaseName NORMAL_YYYYMMDD_HHMM_SS `
  -CaseType normal `
  -TodoTitle NORMAL_YYYYMMDD_HHMM_SS `
  -ExpectedTime '2026-07-13T18:30:00+09:00' `
  -OutputRoot $evidence
```

`PlanCase`はTodo作成前のAlarm、Notification、foreground Activity、時刻、権限、Source SHAを保存し、`case-plan.json`を生成します。

### 5.2 Todo作成

Emulator画面で新規Todoを作ります。

- タイトルは`PlanCase`で指定したASCII文字列
- 当日通知のみ有効
- 指定した未来時刻
- 保存後すぐHomeへ移動
- 以後、通知確認までアプリを開かない

### 5.3 Alarm登録差分

```powershell
& $tool `
  -Action BeginCase `
  -CaseName NORMAL_YYYYMMDD_HHMM_SS `
  -CaseType normal `
  -TodoTitle NORMAL_YYYYMMDD_HHMM_SS `
  -ExpectedTime '2026-07-13T18:30:00+09:00' `
  -OutputRoot $evidence
```

`BeginCase`はTodo保存後のsnapshotを取得し、Todo作成前後のAlarm関連行を比較して`alarm-registration.json`を生成します。

PASS候補へ進む最低条件：

- `alarm-registration.json`の`Result=PASS`
- `AddedLineCount > 0`
- `SourceSha`がRelease sessionと一致

差分がない場合は待機しません。設定または因果関係を確認できないため`INCONCLUSIVE`とします。

### 5.4 待機

```powershell
& $tool `
  -Action Wait `
  -CaseName NORMAL_YYYYMMDD_HHMM_SS `
  -CaseType normal `
  -TodoTitle NORMAL_YYYYMMDD_HHMM_SS `
  -OutputRoot $evidence `
  -PollSeconds 15
```

`Wait`は接続、boot ID、タイムゾーン、通知権限、前面Activity、通知タイトル、heartbeat間隔を監視します。通知検出時または予定時刻+20分で証跡を保存します。

通知領域の自動展開に失敗した場合は、手動で通知領域を開いて取得します。

```powershell
& $tool `
  -Action Capture `
  -CaseName NORMAL_YYYYMMDD_HHMM_SS `
  -CaseType normal `
  -TodoTitle NORMAL_YYYYMMDD_HHMM_SS `
  -ExpandNotificationShade `
  -OutputRoot $evidence
```

### 5.5 Finalize

```powershell
& $tool `
  -Action Finalize `
  -CaseName NORMAL_YYYYMMDD_HHMM_SS `
  -CaseType normal `
  -TodoTitle NORMAL_YYYYMMDD_HHMM_SS `
  -Verdict PASS `
  -Notes '通知領域でタイトルと本文を確認' `
  -OutputRoot $evidence
```

通知権限、Alarm登録差分、通知タイトル、通知領域画面、notification dump、非前面状態、Git gateが揃わない場合、PASSは拒否されます。UI階層でタイトルを取得できず、人が保存済みスクリーンショットを確認した場合だけ`-ManualScreenshotVerified`を付けます。

## 6. Emulator再起動後

通常通知がPASSしてから進みます。

1. `PlanCase`をTodo作成前に実行する。
2. 別Todoを現在から20～25分後へ設定する。
3. Homeへ移動する。
4. `BeginCase`でAlarm登録差分を確認する。
5. `Reboot`を実行する。

```powershell
& $tool `
  -Action PlanCase `
  -CaseName REBOOT_YYYYMMDD_HHMM_SS `
  -CaseType reboot `
  -TodoTitle REBOOT_YYYYMMDD_HHMM_SS `
  -ExpectedTime '2026-07-13T19:00:00+09:00' `
  -OutputRoot $evidence

# EmulatorでTodoを作成してHomeへ移動

& $tool `
  -Action BeginCase `
  -CaseName REBOOT_YYYYMMDD_HHMM_SS `
  -CaseType reboot `
  -TodoTitle REBOOT_YYYYMMDD_HHMM_SS `
  -ExpectedTime '2026-07-13T19:00:00+09:00' `
  -OutputRoot $evidence

& $tool `
  -Action Reboot `
  -CaseName REBOOT_YYYYMMDD_HHMM_SS `
  -CaseType reboot `
  -TodoTitle REBOOT_YYYYMMDD_HHMM_SS `
  -ExpectedTime '2026-07-13T19:00:00+09:00' `
  -ResetLogcatBeforeMutation `
  -OutputRoot $evidence
```

再起動前後のboot ID、要求時刻、`sys.boot_completed=1`確認時刻、Alarm、Notification、Activity、logcatを保存します。アプリは起動しません。boot IDが変化しなければ`BLOCKED`です。

```powershell
& $tool `
  -Action Wait `
  -CaseName REBOOT_YYYYMMDD_HHMM_SS `
  -CaseType reboot `
  -TodoTitle REBOOT_YYYYMMDD_HHMM_SS `
  -OutputRoot $evidence

& $tool `
  -Action Finalize `
  -CaseName REBOOT_YYYYMMDD_HHMM_SS `
  -CaseType reboot `
  -TodoTitle REBOOT_YYYYMMDD_HHMM_SS `
  -Verdict PASS `
  -Notes '再起動後にアプリを開かず通知を確認' `
  -OutputRoot $evidence
```

## 7. APK上書き後

RebootがPASSしてから進みます。

```powershell
& $tool `
  -Action PlanCase `
  -CaseName UPDATE_YYYYMMDD_HHMM_SS `
  -CaseType install-r `
  -TodoTitle UPDATE_YYYYMMDD_HHMM_SS `
  -ExpectedTime '2026-07-13T19:30:00+09:00' `
  -OutputRoot $evidence

# EmulatorでTodoを作成してHomeへ移動

& $tool `
  -Action BeginCase `
  -CaseName UPDATE_YYYYMMDD_HHMM_SS `
  -CaseType install-r `
  -TodoTitle UPDATE_YYYYMMDD_HHMM_SS `
  -ExpectedTime '2026-07-13T19:30:00+09:00' `
  -OutputRoot $evidence

& $tool `
  -Action Install `
  -CaseName UPDATE_YYYYMMDD_HHMM_SS `
  -CaseType install-r `
  -TodoTitle UPDATE_YYYYMMDD_HHMM_SS `
  -ExpectedTime '2026-07-13T19:30:00+09:00' `
  -ApkPath .\build\app\outputs\flutter-apk\app-debug.apk `
  -ResetLogcatBeforeMutation `
  -OutputRoot $evidence

& $tool `
  -Action Wait `
  -CaseName UPDATE_YYYYMMDD_HHMM_SS `
  -CaseType install-r `
  -TodoTitle UPDATE_YYYYMMDD_HHMM_SS `
  -OutputRoot $evidence
```

APK SHA-256、`install -r`結果、更新前後の`lastUpdateTime`、Alarm、Notification、Activity、logcatを保存します。

### broadcastを一意に確認できた場合

ログなどから`MY_PACKAGE_REPLACED`受信を一意に確認でき、通知証跡もすべて揃った場合だけPASSにします。

```powershell
& $tool `
  -Action Finalize `
  -CaseName UPDATE_YYYYMMDD_HHMM_SS `
  -CaseType install-r `
  -TodoTitle UPDATE_YYYYMMDD_HHMM_SS `
  -Verdict PASS `
  -InstallBroadcastVerified `
  -Notes 'MY_PACKAGE_REPLACED受信と通知到着を確認' `
  -OutputRoot $evidence
```

### broadcastを一意に確認できない場合

同一APKのためbroadcast受信を一意に識別できなくても、install成功、Alarm登録差分、通知到着、タイトル、画面、非前面状態がすべて揃っている場合だけ限定的なINCONCLUSIVEを記録します。

```powershell
& $tool `
  -Action Finalize `
  -CaseName UPDATE_YYYYMMDD_HHMM_SS `
  -CaseType install-r `
  -TodoTitle UPDATE_YYYYMMDD_HHMM_SS `
  -Verdict INCONCLUSIVE `
  -InstallBroadcastUnverified `
  -Notes 'install-rと通知到着は確認。broadcast受信の一意な証跡なし' `
  -OutputRoot $evidence
```

通知未到着や証跡不足を`InstallBroadcastUnverified`だけでClose候補にできません。

## 8. FAIL、BLOCKED、INCONCLUSIVE

- **FAIL**：通知権限、Alarm登録差分、接続、boot ID、時刻、非前面状態を維持し、予定時刻+20分まで通知タイトルがない。`Wait`の`TIMEOUT`証跡が必須。
- **BLOCKED**：ADB切断、Emulator停止、権限拒否、時刻変更、boot完了不能、PCスリープ相当のheartbeat欠落など、環境条件が崩れた。
- **INCONCLUSIVE**：Alarm登録差分、画面、時刻、待機継続性、broadcast因果関係などの証跡が不足する。

1回目のFAILではコード変更しません。同じSource SHA、別の未来Todoで1回だけ再現確認します。

## 9. Issueコメント生成とAggregate

各ケースの`Finalize`は`case-result.json`と`issue-comment.md`を生成します。3ケース完了後にAggregateします。

```powershell
& $tool `
  -Action Aggregate `
  -CaseName ISSUE60_SUMMARY `
  -NormalCaseName NORMAL_YYYYMMDD_HHMM_SS `
  -RebootCaseName REBOOT_YYYYMMDD_HHMM_SS `
  -InstallCaseName UPDATE_YYYYMMDD_HHMM_SS `
  -OutputRoot $evidence
```

生成物：

- `ISSUE60_SUMMARY\issue60-summary.json`
- `ISSUE60_SUMMARY\issue60-summary.md`

Closeレビュー条件：

- NormalがPASS
- RebootがPASS
- install-rがbroadcast確認付きPASS、または通知証跡完備・broadcast識別不能の理由付きINCONCLUSIVE
- 3ケースのSource SHAが同一
- 集約時の最新clean `origin/master`と一致
- `issue60-summary.md`をIssue #60へ記録
