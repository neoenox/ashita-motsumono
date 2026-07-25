# TODO / リリース前作業

このファイルは、ストア提出前に残っている作業と、今回の仕上げで完了した項目をまとめます。Play Console での実作業順は `docs/PLAY_CONSOLE_SUBMISSION.md`、ゲート順は `docs/RELEASE_EXECUTION_PLAN.md` を正とします。

## 現在の判断

- UIビジュアルリフレッシュはmasterへ実装済みです。`AppTheme`、カテゴリ色帯、スペーシング定数、空状態改善を追加で作り直さず、v0.6.3ではリリース候補APKの実機表示とLPスクリーンショットだけを最終確認します。
- リリースゲート修正PR #133をマージし、最新masterのFlutter CIが成功した時点で機能・UI変更を凍結します。
- 実行順は `Issue #60 → Issue #98 → Issue #59 → Issue #94`、機械判定は `releaseSession → issue60 → playSigning → formalRelease → playSubmission → internalTest` です。
- UIの追加調整、全体format、同期機能など、リリース阻害でない変更はv0.7以降へ送ります。

## P0: コード凍結前のゲート

- [ ] PR #133のFlutter CI、Release Execution Gate CI、関連チェックをすべて成功させ、Ready for reviewへ変更してmasterへマージする。
- [ ] PR #133マージ後の最新masterでFlutter CI、全テスト、LPスクリーンショット生成・検証が成功することを確認する。
- [ ] 失敗が再現する場合はログから原因を特定し、テストskip・握りつぶしではなく回帰修正を行う。

## P0: リリース前に確認すること

- [ ] Issue #60のAndroid Emulator検証を最新clean `origin/master`で実施し、Normal / Reboot / install-rを集約して`issue60`ゲートをPASSさせる。
- [ ] Play Consoleでアプリ、Play App Signing、アップロード証明書SHA-256を確認し、Repository Variable `ANDROID_UPLOAD_CERT_SHA256`へ登録する。
- [ ] Play Consoleで広告削除とAI分析の課金商品を作成し、`IAP_REMOVE_ADS_PRODUCT_ID`と`IAP_AI_ACCESS_PRODUCT_ID`を正式設定と一致させる。
- [ ] 本番Cloudflare WorkerをSecrets、Google Play購入検証、Gemini中継、Rate Limitingを含む設定でデプロイし、`/health`、購入検証、AIトークン発行、中継を確認する。
- [ ] GitHub Actions の `Release Android` を`workflow_dispatch`で実行し、署名済みAPK/AAB/evidence artifactが生成されることを確認する。
- [ ] `release-manifest.json`のcommit SHA、Run ID、version、application ID、両方の課金商品ID、証明書、APK/AAB SHA-256が正式Release対象と一致することを確認する。
- [ ] APK artifactをAndroid実機に入れ、カメラ撮影、画像選択、日本語OCR、通知許可、通知予約、主要画面の表示崩れを確認する。
- [ ] Play Console に `docs/STORE_LISTING_JA.md` の掲載文、データセーフティ回答、審査メモを転記する。
- [ ] Play Console にプライバシーポリシー公開URL、連絡先メールアドレス、カテゴリ、スクリーンショット、アプリアイコンを登録する。
- [ ] 正式AABを内部テストへ配布し、Play経由インストールで本番AdMob、広告削除とAI分析の価格表示・購入・復元、広告非表示、AI解析を確認する。
- [ ] 通知拒否、OCR失敗、広告失敗、購入取消・返金などのフォールバック時も主要機能とデータが壊れないことを確認する。
- [ ] `release_validation_session.ps1 -Action Evaluate`の最終結果が`READY_FOR_SUBMISSION`になった後だけ審査提出する。
- [ ] 提出直前に `docs/PLAY_CONSOLE_SUBMISSION.md` の未完了項目を上から順に確認する。
- [x] PR #104 merge後は追加のCI機能開発を原則停止し、Play Console設定と正式Release証跡確認へ進む。（PR #104, #111, #114, #115, #116 マージ済み）

## 今回対応済み

- [x] UIビジュアルリフレッシュのテーマ集中管理、カテゴリ色帯、スペーシング定数化、空状態改善をmasterへ反映する。
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

- [ ] UI実機確認で見つかった非blockingな視覚調整をまとめて実施する。
- [ ] Dart format既存負債を専用PRで解消する。（Issue #112）
- [ ] Cloudflare Workers + D1 同期の仕様を再設計する。
- [ ] 同期前提の変更キューをDriftに追加する。
- [ ] 家族共有は需要検証後に実装判断する。
- [ ] 画像/PDF同期はTodo同期より後に検討する。
