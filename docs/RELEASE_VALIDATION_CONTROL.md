# Release Validation Control

対象：`kaenozu/ashita-motsumono`  
Application ID：`com.ashita_motsumono`  
Android Emulator：`emulator-5554`

この文書は、Issue #60のAndroid Emulator実測からIssue #98、#59、#94へ進む際の推奨入口です。

推奨ツール：

```text
 tool/release_validation_control.ps1
```

既存の`tool/release_validation_session.ps1`はバックエンドとして維持します。新しい制御ツールは、既存処理を変更せずに次を追加します。

- 証跡の非破壊退避
- 追加Alarmの予定時刻照合
- 予定時刻の解析不能・不一致時の`INCONCLUSIVE`強制
- 詳細な`Status`
- Windows PowerShell 5.1実行契約

## 1. 原則

- 証跡ルートは`Documents\ashita-release-evidence`へ統一する。
- 既存証跡を削除しない。
- Release session開始後、Issue #60集約まで別PRをmasterへマージしない。
- NormalがPASSするまでRebootへ進まない。
- RebootがPASSするまで`install-r`へ進まない。
- CI、ビルド、APKインストール、アプリ起動成功を実通知のPASSにしない。
- Alarm登録行が増えただけではPASSにしない。
- 追加Alarmの発火時刻が予定時刻±5分以内で、`ExpectedTimeMatch=PASS`の場合だけ待機・PASS・FAIL判定へ進む。
- Alarm時刻を解析できない場合は`INCONCLUSIVE`とする。
- 解析できた時刻が予定時刻と一致しない場合も`INCONCLUSIVE`とする。
- 外部操作を実行済みと推測しない。

## 2. worktree

```powershell
git fetch origin
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$worktree = "C:\wt\release-$stamp"
git worktree add $worktree origin/master
Set-Location $worktree

Set-ExecutionPolicy -Scope Process Bypass

$control = '.\tool\release_validation_control.ps1'
$evidence = Join-Path $HOME 'Documents\ashita-release-evidence'
```

## 3. 既存証跡の退避

証跡ルートに以前のデータがある場合：

```powershell
& $control `
  -Action ArchiveSession `
  -EvidenceRoot $evidence
```

退避先は次の形式です。

```text
Documents\ashita-release-evidence-archive-YYYYMMDD-HHMMSS
```

退避先には`archive-manifest.json`を生成します。元の証跡は削除しません。

進行中のRelease sessionは誤操作防止のため拒否されます。明示的に中断して退避する場合だけ使用します。

```powershell
& $control `
  -Action ArchiveSession `
  -ForceArchiveActive `
  -EvidenceRoot $evidence
```

`-ForceArchiveActive`は通常運用では使用しません。

## 4. Doctor

```powershell
& $control `
  -Action Doctor `
  -EvidenceRoot $evidence
```

必須条件：

- `git`、`python`、`flutter`、`adb`が利用可能
- host UTC offsetが`+09:00`
- `HEAD == origin/master`
- tracked file変更なし
- `emulator-5554`が`device`
- `sys.boot_completed=1`
- `ro.kernel.qemu=1`
- Emulator timezoneが`Asia/Tokyo`

失敗時は`BLOCKED`であり、アプリコードを変更しません。

## 5. BuildInstall

```powershell
& $control `
  -Action BuildInstall `
  -EvidenceRoot $evidence
```

完了後の人間操作：

1. Emulatorでアプリを一度だけ開く
2. 通知権限を許可する
3. Homeへ戻る
4. 以後、Normalケース完了までアプリを開かない

## 6. StartSession

```powershell
& $control `
  -Action StartSession `
  -EvidenceRoot $evidence
```

通知権限が`GRANTED`でなければ開始できません。Source SHAを固定し、Issue #60集約までmasterを移動させません。

## 7. Normal

### 7.1 PlanCase

```powershell
& $control `
  -Action PlanCase `
  -CaseType normal `
  -EvidenceRoot $evidence
```

表示されたタイトルと通知時刻で新規Todoを作成します。

- 当日通知のみ有効
- 保存後すぐHomeへ移動
- アプリを再度開かない
- 過去のTodoタイトルを再利用しない

### 7.2 BeginCase

```powershell
& $control `
  -Action BeginCase `
  -CaseType normal `
  -EvidenceRoot $evidence
```

制御ツールは次を実行します。

1. バックエンドでTodo作成前後のAlarm差分を取得
2. `alarm-registration.json`を確認
3. `issue60_alarm_time_evidence.ps1`で追加Alarmの発火時刻を解析
4. `alarm-time-evidence.json`を生成
5. 発火時刻が予定時刻±5分以内か確認
6. `ExpectedTimeMatch`を設定

必要条件：

```text
Result=PASS
AddedLineCount > 0
RelevantLineCountIncreased=true
ExpectedTimeMatch=PASS
```

次の場合は待機しません。

- 追加Alarmなし
- Alarm関連行の件数増加なし
- 発火時刻を解析不能
- 発火時刻が予定時刻±5分の外側

判定は`INCONCLUSIVE`です。

### 7.3 WaitCase

```powershell
& $control `
  -Action WaitCase `
  -CaseType normal `
  -EvidenceRoot $evidence
```

`ExpectedTimeMatch=PASS`でなければ制御ツールが拒否します。

### 7.4 FinalizeCase

通知と証跡を確認後：

```powershell
& $control `
  -Action FinalizeCase `
  -CaseType normal `
  -Verdict PASS `
  -Notes 'アプリを再度開かず通知領域でTodoタイトルを確認' `
  -ManualScreenshotVerified `
  -EvidenceRoot $evidence
```

UI Automatorがタイトルを取得できている場合、`-ManualScreenshotVerified`は不要です。

PASSまたはFAILを指定する場合、制御ツールは`ExpectedTimeMatch=PASS`を必須化します。

最初のFAILではコードを変更せず、別の未来TodoでNormalを1回だけ再確認します。

## 8. Reboot

NormalがPASSした後だけ実行します。

```powershell
& $control -Action PlanCase -CaseType reboot -EvidenceRoot $evidence
```

Todo作成後：

```powershell
& $control -Action BeginCase -CaseType reboot -EvidenceRoot $evidence
& $control -Action MutateCase -CaseType reboot -EvidenceRoot $evidence
& $control -Action WaitCase -CaseType reboot -EvidenceRoot $evidence
```

通知確認後：

```powershell
& $control `
  -Action FinalizeCase `
  -CaseType reboot `
  -Verdict PASS `
  -Notes '再起動後にアプリを開かず通知を確認' `
  -EvidenceRoot $evidence
```

## 9. install-r

RebootがPASSした後だけ実行します。

```powershell
& $control -Action PlanCase -CaseType install-r -EvidenceRoot $evidence
```

Todo作成後：

```powershell
& $control -Action BeginCase -CaseType install-r -EvidenceRoot $evidence
& $control -Action MutateCase -CaseType install-r -EvidenceRoot $evidence
& $control -Action WaitCase -CaseType install-r -EvidenceRoot $evidence
```

`MY_PACKAGE_REPLACED`を一意に確認できた場合：

```powershell
& $control `
  -Action FinalizeCase `
  -CaseType install-r `
  -Verdict PASS `
  -InstallBroadcastVerified `
  -Notes 'MY_PACKAGE_REPLACED受信と通知到着を確認' `
  -EvidenceRoot $evidence
```

通知到着は確認できたがbroadcastだけ一意に証明できない場合：

```powershell
& $control `
  -Action FinalizeCase `
  -CaseType install-r `
  -Verdict INCONCLUSIVE `
  -InstallBroadcastUnverified `
  -Notes 'install-rと通知到着は確認。broadcast受信の一意な証跡なし' `
  -EvidenceRoot $evidence
```

通知未到着や画面不足をbroadcast未確認だけでClose候補にしません。

## 10. Aggregate

```powershell
& $control `
  -Action Aggregate `
  -EvidenceRoot $evidence
```

生成物：

- `ISSUE60_SUMMARY\issue60-summary.json`
- `ISSUE60_SUMMARY\issue60-summary.md`
- `release-readiness.json`
- `release-readiness.md`

Issue #60のCloseレビュー条件：

- Normal=`PASS`
- Reboot=`PASS`
- install-rはbroadcast確認済み`PASS`、または通知証跡完備の限定的`INCONCLUSIVE`
- 3ケースすべて`ExpectedTimeMatch=PASS`
- 3ケースが同一Source SHA
- `git fetch origin`後も最新clean `origin/master`

## 11. Status

```powershell
& $control `
  -Action Status `
  -EvidenceRoot $evidence
```

出力：

- `doctorPassed`
- `apkInstalled`
- `notificationPermission`
- `sessionStarted`
- `sessionSourceSha`
- Normal、Reboot、install-rのstatusとverdict
- `alarmExpectedTimeMatch`
- Wait結果
- 証跡ファイル一覧
- `nextAction`
- コピー可能な`nextCommand`
- 人間操作を示す`manualAction`

同じ内容を`release-validation-status.json`へUTF-8 BOMなしで保存します。

## 12. 後続Issue

Issue #60完了後の順序：

```text
Issue #60
→ Issue #98 playSigning
→ Issue #59 formalRelease
→ Issue #94 playSubmission / internalTest
```

Play Console、鍵、Secrets、内部テスト、審査提出は認証済み外部環境で実行します。

## 13. Windows PowerShell 5.1 CI

`.github/workflows/release-validation-windows-powershell51.yml`で次を検証します。

- Windows PowerShell 5.1で全関連スクリプトをparse
- Alarm予定時刻一致=`PASS`
- Alarm予定時刻不一致=`MISMATCH`
- Alarm時刻解析不能=`INCONCLUSIVE`
- `Status`の実行
- git未導入時に`UNKNOWN`を返してクラッシュしない
- JSONがUTF-8 BOMなし
- 進行中sessionのArchiveSession拒否
- `-ForceArchiveActive`時の非破壊退避
- `archive-manifest.json`生成

CI成功は実通知成功の代替ではありません。

## 14. 禁止事項

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
- Alarm時刻解析不能をPASS扱いすること
