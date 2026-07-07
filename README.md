# あした持つもの MVP

園・学校・習い事のプリント、スクショ、連絡文から、今日・明日の持ち物・提出物・集金をTodo化するFlutterアプリです。

## 対象プラットフォーム

現行MVPは **Android/iOS専用** です。

日本語OCRは `google_mlkit_text_recognition` のAndroid/iOS向けネイティブ実装を使います。Web版、Windows版、macOS版、Linux版はこのMVPでは対象外です。

## 実装済み

- 子ども登録・編集・削除
- Todo手入力・編集・完了/未完了・削除
- 画像選択/カメラ撮影
- ML Kit Text Recognition v2による日本語OCR呼び出し
- OCR全文貼り付けからの抽出テスト導線
- 日付・曜日・金額・持ち物・提出系キーワード抽出
- 登録前の確認/修正画面
- 確認画面でキャンセルした場合の一時Document/画像クリーンアップ
- 今日/明日/未設定/今後のTodo表示（検索フィルター付き）
- チェックリスト
- 元画像表示
- ローカル通知予約（前日夜＋当日朝、端末タイムゾーン自動検出）
- 通知時刻カスタマイズ（設定画面）
- 通知時刻変更後の既存Todo通知再予約
- 端末内保存（Drift/SQLite）
- SharedPreferences JSON からの自動移行
- 保存データ破損時のSQLite DB退避情報コピー導線
- 抽出ロジックの単体テスト
- ウィジェットテスト

## MVPの前提

- サーバーなし
- ログインなし
- 家族共有なし
- 画像クラウド保存なし
- P2Pなし
- Cloudflare Workers + D1同期はv0.3以降

## 必要環境

`pubspec.lock` の解決結果に合わせ、Dart SDK は 3.12.0 以上を前提にしています。
`flutter_local_notifications 22.x` は Flutter SDK 3.38.1 以上を要求するため、Flutter は安定版の新しめのバージョンを使ってください。

## セットアップ

Android/iOSのネイティブ雛形生成が必要な場合：

```bash
bash tool/create_platforms.sh
flutter pub get
```

その後、`docs/NATIVE_SETUP.md` に沿ってAndroid/iOSのOCR言語パック、通知、権限を追加してください。

## 実行

```bash
flutter run
```

## テスト

```bash
flutter test
```

## Androidリリース生成

GitHub Actions の `Release Android` ワークフローは、`v*` 形式のタグをpushしたときに署名済みAPKとPlay Store提出用AABを生成します。

```bash
git tag v0.4.1
git push origin v0.4.1
```

事前にGitHub Secretsへ以下を登録してください。

- `KEYSTORE_BASE64`
- `KEYSTORE_STORE_PASSWORD`
- `KEYSTORE_KEY_PASSWORD`
- `KEYSTORE_KEY_ALIAS`
- `ADMOB_APP_ID`
- `ADMOB_BANNER_AD_UNIT_ID`

署名鍵の作成とSecrets登録の詳細は `docs/ANDROID_RELEASE.md` を参照してください。
Google Play ストア掲載文、審査メモ、データセーフティ回答の下書きは `docs/STORE_LISTING_JA.md` を参照してください。
ストア用スクリーンショットは `tool/generate_store_screenshots.py` で `assets/store/screenshots/` に生成できます。

ワークフロー内では Android 雛形を生成し、`tool/configure_android_release.sh` でAndroid向けのOCR・通知・desugaring設定を反映してから `flutter build apk --release` と `flutter build appbundle --release` を実行します。

生成されたAPKは artifact `ashita-motsumono-<tag>-release-apk`、AABは artifact `ashita-motsumono-<tag>-release-aab` からダウンロードできます。

## 今後の作業

今後の作業リストは `docs/TODO.md` にまとめています。

## まず確認する導線

1. 子どもを追加
2. 「追加」→ OCRテキスト貼り付け
3. 以下を貼り付け

```text
7月10日までに水着、帽子、タオルを持参してください。
集金袋に500円を入れて提出してください。
```

4. 候補が作られる
5. 確認画面で修正して登録
6. ホームの「今後の予定」に表示される

## データとプライバシー

端末内保存のみです。子ども名、Todo、OCR全文、元画像パスはDrift/SQLiteデータベースに保存されます。

エクスポート機能は、これらのデータをJSONとしてクリップボードにコピーします。個人情報を含む可能性があるため、貼り付け先に注意してください。

「設定」>「データ管理」から、人物、Todo、読み取り履歴、保存画像を端末内から削除できます。

プライバシーポリシーの提出用下書きは `docs/privacy_policy.md` を参照してください。広告表示とアプリ内課金では Google Mobile Ads / Google Play Billing が通信を行います。

## 注意

- Android/iOSネイティブ設定を行わないと、日本語OCRや通知権限で失敗する可能性があります。
- データ保存はDrift/SQLiteを使用しています。
- ローカル通知は端末タイムゾーンを自動検出します（検出できない場合はJST固定）。
- 通知時刻はアプリ内の設定画面からカスタマイズできます。
