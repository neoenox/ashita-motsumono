# Android Release Execution Plan

対象リポジトリ：`kaenozu/ashita-motsumono`  
正式アプリ名：`あしたもつもの`  
Application ID：`com.ashita_motsumono`

この文書はAndroid通知実測からGoogle Play提出までの唯一の実行順を定義します。推奨の操作入口は`tool/release_validation_session.ps1`です。詳細なコマンドは`docs/RELEASE_VALIDATION_SESSION.md`を参照してください。

## 1. 実行順

Issueの順序：

```text
Issue #60 → Issue #98 → Issue #59 → Issue #94
```

機械判定ゲート：

```text
releaseSession
→ issue60
→ playSigning
→ formalRelease
→ playSubmission
→ internalTest
```

`playSigning`と`playSubmission`を分離し、Play App Signingとアップロード証明書が確定した段階で正式AABを生成できるようにします。ストア掲載・データセーフティ・広告申告は正式Release後にIssue #94で完了します。

## 2. 判定原則

- CI成功、静的設定、ビルド、インストール、ローカルAPK起動を実通知・Play配布・広告・課金のPASSとして代用しない。
- 環境診断と通知権限確認後にRelease sessionを開始する。
- Issue #60の3ケース集約まで検証対象masterを実質的に凍結する。
- 3ケースのSource SHAを同一にし、集約時の最新`origin/master`と一致させる。
- Todo作成前後のAlarm登録差分がない場合は通知ケースをPASSにしない。
- 証跡不足は`FAIL`ではなく`INCONCLUSIVE`、環境崩壊は`BLOCKED`とする。
- Play Console、GitHub Actions、APK/AAB、内部テストを同一Source SHAと正式Run IDで関連付ける。
- Secrets、キーストア、パスワード、AdMob ID、Gemini Proxy URLを証跡JSONへ保存しない。

## 3. 単一証跡ルート

```powershell
$evidence = Join-Path $HOME 'Documents\ashita-release-evidence'
```

Issue #60の証跡、Release session、Play Console証跡、release manifest、内部テスト証跡、最終readinessを別ルートへ分散させません。

## 4. 環境診断と初期インストール

```powershell
$sessionTool = '.\tool\release_validation_session.ps1'

& $sessionTool -Action Doctor -EvidenceRoot $evidence
& $sessionTool -Action BuildInstall -EvidenceRoot $evidence
```

APKインストール後、アプリを一度開いて通知権限を許可し、Homeへ戻ります。

必須条件：

- `git`、`python`、`flutter`、`adb`
- host UTC offset=`+09:00`
- `HEAD == origin/master`
- tracked file変更なし
- Emulator=`emulator-5554`
- QEMU、boot完了、Asia/Tokyo
- Application ID=`com.ashita_motsumono`
- 通知権限=`GRANTED`

## 5. Release session開始

```powershell
& $sessionTool -Action StartSession -EvidenceRoot $evidence
```

内部では次を実行します。

```powershell
python .\tool\release_execution_orchestrator.py start-session `
  --root . `
  --output "$evidence\release-session.json"
```

Release session開始後、Issue #60集約まで別PRをmasterへマージしません。Source SHA、`HEAD`、`origin/master`が一致しない場合、ケース処理と集約を拒否します。

## 6. Issue #60：通知実測

各ケースの順序：

```text
PlanCase
→ EmulatorでTodo作成
→ BeginCase
→ 必要なmutation
→ WaitCase
→ FinalizeCase
```

### Normal

```powershell
& $sessionTool -Action PlanCase -CaseType normal -EvidenceRoot $evidence
& $sessionTool -Action BeginCase -CaseType normal -EvidenceRoot $evidence
& $sessionTool -Action WaitCase -CaseType normal -EvidenceRoot $evidence
```

NormalがPASSするまでRebootへ進みません。

### Reboot

```powershell
& $sessionTool -Action PlanCase -CaseType reboot -EvidenceRoot $evidence
& $sessionTool -Action BeginCase -CaseType reboot -EvidenceRoot $evidence
& $sessionTool -Action MutateCase -CaseType reboot -EvidenceRoot $evidence
& $sessionTool -Action WaitCase -CaseType reboot -EvidenceRoot $evidence
```

### install-r

```powershell
& $sessionTool -Action PlanCase -CaseType install-r -EvidenceRoot $evidence
& $sessionTool -Action BeginCase -CaseType install-r -EvidenceRoot $evidence
& $sessionTool -Action MutateCase -CaseType install-r -EvidenceRoot $evidence
& $sessionTool -Action WaitCase -CaseType install-r -EvidenceRoot $evidence
```

集約：

```powershell
& $sessionTool -Action Aggregate -EvidenceRoot $evidence
```

受入条件：

- `Recommendation=ELIGIBLE_FOR_CLOSE_REVIEW`
- Normal=`PASS`
- Reboot=`PASS`
- install-rは`MY_PACKAGE_REPLACED`確認済み`PASS`、または通知証跡完備でbroadcast因果関係だけ未確認の`INCONCLUSIVE`
- Todo作成前後のAlarm登録差分あり
- 3ケースがRelease sessionと同じSource SHA
- 集約前の`git fetch origin`後も最新clean `origin/master`

## 7. Issue #98：playSigning

Play Consoleで次を準備します。

- アプリ作成
- Application ID=`com.ashita_motsumono`
- アプリ名=`あしたもつもの`
- デフォルト言語=`ja`または`ja-JP`
- Play App Signing
- アップロード証明書SHA-256
- 広告削除商品
- 課金商品ID

テンプレート：

```powershell
& $sessionTool -Action WriteTemplates -EvidenceRoot $evidence
```

`CN=Test`を本番鍵と推測しません。Play Consoleと本番アップロードキーストアのSHA-256が一致しなければ正式Releaseへ進みません。

この段階ではプライバシーポリシー登録、ストア掲載、データセーフティ、コンテンツレーティング、広告申告を未完了のままにできます。

## 8. Issue #59：formalRelease

必須GitHub Secrets：

- `KEYSTORE_BASE64`
- `KEYSTORE_STORE_PASSWORD`
- `KEYSTORE_KEY_PASSWORD`
- `KEYSTORE_KEY_ALIAS`
- `ADMOB_APP_ID`
- `ADMOB_BANNER_AD_UNIT_ID`
- `GEMINI_PROXY_URL`

必須Repository Variable：

- `ANDROID_UPLOAD_CERT_SHA256`

任意Repository Variable：

- `IAP_REMOVE_ADS_PRODUCT_ID`（未設定時`remove_ads`）

`Release Android`を`workflow_dispatch`または正式`v*`タグで実行し、次を保存します。

- `ashita-motsumono-signed-release-apk`
- `ashita-motsumono-signed-release-aab`
- `ashita-motsumono-release-evidence`
- `release-manifest.json`

`release-manifest.json`は`$evidence\release-manifest.json`へ保存します。

formalReleaseゲート：

- commit SHAがRelease sessionと一致
- Application ID一致
- Play Console、キーストア、APK、AABの証明書SHA-256一致
- 証明書照合がすべて`matches: true`
- APK/AAB SHA-256が有効
- artifact名、課金商品ID、Run IDが一致

## 9. Issue #94：playSubmission

正式Release後、`play-console-evidence.json`へ次を追記します。

- `privacyPolicyRegistered=true`
- `storeListingComplete=true`
- `dataSafetyComplete=true`
- `contentRatingComplete=true`
- `adsDeclarationComplete=true`

ストア掲載には説明文、アイコン、スクリーンショット、カテゴリ、連絡先を含めます。データセーフティと審査説明を実装・プライバシーポリシーと一致させます。

## 10. Issue #94：internalTest

正式AABをGoogle Play内部テストへアップロードし、Play Store経由でインストールします。

記録項目：

- Source SHA
- 正式Release Run ID
- AABアップロード
- Play経由インストール
- カメラ、画像選択、日本語OCR
- 手入力フォールバック
- 通知表示と通知拒否時Todo登録
- 本番AdMobと広告失敗時フォールバック
- 広告削除価格、購入、広告非表示、購入復元
- AI画像解析の同意、購入、実行
- 全データ削除
- JSONエクスポート

## 11. 統合判定

途中経過：

```powershell
& $sessionTool `
  -Action Evaluate `
  -ReportOnly `
  -EvidenceRoot $evidence
```

低レベルの等価コマンド：

```powershell
python .\tool\release_execution_orchestrator.py evaluate `
  --root . `
  --session "$evidence\release-session.json" `
  --issue60-summary "$evidence\ISSUE60_SUMMARY\issue60-summary.json" `
  --play-console-evidence "$evidence\play-console-evidence.json" `
  --release-manifest "$evidence\release-manifest.json" `
  --internal-test-evidence "$evidence\internal-test-evidence.json" `
  --output-json "$evidence\release-readiness.json" `
  --output-markdown "$evidence\release-readiness.md" `
  --report-only
```

最終強制判定：

```powershell
& $sessionTool -Action Evaluate -EvidenceRoot $evidence
```

提出可能な結果：

```text
READY_FOR_SUBMISSION
```

それ以外は`KEEP_BLOCKED`です。

## 12. Issue更新と提出

- `issue60-summary.md`をIssue #60へ記録
- Play署名証跡をIssue #98へ記録
- 正式Run IDとmanifest結果をIssue #59へ記録
- `release-readiness.md`をIssue #94へ記録
- `READY_FOR_SUBMISSION`後だけ審査提出
- 公開URL取得後にLPへ反映
- Issue #94をClose

## 13. 自動化できない作業

- Emulator上のTodo作成と通知目視
- Play Consoleフォーム入力
- 本番アップロード鍵の作成・保管
- GitHub Secrets／Variablesの値登録
- Play内部テスト配布と実機操作
- AdMob、課金、Gemini Proxyの本番確認
- 審査提出

ツールは外部操作を代行せず、入力された証跡の整合性だけを判定します。
