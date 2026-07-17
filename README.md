# あしたもつもの MVP

園・学校・習い事のプリント、スクショ、連絡文から、今日・明日の持ち物・提出物・集金をTodo化するFlutterアプリです。

## 対象プラットフォーム

現行MVPは **Android/iOS専用** です。

日本語OCRはAndroid/iOS向けのGoogle ML Kit Text Recognitionを使います。Web版、Windows版、macOS版、Linux版は対象外です。

## 実装済み

- 子ども登録・編集・削除
- Todo手入力・編集・完了/未完了・削除
- 画像選択、カメラ撮影、日本語OCR
- Androidで中断された画像選択の起動時復旧
- OCR全文・共有テキストからのTodo候補抽出
- 日付・曜日・金額・持ち物・提出系キーワード抽出
- 登録前の確認・修正と多重登録防止
- 今日、明日、未設定、今後のTodo表示
- チェックリスト、元画像表示
- ローカル通知予約と通知時刻カスタマイズ
- Drift/SQLiteによる端末内保存
- 並行する保存操作の直列化
- SharedPreferences JSONからの厳格な自動移行
- 保存データ破損時のDB退避と復旧導線
- 広告除去・AI分析のアプリ内課金
- バックエンド購入検証と短命AIアクセストークン
- Cloudflare Workers経由の任意AI画像解析
- 単体テスト、ウィジェットテスト、統合テスト

## アーキテクチャ上の前提

- ログインなし
- 家族共有なし
- Todoのクラウド同期なし
- 画像のクラウド保存なし
- 通常OCRは端末内処理
- 購入検証と任意のAI画像解析だけCloudflare Workersを使用
- AI画像は保存せずGemini APIへ中継

## 必要環境

- Flutter **3.44.0**（`.fvmrc`とCIで固定）
- Dart SDK 3.12.0以上
- Java 17
- Android SDK / Xcode（対象プラットフォームに応じて）

## セットアップ

```bash
bash tool/create_platforms.sh
flutter pub get
```

その後、`docs/NATIVE_SETUP.md` に沿ってAndroid/iOSのOCR、通知、権限を設定してください。

## 実行

通常OCRなど、外部AIを使わない機能:

```bash
flutter run
```

AI画像解析を含める場合:

```bash
flutter run \
  --dart-define=GEMINI_PROXY_URL=https://<worker-host> \
  --dart-define=IAP_REMOVE_ADS_PRODUCT_ID=remove_ads \
  --dart-define=IAP_AI_ACCESS_PRODUCT_ID=ai_analysis
```

リリースビルドではlocalhostやHTTPのプロキシURLを拒否します。デバッグビルドだけlocalhostを使用できます。

## テスト

```bash
flutter analyze --no-fatal-infos
flutter test
python3 -m unittest tool/test_generate_release_manifest.py
python3 -m unittest tool/test_release_workflow.py
```

## Cloudflare Workers

Workerは次の経路を提供します。

- `POST /entitlements/verify` — Google Play / Appleの購入証明を検証
- `POST /analyze` — 短命アクセストークンを要求してGemini APIへ画像を中継
- `GET /health` — 非機微な稼働情報

詳細は `workers/gemini-proxy/README.md` を参照してください。

### 必須Worker Secrets

- `GEMINI_API_KEY`
- `ENTITLEMENT_SIGNING_SECRET` — 32バイト以上の暗号学的乱数
- `GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY`

Workerの `wrangler.toml` では、パッケージID、バンドルID、商品ID、画像上限、購入検証・AI解析のRate Limiting bindingを設定します。本番デプロイ前にストア設定と一致させてください。

## Androidリリース生成

GitHub Actionsの`Flutter CI`ワークフローを`workflow_dispatch`で実行するか、`v*`タグをpushすると、署名済みAPKとPlay Store提出用AABを生成します。

```bash
git tag v0.6.0
git push origin v0.6.0
```

### 必須GitHub Secrets

- `KEYSTORE_BASE64`
- `KEYSTORE_STORE_PASSWORD`
- `KEYSTORE_KEY_PASSWORD`
- `KEYSTORE_KEY_ALIAS`
- `ADMOB_APP_ID`
- `ADMOB_BANNER_AD_UNIT_ID`
- `GEMINI_PROXY_URL`

### 必須Repository Variables

- `ANDROID_UPLOAD_CERT_SHA256`
- `IAP_REMOVE_ADS_PRODUCT_ID`
- `IAP_AI_ACCESS_PRODUCT_ID`

### 署名鍵の作成

```bash
keytool -genkeypair \
  -v \
  -keystore upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

作成した`upload-keystore.jks`は安全な場所に保管してください。

Base64エンコード:

```bash
# Linux / Git Bash
base64 -w 0 upload-keystore.jks

# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))
```

### 成果物

- APK: `ashita-motsumono-signed-release-apk`
- AAB: `ashita-motsumono-signed-release-aab`
- 検証証跡: `ashita-motsumono-release-evidence`

`release-manifest.json`には、コミット、バージョン、application ID、両方の課金商品ID、証明書SHA-256、APK/AAB SHA-256、Actions実行情報を記録します。

### セキュリティ

- `upload-keystore.jks`、`key.properties`、Worker秘密鍵はリポジトリへ含めないでください。
- AndroidのDB、画像、設定、購入キャッシュ、障害ログはクラウドバックアップ・端末間転送から除外します。
- AI解析画像は5MB以下、JPEG/PNG/WebPだけを受け付けます。
- Workerは購入検証済みの短命トークンとRate Limitingを要求します。
- 端末内の購入フラグだけでは利用権を付与しません。
- SecretsはCIログへ出力しないでください。

## データとプライバシー

人物名、Todo、OCR全文、画像パスは端末内DBへ保存します。通常OCRの画像は外部へ送信しません。

AI画像解析では、利用者の説明確認と同意後に、購入検証済みトークンを使って画像、MIME形式、基準日、端末タイムゾーンをCloudflare Workers経由でGemini APIへ送信します。

エクスポートは人物名、Todo、OCR全文をJSONとしてクリップボードへコピーし、画像ファイルと端末内画像パスは除外します。

「設定」から全データを削除すると、人物、Todo、読み取り履歴、保存画像、学習済み候補、障害ログ、旧形式・破損DBの退避ファイルを削除対象にします。

詳細は `docs/privacy_policy.md` を参照してください。

## リリース前の外部ゲート

コードとCIだけでは次を完了扱いにしません。

- Cloudflare Workerの本番SecretsとRate Limiting binding
- Play Consoleサービスアカウントの購入確認・acknowledge権限
- Google Play / App Storeの商品IDと価格
- Android/iOS実機での購入、復元、返金・取消、通知、OCR、AI解析
- AdMob同意設定とストア開示
- 公開プライバシーポリシー・問い合わせページ

今後の作業は `docs/TODO.md` を参照してください。
