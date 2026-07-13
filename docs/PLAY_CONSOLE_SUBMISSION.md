# Play Console 提出チェックリスト

Google Play へ初回提出する直前に使う作業順です。ストア掲載文の本文は `docs/STORE_LISTING_JA.md`、署名とAAB生成手順は `docs/ANDROID_RELEASE.md` を参照してください。

## 0. 統合Release gate

通知実測、Play Console署名、正式Release Run、内部テストを別々に完了扱いにせず、`docs/RELEASE_EXECUTION_PLAN.md`の順序で実施します。

```text
Issue #60 → Issue #98 → Issue #59 → Issue #94
```

最終提出前に`tool/release_execution_gate.py evaluate`を実行し、`release-readiness.json`が`READY_FOR_SUBMISSION`であることを確認します。CI成功、ローカルAPK起動、静的Manifest確認だけではこの判定を代用できません。

## 1. ローカル検証

- [x] `dart format` を実行する
- [x] `flutter analyze` を実行する
- [x] `flutter test --no-pub -r compact` を実行する
- [x] 設定画面の表示バージョンが`pubspec.yaml`と一致することをCIで確認する
- [ ] Android実機でカメラ撮影、画像選択、日本語OCR、通知許可、通知予約を確認する
- [ ] 内部テスト版で広告削除の購入・復元を確認する

2026-07-09 時点のローカル結果:

- `flutter analyze`: No issues found
- `flutter test --no-pub -r compact`: All tests passed, 206 tests

## 2. Play Console で事前作成するもの

- [ ] アプリを新規作成する
- [ ] アプリ名を「あしたもつもの」にする
- [ ] デフォルト言語を日本語にする
- [ ] プライバシーポリシーURLを登録する
- [ ] Play App Signingを設定し、アップロード証明書SHA-256を記録する
- [ ] アプリ内商品を作成する
- [ ] 商品IDを GitHub Repository Variable `IAP_REMOVE_ADS_PRODUCT_ID` と一致させる
- [ ] 未設定で進める場合、商品IDを `remove_ads` にする
- [ ] `play-console-evidence.json`へ確認済みの事実だけを記録する

## 3. GitHub に登録する値

Secrets:

- [ ] `KEYSTORE_BASE64`
- [ ] `KEYSTORE_STORE_PASSWORD`
- [ ] `KEYSTORE_KEY_PASSWORD`
- [ ] `KEYSTORE_KEY_ALIAS`
- [ ] `ADMOB_APP_ID`（本番App ID。未設定の場合、Release Android workflowは失敗）
- [ ] `ADMOB_BANNER_AD_UNIT_ID`（本番バナー広告ユニットID。未設定の場合、Release Android workflowは失敗）
- [ ] `GEMINI_PROXY_URL`（AI画像解析用Cloudflare Workers URL。未設定の場合、Release Android workflowは失敗）

Repository Variables:

- [ ] `ANDROID_UPLOAD_CERT_SHA256`（Play Consoleのアップロード証明書SHA-256。必須）
- [ ] `IAP_REMOVE_ADS_PRODUCT_ID`（未設定時は`remove_ads`）

## 4. リリース成果物

- [ ] `Release Android` ワークフローを手動実行、または `v*` タグをpushする
- [ ] 正式Runのcommit SHAが`release-session.json`のSource SHAと一致する
- [ ] 復元したキーストア証明書が`ANDROID_UPLOAD_CERT_SHA256`と一致する
- [ ] APK artifact `ashita-motsumono-signed-release-apk` が生成される
- [ ] APK artifact内の`upload-keystore-certificate.json`と`apk-certificate.json`が`matches: true`
- [ ] APK artifact内の`apk-signature-verification.txt`と`APK_SHA256SUMS`を確認する
- [ ] AAB artifact `ashita-motsumono-signed-release-aab` が生成される
- [ ] AAB artifact内の`upload-keystore-certificate.json`と`aab-certificate.json`が`matches: true`
- [ ] AAB artifact内の`aab-signature-verification.txt`、`aab-signer-certificate.txt`、`AAB_SHA256SUMS`を確認する
- [ ] `release-manifest.json`を統合Release gateへ入力する
- [ ] APK artifact を実機に入れてスモークテストする
- [ ] AAB artifact をPlay Consoleへアップロードする
- [ ] 内部テストトラックでインストールできることを確認する
- [ ] 本番広告ユニットIDを入れた内部テスト版で、広告が読み込まれることを確認する
- [ ] 設定画面のサポーター価格がPlay Consoleの価格で表示されることを確認する
- [ ] `internal-test-evidence.json`へ内部テスト結果を記録する

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

Play Consoleへ登録する回答は、`docs/privacy_policy.md`および実装内容と一致させます。

- [ ] 通常の日本語OCRは端末上で実行し、画像をCloudflare WorkersまたはGoogle Gemini APIへ送信しないことを説明する
- [ ] AI画像解析をユーザーが選択し、外部送信の説明に同意した場合だけ、解析対象の画像、画像形式、解析基準日およびタイムゾーンを、開発者が管理するCloudflare Workers経由でGoogle Gemini APIへ送信することを申告する
- [ ] Cloudflare WorkersはAI画像解析の中継に使用し、人物、Todo、OCR結果、画像を同期・保管する独自バックエンドとしては使用しないことを説明する
- [ ] Google Mobile Adsを広告表示に使用し、広告ID、端末情報、広告の表示・操作情報などが処理される場合があることを申告する
- [ ] Google Play Billingを広告削除の買い切り課金と購入復元に使用し、決済情報をアプリが直接取得しないことを申告する
- [ ] カメラ権限はプリント撮影用、画像選択はOCRまたはAI画像解析用、通知権限はTodoリマインド用と説明する
- [ ] アプリ内削除導線は「設定」>「データ管理」>「登録データをすべて削除」と説明し、人物、Todo、読み取り履歴、保存画像、学習済み持ち物候補が削除対象であることを確認する
- [ ] JSONエクスポートには人物名、Todo、OCR処理済みテキストが含まれる一方、保存画像のファイル本体と端末内画像パスは含まれないことを確認する
- [ ] AI画像解析で外部サービスへ送信済みの情報には、CloudflareおよびGoogleの保持・削除方針が適用されることをプライバシーポリシーと矛盾なく説明する

## 7. 提出直前の判断

- [ ] Issue #60の統合結果が`ELIGIBLE_FOR_CLOSE_REVIEW`
- [ ] Play Console、キーストア、APK、AABのアップロード証明書SHA-256がすべて一致する
- [ ] `release-session.json`、`release-manifest.json`、内部テストのSource SHAが一致する
- [ ] クラッシュやOCR失敗時に、ユーザーが手入力へ戻れることを実機で確認する
- [ ] 通知が許可されていない場合でも、Todo登録自体は継続できることを確認する
- [ ] 広告読み込みに失敗しても主要機能が使えることを確認する
- [ ] 買い切り購入済み状態で広告が非表示になることを確認する
- [ ] 復元ボタンで購入済み状態に戻せることを確認する
- [ ] `release-readiness.json`が`READY_FOR_SUBMISSION`
