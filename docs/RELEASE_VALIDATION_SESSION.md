# Release Validation Session

対象：`kaenozu/ashita-motsumono`  
Application ID：`com.ashita_motsumono`  
Android Emulator：`emulator-5554`

この文書は、Issue #60の通知実測から最終Release判定までを、単一の証跡ルートと状態ファイルで実行する推奨手順です。

低レベルの証跡ツールを直接呼ぶ場合は`docs/ISSUE60_ANDROID_EMULATOR_VALIDATION.md`を参照してください。

## 1. 原則

- 証跡ルートは`Documents\ashita-release-evidence`へ統一する。
- 環境診断とAPK初期インストールを完了してからRelease sessionを固定する。
- Release session開始後、Issue #60の3ケース集約までmasterへ別PRをマージしない。
- Todo作成前と作成後のAlarm証跡を比較し、新しいAlarm登録差分がなければPASSにしない。
- NormalがPASSするまでRebootへ進まない。
- RebootがPASSするまで`install -r`へ進まない。
- CI、ビルド、インストール、起動成功を実通知のPASSとして扱わない。
- 外部操作や証跡が不足する場合は`BLOCKED`または`INCONCLUSIVE`にする。

## 2. worktree

```powershell
git fetch origin
git worktree add C:\wt\release origin/master
cd C:\wt\release

Set-ExecutionPolicy -Scope Process Bypass

$sessionTool = '.\tool\release_validation_session.ps1'
$evidence = Join-Path $HOME 'Documents\ashita-release-evidence'
```

既存の別Release sessionが`$evidence`に残っている場合は、内容を保存して別フォルダーへ移動してから開始します。異なるSource SHAのsessionを上書きしません。

## 3. GO/NO-GO診断

```powershell
& $sessionTool `
  -Action Doctor `
  -EvidenceRoot $evidence
```

必須条件：

- `git`、`python`、`flutter`、`adb`が利用可能
- hostのUTC offsetが`+09:00`
- `HEAD == origin/master`
- tracked file変更なし
- `emulator-5554`が`device`
- `sys.boot_completed=1`
- `ro.kernel.qemu=1`
- Emulator timezoneが`Asia/Tokyo`

失敗した場合はRelease sessionを開始しません。

## 4. APKビルドと初期インストール

```powershell
& $sessionTool `
  -Action BuildInstall `
  -EvidenceRoot $evidence
```

処理内容：

- `flutter pub get`
- `flutter build apk --debug`
- APK SHA-256記録
- `adb -s emulator-5554 install -r`
- インストール前後のpackage、Alarm、Notification、logcat保存

完了後にEmulatorでアプリを一度だけ開き、通知権限を許可してHomeへ戻ります。

## 5. Release session開始

```powershell
& $sessionTool `
  -Action StartSession `
  -EvidenceRoot $evidence
```

`StartSession`は通知権限が`GRANTED`でなければ失敗します。

生成物：

- `release-session.json`
- `release-validation-state.json`
- `SETUP_ENV`
- `SETUP_APP`

Release sessionのSource SHAと現在の`HEAD`、`origin/master`が一致しなくなった場合、以後のケース処理を拒否します。

## 6. Normalケース

### 6.1 Todo作成前の計画とAlarm基準取得

```powershell
& $sessionTool `
  -Action PlanCase `
  -CaseType normal `
  -EvidenceRoot $evidence
```

スクリプトがTodoタイトル、通知予定日時、Emulatorへ入力するローカル時刻を表示し、Todo作成前のAlarm snapshotを保存します。

### 6.2 Todo作成

Emulatorで表示されたタイトルの新規Todoを作成します。

- 当日通知のみ有効
- 表示された時刻を設定
- 保存後すぐHomeへ移動
- 以後アプリを開かない

### 6.3 Alarm登録差分

```powershell
& $sessionTool `
  -Action BeginCase `
  -CaseType normal `
  -EvidenceRoot $evidence
```

`alarm-registration.json`の`Result`が`PASS`でなければ待機しません。設定または証跡が不十分なため`INCONCLUSIVE`として扱います。

### 6.4 待機

```powershell
& $sessionTool `
  -Action WaitCase `
  -CaseType normal `
  -EvidenceRoot $evidence
```

ADB接続、boot ID、timezone、通知権限、foreground Activity、Todoタイトル、heartbeat間隔を監視し、通知検出または予定時刻+20分で終了します。

### 6.5 判定

```powershell
& $sessionTool `
  -Action FinalizeCase `
  -CaseType normal `
  -Verdict PASS `
  -Notes '通知領域でタイトルと本文を確認' `
  -EvidenceRoot $evidence
```

UI Automatorでタイトルを取得できず、保存済み画面を人が確認した場合は`-ManualScreenshotVerified`を付けます。

FAILは、権限・Alarm登録差分・接続・時刻・非前面状態を維持し、予定時刻+20分までタイトルがない場合だけ指定します。1回目のFAILではコード変更せず、別の未来TodoでNormalを1回だけ再現確認します。

## 7. Rebootケース

NormalがPASSしてから実行します。

```powershell
& $sessionTool -Action PlanCase -CaseType reboot -EvidenceRoot $evidence
```

表示されたTodoを作成してHomeへ移動した後：

```powershell
& $sessionTool -Action BeginCase -CaseType reboot -EvidenceRoot $evidence
& $sessionTool -Action MutateCase -CaseType reboot -EvidenceRoot $evidence
& $sessionTool -Action WaitCase -CaseType reboot -EvidenceRoot $evidence
```

通知確認後：

```powershell
& $sessionTool `
  -Action FinalizeCase `
  -CaseType reboot `
  -Verdict PASS `
  -Notes '再起動後にアプリを開かず通知を確認' `
  -EvidenceRoot $evidence
```

`MutateCase`はboot ID変化と`sys.boot_completed=1`を確認し、アプリを起動しません。

## 8. install-rケース

RebootがPASSしてから実行します。

```powershell
& $sessionTool -Action PlanCase -CaseType install-r -EvidenceRoot $evidence
```

表示されたTodoを作成してHomeへ移動した後：

```powershell
& $sessionTool -Action BeginCase -CaseType install-r -EvidenceRoot $evidence
& $sessionTool -Action MutateCase -CaseType install-r -EvidenceRoot $evidence
& $sessionTool -Action WaitCase -CaseType install-r -EvidenceRoot $evidence
```

`MY_PACKAGE_REPLACED`を一意に確認できた場合：

```powershell
& $sessionTool `
  -Action FinalizeCase `
  -CaseType install-r `
  -Verdict PASS `
  -InstallBroadcastVerified `
  -Notes 'MY_PACKAGE_REPLACED受信と通知到着を確認' `
  -EvidenceRoot $evidence
```

通知到着・タイトル・画面・Alarm登録差分・install成功が揃い、broadcastだけを一意に確認できない場合：

```powershell
& $sessionTool `
  -Action FinalizeCase `
  -CaseType install-r `
  -Verdict INCONCLUSIVE `
  -InstallBroadcastUnverified `
  -Notes 'install-rと通知到着は確認。broadcast受信の一意な証跡なし' `
  -EvidenceRoot $evidence
```

通知未到着や画面不足をbroadcast未確認だけでClose候補にしません。

## 9. Issue #60集約

```powershell
& $sessionTool `
  -Action Aggregate `
  -EvidenceRoot $evidence
```

生成物：

- `ISSUE60_SUMMARY\issue60-summary.json`
- `ISSUE60_SUMMARY\issue60-summary.md`
- `release-readiness.json`
- `release-readiness.md`

Closeレビュー条件：Normal=`PASS`、Reboot=`PASS`、install-rがbroadcast確認付き`PASS`または通知証跡完備の限定的`INCONCLUSIVE`、3ケースが同一Source SHA、`git fetch origin`後も最新clean `origin/master`です。

## 10. Play Console証跡テンプレート

```powershell
& $sessionTool `
  -Action WriteTemplates `
  -EvidenceRoot $evidence
```

`play-console-evidence.json`と`internal-test-evidence.json`を生成します。確認できた事実だけを更新し、Secrets、鍵、パスワード、AdMob ID、Gemini Proxy URLを保存しません。

## 11. Release gate評価

途中経過：

```powershell
& $sessionTool `
  -Action Evaluate `
  -ReportOnly `
  -EvidenceRoot $evidence
```

最終強制判定：

```powershell
& $sessionTool `
  -Action Evaluate `
  -EvidenceRoot $evidence
```

すべてのゲートがPASSした場合だけ`READY_FOR_SUBMISSION`になります。

## 12. 状態確認

```powershell
& $sessionTool `
  -Action Status `
  -EvidenceRoot $evidence
```

状態ファイルから、現在のSource SHA、各ケース、既存readiness、次に必要なコマンドを表示します。

## 13. 禁止事項

- serial指定なしADB
- `adb -d`
- 物理端末
- アプリ強制停止
- `pm clear`
- アンインストール
- Emulatorデータ消去
- 待機中のアプリ再オープン
- Release session中のコード・version変更
- Issue #60集約前の別PRマージ
- `ScheduledNotificationBootReceiver`の`android:exported="true"`化

## 14. 人間操作が残る範囲

- Todoの作成
- 通知領域の目視
- Play Consoleフォーム入力
- 本番鍵の作成と安全な保管
- GitHub Secrets／Variables登録
- 内部テスト配布と実機操作
- 審査提出

ツールは外部操作を完了したと推測せず、保存された証跡だけを判定します。
