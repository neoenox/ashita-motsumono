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

必要なSecrets:

- `KEYSTORE_BASE64`
- `KEYSTORE_STORE_PASSWORD`
- `KEYSTORE_KEY_PASSWORD`
- `KEYSTORE_KEY_ALIAS`
- `ADMOB_APP_ID`
- `ADMOB_BANNER_AD_UNIT_ID`

任意のRepository Variables:

- `IAP_REMOVE_ADS_PRODUCT_ID`（未設定の場合は `remove_ads`）

## 3. リリース成果物を作成する

`v*` タグをpushするか、GitHub Actionsから `Flutter CI` ワークフローを手動実行します。

```bash
git tag v0.6.0
git push origin v0.6.0
```

タグpushまたは手動実行で `release-build` ジョブが走り、以下のunsignedなビルド成果物を生成します。Play StoreへはAABを提出します。APKは実機での最終確認に使います。

- APK: `ashita-motsumono-ci-release-apk`（unsigned、CI検証用）
- AAB: `ashita-motsumono-ci-release-aab`（unsigned、CI検証用）

**注意**: 現在のCIはunsignedのビルドです。Play Store提出には、別途ローカルで署名付きAABをビルドするか、CIで `KEYSTORE_BASE64` をデコードするステップを追加してください。

## 4. 提出前の確認

- Android実機でカメラ撮影、画像選択、日本語OCR、通知許可、通知予約を確認する。
- 課金商品ID `remove_ads`、またはRepository Variable `IAP_REMOVE_ADS_PRODUCT_ID` がPlay Console側のアプリ内アイテムと一致していることを確認する。
- AdMobの本番App IDと広告ユニットIDがGitHub Secretsに入っていることを確認する。未設定の場合、`release-build` ジョブは失敗します。
- `ADMOB_BANNER_AD_UNIT_ID` が未設定のビルドではバナー広告を読み込みません。Play Store提出ビルドでは本番広告ユニットIDを必ず設定してください。
- プライバシーポリシーURLをPlay Consoleに登録する。
