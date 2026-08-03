# Issue #60 通知実測 静的準備レポート（Release gate）

- 担当: Release gate 静的準備（静的監査と準備のみ。エミュレータ操作・実測なし）
- 日付: 2026-08-03
- 作業ディレクトリ: `C:\gemini-desktop\ashita-issue60-evidence`（branch `agent/issue60-evidence`、master `51755ce` ベース）
- 対象リポジトリ: `kaenozu/ashita-motsumono`
- Application ID: `com.ashita_motsumono` / エミュレータ: `emulator-5554` / timezone 要件: `Asia/Tokyo`

---

## この担当は保留 / 準備完了

**保留（実測ブロック中）。静的準備は完了しているが、実測を開始できる状態ではない。**

判定根拠は「実測をブロックする外部依存」と「静的監査で検出した問題」の2点。

---

## 理由

### A. 実測をブロックする外部依存（現在の環境状態）

実測開始に必須の環境条件のうち、以下が満たされていない（2026-08-03 確認時点の実測値）。

| # | 項目 | 必要条件 | 現在値 | 判定 |
|---|------|----------|--------|------|
| A1 | 通知権限 | `POST_NOTIFICATION = allow` / ツール判定 `GRANTED` | appops が `ignore`、ツール判定 `DENIED` | BLOCK |
| A2 | Emulator timezone | `persist.sys.timezone = Asia/Tokyo` | `GMT` | BLOCK |
| A3 | Release session 開始 | `BuildInstall`（APKビルド+初期install）完了後に開始 | 未開始（`release-session.json` / `release-validation-state.json` なし） | BLOCK |
| A4 | `adb` が PATH 上にある（**推奨入口側の条件**） | `Get-Command adb` が成功すること | PATH 上に `adb.exe` なし（`C:\Android\sdk\platform-tools` は PATH 外） | BLOCK |
| A5 | Debug APK のビルド | `flutter build apk --debug` 成功物 | `build\app\outputs\flutter-apk\app-debug.apk` 未生成 | BLOCK |

既に満たされている条件（静的確認・環境確認で確認済み）:

- PowerShell 7.6.3（PowerShell 5.1 互換記法のみで実装されていることを静的確認済み）
- Python 3.11.9（`C:\Users\neoen\AppData\Local\Programs\Python\Python311\python.exe`）
- Flutter 3.44.0 stable（`C:\src\flutter\bin\flutter.bat`）
- Java 17（Temurin 17.0.19、`C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot`）
- Android SDK: `ANDROID_SDK_ROOT`/`ANDROID_HOME = C:\Android\sdk`（`adb.exe`・`emulator.exe`・`cmdline-tools` 存在）
- ホスト UTC offset: `+09:00`（Tokyo Standard Time）→ ツールの必須条件を満たす
- エミュレータ: `emulator-5554` が `device`、`sys.boot_completed=1`、`ro.kernel.qemu=1`、API 35 / Android 15、AVD `Pixel_6_API_35`
- Application ID `com.ashita_motsumono` がインストール済み（`lastUpdateTime=2026-08-03 05:15:51`）
- Git gate: `HEAD == origin/master == 51755ced25896359e37baf89c94e1d72c98d6c8c`、tracked ファイル変更なし（`git fetch origin` 後も一致）
- Manifest: `POST_NOTIFICATIONS`・`RECEIVE_BOOT_COMPLETED` 宣言、`ScheduledNotificationReceiver`/`ScheduledNotificationBootReceiver` とも `android:exported="false"`、BootReceiver が `BOOT_COMPLETED`/`MY_PACKAGE_REPLACED`/`QUICKBOOT_POWERON` を受信
- 証跡ルート `Documents\ashita-release-evidence` は存在（**OneDrive 配下に解決される**: `C:\Users\neoen\OneDrive\Documents\ashita-release-evidence`。旧 `issue60` 証跡や session ファイルは無し）

### B. 静的監査で検出した問題（コード修正は行わず、ここに記録）

#### B1（重要）: 推奨入口 `tool/release_validation_session.ps1` から低レベルツールを呼び出せない

- 場所: `release_validation_session.ps1` の `Invoke-Issue60`（151-157行）
- 実装: `& $Issue60Tool @Arguments -Serial ... -PackageName ... -OutputRoot ...`
- 挙動: `$Arguments` は `string[]` なので `@Arguments` は**位置引数として**展開される。呼び出し側の `Invoke-Issue60 @('-Action','Preflight','-CaseName','SETUP_ENV')` では、`-Action` が `Action` に、`Preflight` が `CaseName` に束縛され、末尾のリテラル `-Action Preflight` と衝突して **ParameterBindingValidationException** になる。
- 実測（再現）: マスク版 inner スクリプトで `& $script @Arguments` を再現し、`Action` バインド失敗を確認済み。本物の `release_validation_session.ps1 -Action Doctor` を実行しても `required command not found: adb`（PATH 問題、A4）の後に、PATH を解決すると `-Action` 検証エラーで停止する。
- 影響: `Doctor` / `BuildInstall` / `StartSession` / `PlanCase` / `BeginCase` / `MutateCase` / `WaitCase` / `FinalizeCase` / `Aggregate` の**すべて**が低レベルツール呼び出しで失敗するため、推奨入口が機能しない。
- 対処候補（実測担当者またはコード修正担当者が判断）:
  1. `Invoke-Issue60` を `$Arguments | ForEach-Object { ... }` で1要素ずつ渡す形へ変更（スプラッティングをやめる）
  2. または `Invoke-Issue60` を「inner スクリプトの名前付きパラメータ」へ直接渡す形へ書き換え
- 補足: 低レベルツール `tool/issue60_emulator_evidence.ps1` を**直接**呼ぶ形（`docs/ISSUE60_ANDROID_EMULATOR_VALIDATION.md` の記載どおり）は正常に動く。`Preflight` の直接実行で `preflight-result.json` が生成され、`BLOCKED`（Timezone=GMT, Permission=DENIED）を正しく返した。

#### B2: 権限チェックの分類仕様（実装は妥当、認識合わせ用）

- `issue60_emulator_evidence_core.ps1` の `Permission` は、appops が `deny|ignore|errored` を「DENIED」、`allow` を「GRANTED」と分類する。現状の `ignore` は DENIED 扱い（Android の通知 OFF 状態に相当）。これは仕様どおりであり、修正不要。

#### B3: 旧 `scripts/*` は絶対パス固定の legacy ツール

- `scripts/run_issue60_notification_cases.ps1` と `scripts/summarize_issue60_notification_cases.ps1` は `C:\gemini-desktop\ashita-motsumono`（**この作業ディレクトリではないパス**）と `adb` の `-s` 指定なし reboot 等を含む旧方式。`docs/` が推奨する単一証跡ルートと合致せず、通知検証も「`dumpsys notification` への文字列ヒット」のみ。**実測には使わない**（置き換え対象）。

#### B4: `C:\gemini-desktop\ashita-motsumono` の存在確認のみ

- 旧スクリプトが参照するパスは存在するが、本タスクでは読み取り・変更の対象外（sibling project）として扱った。

---

## 完了済み

- 静的監査（下記「監査結果」参照）: 対象ツール・docs・scripts の存在・役割・ゲート条件の整合を確認
- 環境確認: PowerShell / Python / Flutter / Java / Android SDK / ホスト offset / エミュレータ状態 / Git 状態
- `git fetch origin` 後の再検証: `HEAD == origin/master == 51755ce`、tracked clean
- Python ゲート実装の検証: `release_execution_gate.py`・`release_execution_orchestrator.py` の import / `py_compile` / 単体テスト18件（`python -m unittest test_release_execution_gate test_release_execution_orchestrator`）すべて OK
- 推奨入口の実動確認（Doctor）: `adb` 不在 → PATH 解決後も B1 で失敗することを確認（= 修正が必要な証跡）
- 低レベルツールの実動確認（Preflight 直接実行）: 正常動作、`BLOCKED` を正しく返す
- 本ドキュメント `docs/ISSUE60_READINESS.md` の作成

---

## 再開条件

実測（Normal / Reboot / install-r）を開始するには、以下が**すべて**満たされる必要がある。

1. 通知権限を `GRANTED` にする（エミュレータのアプリ設定で通知を許可。ツール判定が `GRANTED` になること）
2. Emulator の timezone を `Asia/Tokyo` に設定する（`persist.sys.timezone=Asia/Tokyo`）
3. `tool/release_validation_session.ps1` の B1（`Invoke-Issue60` の引数渡し）を修正する、**または** 低レベルツールを直接呼ぶ手順に切り替える
4. `adb` を PATH に追加する、または `ANDROID_SDK_ROOT`/`ANDROID_HOME` が有効な状態で実行する（推奨入口は PATH 上の `adb` を要求するため）
5. `flutter build apk --debug` で `build\app\outputs\flutter-apk\app-debug.apk` を生成する
6. 変更（1〜5）後に `Doctor`（または `Preflight`）が `PASS` になること

再開時の注意:

- `BuildInstall` → StartSession の順で実行し、Source SHA を固定してからケースを開始する（session 中のコード・version 変更は禁止）
- 実測開始前にこの文書の A1〜A5 が解消済みであることを再確認する

---

## 次の担当者向け開始手順

推奨入口を使う場合（B1 修正後）:

```powershell
# 前提: エミュレータ emulator-5554 起動・timezone Asia/Tokyo・通知権限 GRANTED
git fetch origin
cd C:\gemini-desktop\ashita-issue60-evidence   # または専用 worktree（HEAD == origin/master）
Set-ExecutionPolicy -Scope Process Bypass
$env:PATH = 'C:\Android\sdk\platform-tools;C:\src\flutter\bin;' + $env:PATH
$sessionTool = '.\tool\release_validation_session.ps1'
$evidence = Join-Path $HOME 'Documents\ashita-release-evidence'

# 1. 環境診断（A1/A2/A4/A5 が解消されていること）
& $sessionTool -Action Doctor -EvidenceRoot $evidence
# 2. APK ビルドと初期インストール
& $sessionTool -Action BuildInstall -EvidenceRoot $evidence
# 3. アプリを一度だけ開き通知権限を許可し Home へ戻る（人間操作）
# 4. Source SHA 固定
& $sessionTool -Action StartSession -EvidenceRoot $evidence
# 5. Normal ケース
& $sessionTool -Action PlanCase -CaseType normal -EvidenceRoot $evidence
#    （エミュレータで表示された Todo を作成 → Home）
& $sessionTool -Action BeginCase -CaseType normal -EvidenceRoot $evidence
& $sessionTool -Action WaitCase -CaseType normal -EvidenceRoot $evidence
& $sessionTool -Action FinalizeCase -CaseType normal -Verdict PASS -Notes '通知領域でタイトルと本文を確認' -EvidenceRoot $evidence
# 6. Reboot ケース（Normal が PASS してから）
#    PlanCase → BeginCase → MutateCase(reboot) → WaitCase → FinalizeCase
# 7. install-r ケース（Reboot が PASS してから）
#    PlanCase → BeginCase → MutateCase(install-r) → WaitCase → FinalizeCase
# 8. 集約とゲート評価
& $sessionTool -Action Aggregate -EvidenceRoot $evidence
& $sessionTool -Action Evaluate -EvidenceRoot $evidence
```

詳細な操作順序と判定基準は `docs/RELEASE_VALIDATION_SESSION.md`（推奨入口）、`docs/ISSUE60_ANDROID_EMULATOR_VALIDATION.md`（低レベル直接呼び）、`docs/RELEASE_EXECUTION_PLAN.md`（全体順序）、`docs/notification-release-checklist.md`（チェックリスト）を参照。

B1 を修正せず低レベルツールを直接使う場合:

- 上記ドキュメントのコマンド（`tool/issue60_emulator_evidence.ps1` を `-Action ...` で直接呼ぶ形）をそのまま使用できる（実動作確認済み）
- ただし Release session の固定（Source SHA）と集約後のゲート評価は `release_validation_session.ps1` / `release_execution_orchestrator.py` が必要なため、いずれにしても B1 の修正が望ましい

---

## 監査結果

### ツール・スクリプト（存在 / 役割 / ゲート整合）

| ファイル | 存在 | 役割 | ゲート条件の整合 |
|---|---|---|---|
| `tool/release_validation_session.ps1` | ✅ | 推奨の単一操作入口。Doctor/BuildInstall/StartSession/PlanCase/BeginCase/MutateCase/WaitCase/FinalizeCase/Aggregate/WriteTemplates/Evaluate/Status | 条件実装は整合しているが、**B1 の引数渡しバグにより低レベルツールを呼べない** |
| `tool/issue60_emulator_evidence.ps1` | ✅ | 低レベル証跡ツール（Preflight/PlanCase/BeginCase/Wait/Capture/Install/Reboot/Finalize/Aggregate） | 直接呼び出しは正常動作（Preflight 実測確認）。serial/package 固定、`-s emulator-5554` 強制 |
| `tool/issue60_emulator_evidence_cases.ps1` | ✅ | ケース実装（Plan/Begin/Wait/Finalize/Aggregate、alarm差分・通知証跡・verdict 判定） | 整合。PASS には権限 GRANTED・alarm差分・ExpectedTimeMatch・非前面・画面・dump・Git gate が必須。install-r の PASS は `InstallBroadcastVerified` 必須、限定的 INCONCLUSIVE は `InstallBroadcastUnverified` 必須 |
| `tool/issue60_emulator_evidence_core.ps1` | ✅ | 共通関数（PreflightState/Permission/GitState/Snapshot/AlarmRegistration/Wait 監視） | 整合。Preflight は device/boot=1/qemu=1/Asia/Tokyo/Git gate PASS（+必要時 install/GRANTED）を必須。`Permission` は ignore を DENIED 扱い（B2） |
| `tool/issue60_portable_paths.ps1` | ✅ | adb / repo root 解決（`ANDROID_SDK_ROOT`→`ANDROID_HOME`→PATH） | 整合。adb 不在なら明確な throw |
| `tool/release_execution_gate.py` | ✅ | 証跡 validator（releaseSession/issue60/playConsole/formalRelease/internalTest の5ゲート） | 整合。issue60 は Recommendation/3ケース/SourceSha/install-r 規則を検証。import・py_compile・単体テスト OK |
| `tool/release_execution_orchestrator.py` | ✅ | Release ゲート順序（releaseSession→issue60→playSigning→formalRelease→playSubmission→internalTest、schema v2） | 整合。gate.py を base に拡張。import・py_compile・単体テスト OK |
| `scripts/run_issue60_notification_cases.ps1` | ✅ | **legacy**。絶対パス固定（`C:\gemini-desktop\ashita-motsumono`）・`flutter drive` 方式・文字列ヒットで判定 | 不整合（単一証跡ルート外、判定が不十分）。**実測に使用しない**（B3） |
| `scripts/summarize_issue60_notification_cases.ps1` | ✅ | legacy サマリー生成（同左） | 不整合（B3）。**使用しない** |

### ドキュメント（存在 / 役割 / 整合）

| ファイル | 存在 | 役割 | 整合 |
|---|---|---|---|
| `docs/RELEASE_VALIDATION_SESSION.md` | ✅ | 推奨入口の手順（Doctor→BuildInstall→StartSession→3ケース→Aggregate→Evaluate） | 整合。ただし B1 修正後に有効になる手順 |
| `docs/ISSUE60_ANDROID_EMULATOR_VALIDATION.md` | ✅ | 低レベル直接呼びの手順と判定根拠 | 整合。実動作確認済みの手順 |
| `docs/RELEASE_EXECUTION_PLAN.md` | ✅ | 実行順とゲート定義（Issue順・機械ゲート順・各ゲート条件） | 整合 |
| `docs/notification-release-checklist.md` | ✅ | チェックリスト（共通ゲート/必須証跡/3ケース/報告/禁止事項） | 整合 |
| `docs/ISSUE60_READINESS.md` | ✅ | **本ドキュメント（新規作成）** | — |

### ゲート条件の静的確認サマリー

- **Doctor（GO/NO-GO）**: `git`/`python`/`flutter`/`adb` 必須、host UTC offset=`+09:00`、`HEAD==origin/master`、tracked clean、`emulator-5554` が device、`sys.boot_completed=1`、`ro.kernel.qemu=1`、`persist.sys.timezone=Asia/Tokyo` → 実装は整合（現在は timezone が GMT のため NO-GO）
- **BuildInstall**: `flutter pub get` → `flutter build apk --debug` → install → SHA-256 記録 → 手動で通知権限許可（人間操作）→ 実装整合
- **StartSession**: 通知権限 GRANTED 必須 + インストール済み確認 → `release-session.json` 生成（Source SHA 固定）→ 以後 HEAD/origin/master との不一致を拒否 → 実装整合
- **Normal→Reboot→install-r の順序**: `Require-PreviousCase`（normal PASS 前に reboot 不可、reboot PASS 前に install-r 不可）→ 実装整合
- **install-r の受入**: PASS は `InstallBroadcastVerified` 必須 / 限定的 INCONCLUSIVE は通知証跡完備 + `InstallBroadcastUnverified`（gate.py でも検証）→ 整合
- **Aggregate**: 3ケース FINALIZED、同一 Source SHA、最新 clean origin/master、alarm 時刻一致 → 整合
- **Evaluate**: 全ゲート PASS 時のみ `READY_FOR_SUBMISSION`、`--report-only` 時は exit 0 → 整合
- **禁止事項**: serial なし ADB・`adb -d`・物理端末・強制停止・`pm clear`・アンインストール・Emulator データ消去・待機中のアプリ再オープン・session 中のコード変更・`ScheduledNotificationBootReceiver` の `exported="true"` 化 → コード上も明示

---

## 参考（実測値）

- `git rev-parse HEAD` = `51755ced25896359e37baf89c94e1d72c98d6c8c`
- `git rev-parse origin/master`（fetch 前後とも）= 同上
- `git status --porcelain --untracked-files=no` = 空
- 低レベル `Preflight` の結果（`SETUP_ENV\preflight-result.json`）: `BLOCKED` / State=device / Boot=1 / Qemu=1 / Timezone=GMT / Installed=true / Permission=DENIED / Git gate=PASS
- エミュレータ: `Pixel_6_API_35`（Android 15 / API 35、model `sdk_gphone64_x86_64`）
