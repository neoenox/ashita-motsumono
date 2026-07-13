# Android Release Execution Plan

対象リポジトリ：`kaenozu/ashita-motsumono`  
正式アプリ名：`あしたもつもの`  
Application ID：`com.ashita_motsumono`

この文書はAndroid通知実測からGoogle Play提出までの唯一の実行順を定義します。CI成功、静的設定、ローカルAPK起動を、実通知・Play配布・広告・課金のPASSとして代用しません。

## 1. 実行順

Issueの順序：

```text
Issue #60 → Issue #98 → Issue #59 → Issue #94
```

機械判定ゲートの順序：

```text
releaseSession
→ issue60
→ playSigning
→ formalRelease
→ playSubmission
→ internalTest
```

`playSigning`と`playSubmission`を分離する理由は、Play App Signingとアップロード証明書を確定すれば正式AABを生成できる一方、ストア掲載・データセーフティ・広告申告は正式Release後もIssue #94内で完了できるためです。

## 2. 判定原則

- Issue #60の3ケースが終わるまで検証対象masterを実質的に凍結する。
- 3ケースのSource SHAは同一で、集約時点の最新`origin/master`と一致させる。
- Android 13以降の通知実測では`POST_NOTIFICATIONS`を許可済みにする。
- Play Console、GitHub Actions、APK/AAB、内部テストを同一Source SHAと正式Run IDで関連付ける。
- 証跡不足は`PASS`ではなく`BLOCKED`または`INCONCLUSIVE`とする。
- Secrets、キーストア、パスワード、AdMob ID、Gemini Proxy URLは証跡JSONへ記録しない。

## 3. Release sessionを開始する

```powershell
git fetch origin
git worktree add C:\wt\release origin/master
cd C:\wt\release

$evidence = Join-Path $HOME 'Documents\ashita-release-evidence'
New-Item -ItemType Directory -Force $evidence | Out-Null

python .\tool\release_execution_orchestrator.py start-session `
  --root . `
  --output "$evidence\release-session.json"
```

開始条件：

- `HEAD == origin/master`
- 追跡対象ファイルにローカル変更なし
- リポジトリ、Application ID、Source SHAを記録可能

Issue #60の集約まで別PRをmasterへマージしません。`origin/master`が移動した場合はRelease sessionを作り直します。

## 4. Issue #60：Android Emulator通知実測

`docs/ISSUE60_ANDROID_EMULATOR_VALIDATION.md`に従い、`emulator-5554`で次を別々の未来Todoとして実測します。

1. 通常状態
2. Emulator再起動後
3. `adb install -r`後

```powershell
.\tool\issue60_emulator_evidence.ps1 `
  -Action Aggregate `
  -CaseName ISSUE60_SUMMARY `
  -NormalCaseName NORMAL_HHMM `
  -RebootCaseName REBOOT_HHMM `
  -InstallCaseName UPDATE_HHMM
```

受入条件：

- `Recommendation=ELIGIBLE_FOR_CLOSE_REVIEW`
- Normal=`PASS`
- Reboot=`PASS`
- install-rは、`MY_PACKAGE_REPLACED`確認済み`PASS`、または通知証跡が完全でbroadcast因果関係だけ未確認の`INCONCLUSIVE`
- 3ケースがRelease sessionと同じSource SHA

## 5. Issue #98：playSigning

Play Consoleでアプリを作成し、Play App Signing、アップロード証明書、広告削除商品を準備します。

```powershell
python .\tool\release_execution_orchestrator.py write-template `
  --kind play-console `
  --output "$evidence\play-console-evidence.json"
```

この段階で必須：

- `appCreated=true`
- Application ID=`com.ashita_motsumono`
- アプリ名=`あしたもつもの`
- デフォルト言語=`ja`または`ja-JP`
- `playAppSigningEnabled=true`
- Play Consoleのアップロード証明書SHA-256
- `iapProductCreated=true`
- 課金商品ID

この段階では次をまだ`false`のままにできます。

- `privacyPolicyRegistered`
- `storeListingComplete`
- `dataSafetyComplete`
- `contentRatingComplete`
- `adsDeclarationComplete`

`CN=Test`を本番鍵と推測しません。Play Consoleとキーストアのアップロード証明書が一致しなければ正式Releaseへ進みません。

## 6. Issue #59：formalRelease

GitHub SecretsとRepository Variablesを登録し、`Release Android`を`workflow_dispatch`または正式`v*`タグで実行します。

必須Secrets：

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

保存する成果物：

- `ashita-motsumono-signed-release-apk`
- `ashita-motsumono-signed-release-aab`
- `ashita-motsumono-release-evidence`
- `release-manifest.json`

formalReleaseゲートは次を強制します。

- commit SHAがRelease sessionと一致
- Application IDが一致
- Play Console、キーストア、APK、AABの証明書SHA-256が一致
- 証明書照合がすべて`matches: true`
- APK/AAB SHA-256が有効
- artifact名と課金商品IDが一致
- GitHub Actions Run IDが正の整数

ストア掲載未完了でも、`playSigning`がPASSしていればformalReleaseは独立してPASSできます。

## 7. Issue #94：playSubmission

正式Release後、同じ`play-console-evidence.json`へ確認済み事実を追記します。

必須：

- `privacyPolicyRegistered=true`
- `storeListingComplete=true`
- `dataSafetyComplete=true`
- `contentRatingComplete=true`
- `adsDeclarationComplete=true`

ストア掲載には説明文、アイコン、スクリーンショット、カテゴリ、連絡先を含めます。データセーフティと審査説明は実装およびプライバシーポリシーと一致させます。

## 8. Issue #94：internalTest

正式AABをGoogle Play内部テストへアップロードし、Play Store経由でインストールします。

```powershell
$sourceSha = (Get-Content "$evidence\release-session.json" -Raw |
  ConvertFrom-Json).sourceSha

python .\tool\release_execution_orchestrator.py write-template `
  --kind internal-test `
  --source-sha $sourceSha `
  --output "$evidence\internal-test-evidence.json"
```

確認項目：

- AABアップロードとPlay経由インストール
- カメラ、画像選択、日本語OCR
- 手入力フォールバック
- 通知表示と通知拒否時のTodo登録
- 本番AdMob広告と広告失敗時フォールバック
- 広告削除購入、広告非表示、購入復元
- AI画像解析の同意、購入、実行
- 全データ削除とJSONエクスポート

`sourceSha`と`releaseRunId`をRelease sessionおよび正式manifestと一致させます。

## 9. 統合判定

```powershell
python .\tool\release_execution_orchestrator.py evaluate `
  --root . `
  --session "$evidence\release-session.json" `
  --issue60-summary "$evidence\ISSUE60_SUMMARY\issue60-summary.json" `
  --play-console-evidence "$evidence\play-console-evidence.json" `
  --release-manifest "$evidence\release-manifest.json" `
  --internal-test-evidence "$evidence\internal-test-evidence.json" `
  --output-json "$evidence\release-readiness.json" `
  --output-markdown "$evidence\release-readiness.md"
```

途中経過の報告だけを生成する場合は`--report-only`を付けます。

提出可能な最終判定：

```text
READY_FOR_SUBMISSION
```

それ以外は`KEEP_BLOCKED`です。

## 10. Issue更新と提出

`release-readiness.md`をIssue #94へ記録し、Issue #60、#98、#59の証跡と相互参照します。

`READY_FOR_SUBMISSION`後にのみ：

1. Play Consoleの警告がないことを再確認
2. 審査提出
3. 公開URL取得
4. LPへGoogle Play URL反映
5. Issue #94をClose

## 11. 自動化できない作業

次は認証済み外部環境で人間が実行します。

- ユーザーPC上の`emulator-5554`操作と通知目視
- Play Consoleアプリ作成・フォーム入力
- 本番アップロード鍵の作成と保管
- GitHub Secrets／Variablesの値登録
- Play内部テスト配布と実機操作
- AdMob、課金、Gemini Proxyの本番確認
- 審査提出

統合ゲートは外部操作を代行せず、入力された証跡の整合性だけを判定します。
