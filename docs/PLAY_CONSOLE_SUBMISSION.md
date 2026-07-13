# Play Console 提出チェックリスト

Google Playへ初回提出する作業順です。ストア掲載文は`docs/STORE_LISTING_JA.md`、署名とAAB生成は`docs/ANDROID_RELEASE.md`、全体順序は`docs/RELEASE_EXECUTION_PLAN.md`を参照してください。

## 0. 統合Release gate

```text
Issue #60 → Issue #98 → Issue #59 → Issue #94
```

```text
playSigning → formalRelease → playSubmission → internalTest
```

`playSigning`ではアプリ作成、Play App Signing、アップロード証明書、課金商品だけを要求します。ストア掲載・データセーフティ・広告申告は正式Release後の`playSubmission`で判定します。

最終提出前に`tool/release_execution_orchestrator.py evaluate`を実行し、`release-readiness.json`が`READY_FOR_SUBMISSION`であることを確認します。

## 1. ローカル検証

- [x] `dart format`
- [x] `flutter analyze`
- [x] `flutter test --no-pub -r compact`
- [x] 表示バージョンと`pubspec.yaml`の同期をCIで確認
- [ ] Android実機でカメラ、画像選択、日本語OCR、通知を確認
- [ ] 内部テスト版で広告削除の購入・復元を確認

## 2. playSigning：正式Release前に必要

- [ ] アプリを新規作成
- [ ] Application IDを`com.ashita_motsumono`にする
- [ ] アプリ名を「あしたもつもの」にする
- [ ] デフォルト言語を日本語にする
- [ ] Play App Signingを設定
- [ ] アップロード証明書SHA-256を記録
- [ ] アプリ内商品を作成
- [ ] 商品IDを`IAP_REMOVE_ADS_PRODUCT_ID`と一致させる
- [ ] 未設定の場合、商品IDを`remove_ads`にする
- [ ] `play-console-evidence.json`の署名準備項目を事実に基づき更新
- [ ] 統合ゲートの`playSigning`がPASS

## 3. GitHubに登録する値

Secrets:

- [ ] `KEYSTORE_BASE64`
- [ ] `KEYSTORE_STORE_PASSWORD`
- [ ] `KEYSTORE_KEY_PASSWORD`
- [ ] `KEYSTORE_KEY_ALIAS`
- [ ] `ADMOB_APP_ID`
- [ ] `ADMOB_BANNER_AD_UNIT_ID`
- [ ] `GEMINI_PROXY_URL`

Repository Variables:

- [ ] `ANDROID_UPLOAD_CERT_SHA256`
- [ ] `IAP_REMOVE_ADS_PRODUCT_ID`（未設定時`remove_ads`）

## 4. formalRelease：署名済み成果物

- [ ] `Release Android`を手動実行、または正式`v*`タグをpush
- [ ] Runのcommit SHAが`release-session.json`のSource SHAと一致
- [ ] キーストア証明書が`ANDROID_UPLOAD_CERT_SHA256`と一致
- [ ] `ashita-motsumono-signed-release-apk`が生成
- [ ] APK証明書JSONが`matches: true`
- [ ] APK署名ログと`APK_SHA256SUMS`を確認
- [ ] `ashita-motsumono-signed-release-aab`が生成
- [ ] AAB証明書JSONが`matches: true`
- [ ] AAB署名ログと`AAB_SHA256SUMS`を確認
- [ ] `ashita-motsumono-release-evidence`が生成
- [ ] `release-manifest.json`を保存
- [ ] 統合ゲートの`formalRelease`がPASS

ストア掲載が未完了でも、`playSigning`がPASSしていればこの段階へ進めます。

## 5. playSubmission：ストア掲載

- [ ] プライバシーポリシーURLを登録
- [ ] 短い説明を`docs/STORE_LISTING_JA.md`から転記
- [ ] 詳細説明を転記
- [ ] `assets/store/icon-512.png`を登録
- [ ] スクリーンショット5枚を登録
- [ ] カテゴリを「ツール」に設定
- [ ] 連絡先メールアドレスを登録
- [ ] データセーフティを完了
- [ ] コンテンツレーティングを完了
- [ ] 広告申告を完了
- [ ] カメラ、通知、課金、AI画像解析の審査説明を完了
- [ ] `play-console-evidence.json`の提出項目を事実に基づき更新
- [ ] 統合ゲートの`playSubmission`がPASS

スクリーンショット:

- `assets/store/screenshots/01-home.png`
- `assets/store/screenshots/02-add-todo.png`
- `assets/store/screenshots/03-review-candidates.png`
- `assets/store/screenshots/04-todo-detail.png`
- `assets/store/screenshots/05-settings-supporter.png`

## 6. データセーフティ確認

- [ ] 通常の日本語OCRは端末上で実行し、画像をCloudflare WorkersまたはGoogle Gemini APIへ送信しないことを説明する
- [ ] AI画像解析は、外部送信の説明に同意した場合だけ、解析対象の画像、画像形式、解析基準日およびタイムゾーンを、Cloudflare Workers経由でGoogle Gemini APIへ送信することを申告する
- [ ] Cloudflare Workersは中継用途で、独自同期・保管バックエンドではないことを説明する
- [ ] Google Mobile Adsによる広告関連データ処理を申告する
- [ ] Google Play Billingによる広告削除の購入・復元を申告する
- [ ] カメラ、画像選択、通知権限の用途を説明する
- [ ] 全データ削除対象を確認する
- [ ] JSONエクスポートの包含・除外データを確認する
- [ ] 外部サービスの保持・削除方針とプライバシーポリシーを一致させる

## 7. internalTestと提出直前

- [ ] AABを内部テストへアップロード
- [ ] Play経由でインストール
- [ ] 本番広告表示
- [ ] 広告失敗時も主要機能利用可能
- [ ] 商品価格表示、広告削除の購入・復元、広告非表示を確認
- [ ] AI画像解析の同意、購入、実行
- [ ] OCR失敗時の手入力フォールバック
- [ ] 通知拒否時もTodo登録可能
- [ ] データ削除とJSONエクスポート
- [ ] `internal-test-evidence.json`を更新
- [ ] Source SHAと正式Run IDが全証跡で一致
- [ ] `release-readiness.json`が`READY_FOR_SUBMISSION`
