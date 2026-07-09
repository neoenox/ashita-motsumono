# Play Console 提出チェックリスト

Google Play へ初回提出する直前に使う作業順です。ストア掲載文の本文は `docs/STORE_LISTING_JA.md`、署名とAAB生成手順は `docs/ANDROID_RELEASE.md` を参照してください。

## 1. ローカル検証

- [x] `dart format` を実行する
- [x] `flutter analyze` を実行する
- [x] `flutter test --no-pub -r compact` を実行する
- [ ] Android実機でカメラ撮影、画像選択、日本語OCR、通知許可、通知予約を確認する
- [ ] 内部テスト版で広告削除の購入・復元を確認する

2026-07-09 時点のローカル結果:

- `flutter analyze`: No issues found
- `flutter test --no-pub -r compact`: All tests passed, 206 tests

## 2. Play Console で事前作成するもの

- [ ] アプリを新規作成する
- [ ] アプリ名を「あした持つもの」にする
- [ ] デフォルト言語を日本語にする
- [ ] プライバシーポリシーURLを登録する
- [ ] アプリ内商品を作成する
- [ ] 商品IDを GitHub Repository Variable `IAP_REMOVE_ADS_PRODUCT_ID` と一致させる
- [ ] 未設定で進める場合、商品IDを `remove_ads` にする

## 3. GitHub に登録する値

Secrets:

- [ ] `KEYSTORE_BASE64`
- [ ] `KEYSTORE_STORE_PASSWORD`
- [ ] `KEYSTORE_KEY_PASSWORD`
- [ ] `KEYSTORE_KEY_ALIAS`
- [ ] `ADMOB_APP_ID`（本番App ID。未設定の場合、Release Android workflowは失敗）
- [ ] `ADMOB_BANNER_AD_UNIT_ID`（本番バナー広告ユニットID。未設定の場合、Release Android workflowは失敗）

Repository Variables:

- [ ] `IAP_REMOVE_ADS_PRODUCT_ID`

## 4. リリース成果物

- [ ] `Release Android` ワークフローを手動実行、または `v*` タグをpushする
- [ ] APK artifact を実機に入れてスモークテストする
- [ ] AAB artifact をPlay Consoleへアップロードする
- [ ] 内部テストトラックでインストールできることを確認する
- [ ] 本番広告ユニットIDを入れた内部テスト版で、広告が読み込まれることを確認する
- [ ] 設定画面のサポーター価格がPlay Consoleの価格で表示されることを確認する

## 5. ストア掲載

- [ ] 短い説明を `docs/STORE_LISTING_JA.md` から転記する
- [ ] 詳細説明を `docs/STORE_LISTING_JA.md` から転記する
- [ ] アプリアイコン `assets/store/icon-512.png` を登録する
- [ ] スクリーンショット5枚を登録する
- [ ] カテゴリを「ツール」にする
- [ ] 連絡先メールアドレスを登録する

スクリーンショット:

- `assets/store/screenshots/01-home.png`
- `assets/store/screenshots/02-add-todo.png`
- `assets/store/screenshots/03-review-candidates.png`
- `assets/store/screenshots/04-todo-detail.png`
- `assets/store/screenshots/05-settings-supporter.png`

## 6. データセーフティと審査メモ

- [ ] 独自サーバーへ子ども名、Todo、OCR全文、画像を送信しないことを明記する
- [ ] Google Mobile Ads を広告表示に使用することを申告する
- [ ] Google Play Billing を広告削除の買い切り課金に使用することを申告する
- [ ] カメラ権限はプリント撮影用と説明する
- [ ] 通知権限はTodoリマインド用と説明する
- [ ] アプリ内削除導線は「設定」>「データ管理」>「登録データをすべて削除」と説明し、人物、Todo、読み取り履歴、保存画像、学習済み持ち物候補が削除対象であることを確認する

## 7. 提出直前の判断

- [ ] クラッシュやOCR失敗時に、ユーザーが手入力へ戻れることを実機で確認する
- [ ] 通知が許可されていない場合でも、Todo登録自体は継続できることを確認する
- [ ] 広告読み込みに失敗しても主要機能が使えることを確認する
- [ ] 買い切り購入済み状態で広告が非表示になることを確認する
- [ ] 復元ボタンで購入済み状態に戻せることを確認する
