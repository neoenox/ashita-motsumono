# Android Release / Play Store Checklist

Android版をPlay Storeへ提出するための最小手順です。署名鍵やパスワードはリポジトリに置かず、GitHub Secretsに登録します。

## 1. 署名鍵を作成する

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

作成した `upload-keystore.jks` は安全な場所に保管してください。紛失すると同じアプリの更新が難しくなります。

## 2. GitHub SecretsとVariablesを登録する

`upload-keystore.jks` をBase64化して `KEYSTORE_BASE64` に登録します。本番リリースビルドでは、署名情報に加えてAdMob本番ID、AI解析用プロキシURL、Play Consoleと照合したアップロード証明書SHA-256が必須です。

```bash
base64 -w 0 upload-keystore.jks
```

Windows PowerShellの場合:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))
```

### 必須Secrets

| Secret | 説明 |
|---|---|
| `KEYSTORE_BASE64` | `upload-keystore.jks` をbase64エンコードした文字列 |
| `KEYSTORE_STORE_PASSWORD` | キーストアのパスワード |
| `KEYSTORE_KEY_PASSWORD` | 鍵のパスワード |
| `KEYSTORE_KEY_ALIAS` | 鍵のエイリアス（例: `upload`） |
| `ADMOB_APP_ID` | 本番AdMob App ID（`ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy`） |
| `ADMOB_BANNER_AD_UNIT_ID` | 本番バナー広告ユニットID（`ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz`） |
| `GEMINI_PROXY_URL` | Cloudflare WorkersのGeminiプロキシURL |

### 必須Repository Variable

| Variable | 説明 |
|---|---|
| `ANDROID_UPLOAD_CERT_SHA256` | Play Consoleの「アプリの署名」に表示されるアップロード証明書SHA-256。コロン付き・なしのどちらでも可 |

ローカルキーストアのSHA-256は、次のいずれかで確認します。

```bash
keytool -list -v \
  -keystore upload-keystore.jks \
  -alias upload
```

または、証明書DERのSHA-256を直接計算します。

```bash
keytool -exportcert \
  -keystore upload-keystore.jks \
  -alias upload \
  -file upload-certificate.der
sha256sum upload-certificate.der
rm upload-certificate.der
```

Play Consoleに表示されるアップロード証明書SHA-256とローカル結果が一致することを確認してから、`ANDROID_UPLOAD_CERT_SHA256`へ登録してください。`CN=Test`など意図しない証明書の場合は、本番用アップロード鍵へ差し替えてから進めます。

### 任意のRepository Variable

| Variable | デフォルト | 説明 |
|---|---|---|
| `IAP_REMOVE_ADS_PRODUCT_ID` | `remove_ads` | 広告除去商品ID。設定時はPlay Consoleの商品IDと一致させる |

## 3. リリース成果物を作成する

`v*` タグをpushするか、GitHub Actionsから `Flutter CI` ワークフローを手動実行します。

```bash
git tag v0.6.3
git push origin v0.6.3
```

タグpushまたは手動実行で `release-build` ジョブが走り、以下の署名済みビルド成果物を生成します。Play StoreへはAABを提出します。APKは実機での最終確認に使います。

- APK artifact: `ashita-motsumono-signed-release-apk`
- AAB artifact: `ashita-motsumono-signed-release-aab`（Play Console提出用）

`release-build`は署名Secretsと必須Variableを事前検証し、不足していればビルド前に失敗します。Gradle設定はreleaseへdebug署名を割り当てません。署名情報なしでローカルreleaseタスクを直接実行して生成された未署名成果物は、Play Consoleへ提出しないでください。

## 4. CIによる証明書・署名・ハッシュ検証

Release Androidジョブは、ビルド前に復元したキーストア証明書を確認し、artifactをアップロードする前にAPK/AABの署名証明書を確認します。いずれかが`ANDROID_UPLOAD_CERT_SHA256`と一致しない場合は停止します。

検証順:

1. `upload-keystore.jks`から証明書をDER出力し、SHA-256を計算
2. APKを`apksigner verify --verbose --print-certs`で検証し、署名証明書SHA-256を照合
3. AABを`jarsigner -verify -verbose -certs`で検証
4. `keytool -printcert -jarfile`でAAB署名証明書SHA-256を取得して照合
5. APK/AAB本体のSHA-256を記録

APK artifactには次が含まれます。

- `upload-keystore-certificate.json`
- `apk-signature-verification.txt`
- `apk-certificate.json`
- `APK_SHA256SUMS`

AAB artifactには次が含まれます。

- `upload-keystore-certificate.json`
- `aab-signature-verification.txt`
- `aab-signer-certificate.txt`
- `aab-certificate.json`
- `AAB_SHA256SUMS`

各`*-certificate.json`の`matches`が`true`で、`expectedSha256`と`actualSha256`がPlay Consoleのアップロード証明書と一致することを確認してください。artifactをダウンロードした後、提出対象ファイルのSHA-256が同梱ファイルと一致することも確認します。

## 5. セキュリティ警告

- `upload-keystore.jks`、`key.properties`、証明書DERはリポジトリに含めないでください。
- `.gitignore` により以下が除外されています:
  - `android/app/*.jks`
  - `android/app/*.keystore`
  - `android/key.properties`
  - `android/*.jks`
  - `android/*.keystore`
- Secretsの値はCIログに出力されません（`::add-mask::`でマスクされます）。
- 証明書SHA-256は公開情報のためRepository Variableに保存します。秘密鍵やパスワードは必ずSecretsを使用します。
- PRや通常pushの`analyze-and-test`ジョブは署名済みPlay成果物を生成しません。
- GitHub ActionsのSecretsはリポジトリへcommitせず、Release Android実行時だけ参照します。

## 6. 提出前の確認

- 最新masterの`analyze-and-test`が成功している。
- Play Consoleのアップロード証明書SHA-256を`ANDROID_UPLOAD_CERT_SHA256`へ登録した。
- 対象タグまたは手動実行の`release-build`が成功している。
- キーストア・APK・AABの3つの証明書照合JSONがすべて`matches: true`である。
- `ashita-motsumono-signed-release-apk`内の署名検証ログとSHA-256を確認した。
- `ashita-motsumono-signed-release-aab`内の署名検証ログとSHA-256を確認した。
- Android実機でカメラ撮影、画像選択、日本語OCR、通知許可、通知予約を確認する。
- 課金商品ID `remove_ads`、またはRepository Variable `IAP_REMOVE_ADS_PRODUCT_ID` がPlay Console側のアプリ内アイテムと一致していることを確認する。
- AdMobの本番App IDと広告ユニットIDがGitHub Secretsに入っていることを確認する。未設定の場合、`release-build`ジョブは失敗します。
- GeminiプロキシURLがGitHub Secretsに入っていることを確認する。未設定の場合、`release-build`ジョブは失敗します。
- `ADMOB_BANNER_AD_UNIT_ID`が未設定のビルドではバナー広告を読み込みません。Play Store提出ビルドでは本番広告ユニットIDを必ず設定してください。
- プライバシーポリシーURLをPlay Consoleに登録する。
