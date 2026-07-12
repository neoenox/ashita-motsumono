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

## 2. GitHub Secretsを登録する

`upload-keystore.jks` をBase64化して `KEYSTORE_BASE64` に登録します。本番リリースビルドでは、署名情報に加えてAdMob本番IDも必須です。

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
| `GEMINI_PROXY_URL` | Cloudflare WorkersのGeminiプロキシURL（AI解析を使う場合） |

### 任意のRepository Variables

| Variable | デフォルト | 説明 |
|---|---|---|
| `IAP_REMOVE_ADS_PRODUCT_ID` | `remove_ads` | 広告除去商品ID |

## 3. リリース成果物を作成する

`v*` タグをpushするか、GitHub Actionsから `Flutter CI` ワークフローを手動実行します。

```bash
git tag v0.6.0
git push origin v0.6.0
```

タグpushまたは手動実行で `release-build` ジョブが走り、以下の署名済みビルド成果物を生成します。Play StoreへはAABを提出します。APKは実機での最終確認に使います。

- APK: `ashita-motsumono-signed-release-apk`
- AAB: `ashita-motsumono-signed-release-aab`（Play Console提出用）

`release-build`は署名Secretsを事前検証し、不足していればビルド前に失敗します。Gradle設定はreleaseへdebug署名を割り当てません。署名情報なしでローカルreleaseタスクを直接実行して生成された未署名成果物は、Play Consoleへ提出しないでください。

## 4. AABの署名を確認する

Actions artifactを展開し、JDKの`jarsigner`で確認します。

```bash
jarsigner -verify -verbose -certs app-release.aab
```

終了コードが0で、出力に`jar verified.`が含まれることを確認してください。警告だけで判断せず、終了コードと署名者証明書を記録します。

APKはAndroid SDKの`apksigner`で確認できます。

```bash
apksigner verify --verbose --print-certs app-release.apk
```

## 5. セキュリティ警告

- `upload-keystore.jks`、`key.properties`はリポジトリに含めないでください。
- `.gitignore` により以下が除外されています:
  - `android/app/*.jks`
  - `android/app/*.keystore`
  - `android/key.properties`
  - `android/*.jks`
  - `android/*.keystore`
- Secretsの値はCIログに出力されません（`::add-mask::`でマスクされます）。
- PRや通常pushの`analyze-and-test`ジョブは署名済みPlay成果物を生成しません。

## 6. 提出前の確認

- 最新masterの`analyze-and-test`が成功している。
- 対象タグまたは手動実行の`release-build`が成功している。
- `ashita-motsumono-signed-release-aab`をダウンロードし、署名を検証した。
- Android実機でカメラ撮影、画像選択、日本語OCR、通知許可、通知予約を確認する。
- 課金商品ID `remove_ads`、またはRepository Variable `IAP_REMOVE_ADS_PRODUCT_ID` がPlay Console側のアプリ内アイテムと一致していることを確認する。
- AdMobの本番App IDと広告ユニットIDがGitHub Secretsに入っていることを確認する。未設定の場合、`release-build`ジョブは失敗します。
- `ADMOB_BANNER_AD_UNIT_ID`が未設定のビルドではバナー広告を読み込みません。Play Store提出ビルドでは本番広告ユニットIDを必ず設定してください。
- プライバシーポリシーURLをPlay Consoleに登録する。
