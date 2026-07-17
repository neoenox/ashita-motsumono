# TODO / リリース前作業

このファイルは、ストア提出前に残っている作業と、今回の仕上げで完了した項目をまとめます。Play Console での実作業順は `docs/PLAY_CONSOLE_SUBMISSION.md` を正とします。

## リリース前に確認すること

- [ ] PR #119の最新HEADではFlutter CI成功を確認していない。リポジトリ所有者判断でレビュー準備ゲートからは外したが、本番リリース前に全テストとLP画像検証を別途実施する。
- [ ] Play Consoleのアップロード証明書SHA-256を確認し、Repository Variable `ANDROID_UPLOAD_CERT_SHA256`へ登録する。
- [ ] GitHub Actions の `Release Android` を手動実行し、署名済みAPK/AAB artifact が生成されることを確認する。
- [ ] `release-manifest.json`のcommit SHA、Run ID、version、application ID、課金商品ID、APK/AAB SHA-256が正式Release対象と一致することを確認する。
- [ ] APK artifact をAndroid実機に入れ、カメラ撮影、画像選択、日本語OCR、通知許可、通知予約を確認する。
- [ ] 内部テスト版で広告削除とAI分析の購入・復元を確認する。
- [ ] 本番AdMob App ID / 広告ユニットIDで広告が読み込まれ、購入済み状態では非表示になることを確認する。
- [ ] Cloudflare Workerを本番設定でデプロイし、Google Play購入検証、AIトークン発行、Gemini中継、Rate Limitingを確認する。
- [ ] Play Console に `docs/STORE_LISTING_JA.md` の掲載文、データセーフティ回答、審査メモを転記して確認する。
- [ ] Play Console にプライバシーポリシー公開URL、連絡先メールアドレス、カテゴリ、スクリーンショット、アプリアイコンを登録する。
- [ ] 提出直前に `docs/PLAY_CONSOLE_SUBMISSION.md` の未完了項目を上から順に確認する。
- [x] PR #104 merge後は追加のCI機能開発を原則停止し、Play Console設定と正式Release証跡確認へ進む。（PR #104, #111, #114, #115, #116 マージ済み）

## 今回対応済み

- [x] 確認画面で登録せず戻った場合に、一時Documentと元画像を削除する。
- [x] 画像なしのOCR貼り付けDocumentを、キャンセル時に確実に削除する回帰テストを追加する。
- [x] 通知時刻変更後、登録済みの未完了Todo通知を再予約する。
- [x] チェックリスト項目のON/OFFだけでは通知を再予約しない。
- [x] Drift/SQLite読み込み失敗時にDB退避コピー情報を残す。
- [x] DriftStoreの保存/読込/破損退避テストを追加する。
- [x] 抽出ルールに曜日表現、相対日付、曖昧な期限、園・学校向け持ち物辞書を追加する。
- [x] 1つの連絡文から「持ち物」「提出」「集金」を複数Todo候補に分割する。
- [x] OCR誤認識補正を追加する。
- [x] ユーザーが修正した項目を辞書候補に反映できるようにする。
- [x] Todo一覧に子ども別フィルターと完了済み表示切り替えを追加する。
- [x] Android release signing と AAB ビルドworkflowを追加する。
- [x] AdMob本番ID・Google Play Billing商品ID・購入復元の提出前ガードを追加する。
- [x] Play Console 用のストア掲載文、スクリーンショット、アプリアイコン、提出チェックリストを作成する。
- [x] プライバシーポリシー、データ削除導線、JSONエクスポート説明を整備する。
- [x] 設定画面のバージョン表示を`pubspec.yaml`から生成し、CIで同期を検証する。
- [x] Release AndroidでAPK/AABの署名を自動検証し、検証ログとSHA-256をartifactへ保存する。
- [x] リリースビルドの広告削除・AI分析商品IDをRepository Variableから取得し、未設定時は明示的に失敗させる。
- [x] Play Consoleで確認したアップロード証明書SHA-256を、キーストア・APK・AABの3段階で照合するCIガードを追加する。
- [x] 証明書照合・バイナリ再ハッシュ後に`release-manifest.json`を生成し、APK/AABと監査証跡artifactへ保存する。
- [x] AIアクセストークン更新とGoogle OAuthトークン取得の重複リクエストを抑止する。
- [x] クラッシュログ書き込みと副作用再試行の競合を防止する。

## v0.7以降の候補

- [ ] Cloudflare Workers + D1 同期の仕様を再設計する。
- [ ] 同期前提の変更キューをDriftに追加する。
- [ ] 家族共有は需要検証後に実装判断する。
- [ ] 画像/PDF同期はTodo同期より後に検討する。
