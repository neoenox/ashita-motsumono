# あした持つもの MVP

園・学校・習い事のプリント、スクショ、連絡文から、今日・明日の持ち物・提出物・集金をTodo化するFlutter MVPです。

## 対象プラットフォーム

v0.1 MVPは **Android/iOS専用** です。

日本語OCRは `google_mlkit_text_recognition` のAndroid/iOS向けネイティブ実装を使います。Web版、Windows版、macOS版、Linux版はこのMVPでは対象外です。

## 実装済み

- 子ども登録
- Todo手入力
- 画像選択/カメラ撮影
- ML Kit Text Recognition v2による日本語OCR呼び出し
- OCR全文貼り付けからの抽出テスト導線
- 日付・金額・持ち物・提出系キーワード抽出
- 登録前の確認/修正画面
- 今日/明日/未設定/今後のTodo表示
- チェックリスト
- 元画像表示
- ローカル通知予約
- 端末内保存（SharedPreferences JSON）
- 保存データ破損時の退避データコピー導線
- 抽出ロジックの単体テスト

## MVPの前提

- サーバーなし
- ログインなし
- 家族共有なし
- 画像クラウド保存なし
- P2Pなし
- Cloudflare Workers + D1同期はv0.2以降

## 必要環境

`pubspec.lock` の解決結果に合わせ、Dart SDK は 3.12.0 以上を前提にしています。
`flutter_local_notifications 22.x` は Flutter SDK 3.38.1 以上を要求するため、Flutter は安定版の新しめのバージョンを使ってください。

```bash
flutter --version
flutter pub get
flutter analyze
flutter test
```

## このZIPについて

この実行環境にはFlutter SDKが入っていなかったため、`flutter build` / `flutter test` は未実行です。  
Flutter SDKがある環境で、下記の手順に従ってプロジェクト生成・依存取得・テストを実行してください。

## セットアップ

```bash
unzip ashita_motsumono_mvp.zip
cd ashita_motsumono_mvp

# Android/iOSのネイティブ雛形を生成（既存libを退避・復元）
bash tool/create_platforms.sh

# 依存取得
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

## リリースAPK生成

GitHub Actions の `Release APK` ワークフローは、`v*` 形式のタグをpushしたときにAPKを生成します。

```bash
git tag v0.1.0
git push origin v0.1.0
```

ワークフロー内では Android 雛形を生成し、`tool/configure_android_release.sh` でAndroid向けのOCR・通知・desugaring設定を反映してから `flutter build apk --release` を実行します。

生成されたAPKは、Actionsのartifact `ashita-motsumono-<tag>-release-apk` からダウンロードできます。

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

v0.1は端末内保存のみです。子ども名、Todo、OCR全文、元画像パスはSharedPreferences JSONに保存されます。

エクスポート機能は、これらのデータをJSONとしてクリップボードにコピーします。個人情報を含む可能性があるため、貼り付け先に注意してください。

## 注意

- Android/iOSネイティブ設定を行わないと、日本語OCRや通知権限で失敗する可能性があります。
- v0.1はSharedPreferences JSON保存です。データ量が増える前に、v0.2でDrift/SQLiteへ差し替える想定です。
- ローカル通知はJST固定です。海外利用やDST対応はv0.2以降で `flutter_timezone` 等を追加してください。
