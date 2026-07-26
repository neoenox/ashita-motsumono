# Android Release / Play Store Checklist

Android版をPlay Storeへ提出する署名・成果物手順です。全体順序は`docs/RELEASE_EXECUTION_PLAN.md`を参照してください。

## 1. 前提ゲート

正式Release前に次をPASSさせます。

```text
releaseSession → issue60 → playSigning
```

ストア掲載・データセーフティは`playSubmission`で判定するため、正式Release前の必須条件ではありません。

## 2. 署名鍵を作成する

ローカルで一度だけ作成します。

```bash
keytool -genkeypair \
  -v \
  -keystore upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

鍵は安全に保管し、リポジトリへ追加しません。

## 3. SecretsとVariables

WindowsでキーストアをBase64化します。

```powershell
[Convert]::ToBase64String(
  [IO.File]::ReadAllBytes('upload-keystore.jks')
)
```

必須Secrets：

| Secret | 用途 |
|---|---|
| `KEYSTORE_BASE64` | アップロードキーストア |
| `KEYSTORE_STORE_PASSWORD` | キーストアパスワード |
| `KEYSTORE_KEY_PASSWORD` | 鍵パスワード |
| `KEYSTORE_KEY_ALIAS` | 鍵エイリアス |
| `ADMOB_APP_ID` | 本番AdMob App ID |
| `ADMOB_BANNER_AD_UNIT_ID` | 本番バナー広告ユニットID |
| `GEMINI_PROXY_URL` | AI解析用Cloudflare Workers URL |

必須Repository Variable：

| Variable | 用途 |
|---|---|
| `ANDROID_UPLOAD_CERT_SHA256` | Play Consoleのアップロード証明書SHA-256 |

任意Repository Variable：

| Variable | デフォルト |
|---|---|
| `IAP_REMOVE_ADS_PRODUCT_ID` | `remove_ads` |
| `IAP_AI_ACCESS_PRODUCT_ID` | `ai_analysis` |

## 4. 証明書を照合する

```bash
keytool -list -v \
  -keystore upload-keystore.jks \
  -alias upload
```

Play Consoleのアップロード証明書SHA-256と一致することを確認します。`CN=Test`など意図しない証明書を本番鍵と推測しません。

確認結果は秘密情報を含めず`play-console-evidence.json`へ記録します。

## 5. 正式Releaseを実行する

`workflow_dispatch`または正式`v*`タグを使用します。

```bash
git tag v0.6.3
git push origin v0.6.3
```

生成される正式artifact：

- `ashita-motsumono-signed-release-apk`
- `ashita-motsumono-signed-release-aab`
- `ashita-motsumono-release-evidence`

正式Runのcommit SHAが`release-session.json`の`sourceSha`と一致しない場合、その成果物を流用しません。

## 6. CIの署名・ハッシュ検証

Release Androidジョブは次の順で検証します。

1. キーストア証明書のSHA-256を計算
2. APKを`apksigner verify --verbose --print-certs`で検証
3. AABを`jarsigner -verify -verbose -certs`で検証
4. `keytool -printcert -jarfile`でAAB証明書を取得
5. キーストア、APK、AABを`ANDROID_UPLOAD_CERT_SHA256`と照合
6. APK/AABのSHA-256を記録・再照合
7. すべて成功した場合だけ`release-manifest.json`を生成

APK artifact：

- `upload-keystore-certificate.json`
- `apk-signature-verification.txt`
- `apk-certificate.json`
- `APK_SHA256SUMS`
- `release-manifest.json`

AAB artifact：

- `upload-keystore-certificate.json`
- `aab-signature-verification.txt`
- `aab-signer-certificate.txt`
- `aab-certificate.json`
- `AAB_SHA256SUMS`
- `release-manifest.json`

`release-manifest.json`にはcommit、ref、Run ID、version、Application ID、証明書、artifact名、APK/AABハッシュ、両方の課金商品IDを記録します。秘密鍵、パスワード、AdMob ID、Gemini URLは記録しません。

## 7. formalReleaseゲート

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

正式Release直後は、`formalRelease=PASS`、`playSubmission`または`internalTest=BLOCKED`でも正常です。後続作業を完了するまで全体判定は`KEEP_BLOCKED`です。

## 8. セキュリティ

- `.jks`、`.keystore`、`key.properties`、証明書DERをcommitしない
- パスワードと秘密鍵はSecretsのみで管理
- SHA-256は公開情報としてRepository Variableへ登録可能
- 証跡JSONへSecretsを記録しない
- PRや通常pushでは署名済みPlay成果物を生成しない

## 9. 提出前確認

- [ ] 最新master CI成功
- [ ] Release session Source SHAが最新clean `origin/master`と一致
- [ ] Issue #60ゲートPASS
- [ ] `playSigning`ゲートPASS
- [ ] 正式Release Run成功
- [ ] 証明書照合がすべて`matches: true`
- [ ] APK/AAB SHA-256一致
- [ ] `formalRelease`ゲートPASS
- [ ] `playSubmission`ゲートPASS
- [ ] AABを内部テストへアップロードしPlay経由インストール
- [ ] 広告、課金、AI、OCR、通知、削除、エクスポート確認
- [ ] `internalTest`ゲートPASS
- [ ] 最終判定`READY_FOR_SUBMISSION`
