# ストア開示整合性チェックリスト

基準日: 2026年7月14日

本チェックリストは、アプリ実装、権限、SDK、プライバシーポリシー、サポートページ、Google Play Data safety、Apple App Privacyの矛盾を防ぐために使用します。

## 判定

- **PASS**: 実装・設定・文書・実機証跡が一致
- **FAIL**: 矛盾または誤記がある
- **BLOCKED**: 管理画面、正式ビルド、実機等がなく確認不能
- **N/A**: 対象外で理由を記録

1項目でもFAILまたは重大なBLOCKEDがある場合、ストア回答を確定・提出しません。

## 1. 対象の固定

- [ ] 検証日を記録
- [ ] 対象commit SHAを記録
- [ ] Android versionName/versionCodeを記録
- [ ] iOS version/buildを記録
- [ ] Application ID / Bundle IDを記録
- [ ] 正式APK/AAB/IPA/TestFlight buildの識別情報を記録
- [ ] `pubspec.lock`の依存SDKバージョンを保存
- [ ] Android merged manifestを保存
- [ ] iOS Info.plist、Privacy Manifest、entitlementsを保存

## 2. ブランド・URL

- [ ] アプリ内表示名、Google Play名、App Store名が「あしたもつもの」で一致
- [ ] プライバシーポリシーURLがHTTPS、公開、ログイン不要
- [ ] サポートURLがHTTPS、公開、ログイン不要
- [ ] アプリ内リンクとストア登録URLが一致
- [ ] 問い合わせ先が実際に受信・返信可能
- [ ] 削除相談を受け付ける方法がある
- [ ] 制定日・改定日が公開版と一致

## 3. 端末内データ

- [ ] 人物、Todo、チェックリスト、読み取り文書、画像、学習済み候補をインベントリへ記載
- [ ] 通知ID、通知同期キュー、画像削除キューを記載
- [ ] 購入済みフラグを記載
- [ ] `crash.log`が端末内のみで自動送信されない説明と実装が一致
- [ ] DB破損退避ファイルの存在と削除/保持上の注意を記載
- [ ] ログイン・独自同期・家族共有がない説明と実装が一致
- [ ] OSバックアップ対象範囲を断定していない

## 4. カメラ・写真・OCR

- [ ] AndroidのCAMERA権限と用途説明が一致
- [ ] iOSのカメラ/写真説明文と用途が一致
- [ ] 通常OCRは端末内処理である
- [ ] 通常OCR時にWorkers/Geminiへの通信がない
- [ ] OCR失敗/空結果時の作業画像削除を確認
- [ ] 読み取り成功時の画像保存をポリシーへ記載
- [ ] 画像選択でアクセスする範囲をOS別に確認

## 5. AI画像解析

- [ ] AI解析は購入者向け任意機能である
- [ ] 画像選択前に顕著な説明を表示
- [ ] 送信内容として画像、MIME形式、基準日、タイムゾーンを表示
- [ ] 送信先としてCloudflare Workers経由のGoogle Gemini APIを表示
- [ ] キャンセル時に画像選択・HTTP送信が発生しない
- [ ] 同意後だけ送信する
- [ ] 本番URLがHTTPSでlocalhostではない
- [ ] Workerコードに永続保存処理がないことを確認
- [ ] Cloudflareログ/Analytics/Logpushの設定と保持期間を確認
- [ ] Gemini APIの入力・出力保持、ログ、モデル改善利用を確認
- [ ] 写真とOther User Contentのストア回答を一致
- [ ] Appleでリアルタイム処理例外を使う場合、保持条件の証拠がある
- [ ] Google PlayでSharing除外を使う場合、サービスプロバイダー/明示同意条件の証拠がある

## 6. 広告

- [ ] AdMob App IDとBanner Ad Unit IDが本番値
- [ ] テスト広告IDが正式成果物に残っていない
- [ ] Google Mobile Ads SDKの解決済みバージョンを記録
- [ ] mediation SDK一覧を記録（なしの場合も明記）
- [ ] SDK公式データ開示を保存
- [ ] IP/Approximate Locationを回答へ反映
- [ ] App Interactionsを回答へ反映
- [ ] Diagnosticsを回答へ反映
- [ ] Device or Other IDsを回答へ反映
- [ ] Advertising/Analytics/Fraud prevention目的を回答へ反映
- [ ] 広告ID無効化設定の有無を確認
- [ ] UMP/同意フローの実装と本番設定を確認
- [ ] パーソナライズ広告、非パーソナライズ広告、Limited Adsの条件を確認
- [ ] iOS ATT/IDFA/Tracking回答を実機とPrivacy Manifestで確認
- [ ] 広告除去購入後に広告が表示されない
- [ ] 広告ロード失敗時も主要機能が利用できる

## 7. アプリ内課金

- [ ] 商品ID `remove_ads` または本番上書き値が一致
- [ ] 商品ID `ai_analysis` または本番上書き値が一致
- [ ] 2商品が非消費型として登録
- [ ] 価格表示はストア取得値と一致
- [ ] 購入、保留、取消、失敗、復元を実機確認
- [ ] 購入完了処理を確認
- [ ] 広告除去とAI利用権が独立して動作
- [ ] カード番号等をアプリが取得しない説明と一致
- [ ] Purchase HistoryのPlay/Apple回答を確認
- [ ] 端末内購入フラグとストア復元の関係を説明

## 8. 通知

- [ ] Android POST_NOTIFICATIONS権限と説明が一致
- [ ] Android RECEIVE_BOOT_COMPLETEDの用途が一致
- [ ] iOS通知許可文脈を確認
- [ ] 通知拒否時もTodo登録可能
- [ ] 通知本文に表示されるTodo情報のプライバシー注意を確認
- [ ] normal/reboot/install-rまたはアプリ更新後の通知証跡がある
- [ ] リモートPushトークンを使用していない

## 9. 削除・エクスポート・復旧

- [ ] 一括削除対象がポリシー、サポート、実装で一致
- [ ] 個別Todo削除後の孤立文書/画像削除を確認
- [ ] 通知取消・画像削除失敗が再試行される
- [ ] アンインストール後の端末内データを確認
- [ ] 外部サービス送信済みデータは一括削除対象外であることを明記
- [ ] JSONエクスポートに人物、Todo、OCRテキストが含まれる
- [ ] JSONエクスポートに画像本体・ローカル画像パスが含まれない
- [ ] クリップボード注意を記載
- [ ] DB読み込み失敗時に空データで上書きしない
- [ ] 退避情報の扱いをサポート手順に記載

## 10. 権限の最小化

- [ ] Android Manifestの宣言権限を列挙
- [ ] 正確/おおよその位置情報権限がない
- [ ] 連絡先、マイク、SMS、通話履歴、カレンダー権限がない
- [ ] 不要なストレージ権限がない
- [ ] iOS Info.plistの権限説明が機能に限定されている
- [ ] ストアの権限申告とManifest/Info.plistが一致

## 11. Google Play Data safety

- [ ] 「収集または共有: はい」
- [ ] AdMob由来のApproximate Locationを申告
- [ ] AdMob由来のApp Interactionsを申告
- [ ] AdMob由来のDiagnosticsを申告
- [ ] AdMob由来のDevice or Other IDsを申告
- [ ] AI画像解析のPhotosを申告
- [ ] AI画像解析のOther User-Generated Contentを申告
- [ ] Purchase Historyの扱いをPlay Console最新定義で確認
- [ ] 収集/共有、一時的処理、任意/必須、目的を各タイプで回答
- [ ] 「すべて転送中暗号化」は正式通信先を確認後に回答
- [ ] 削除方法と削除URLを公開
- [ ] Families Policy対象の有無を確定
- [ ] Consoleプレビューと公開ポリシーが一致

## 12. Apple App Privacy

- [ ] Photosを確認
- [ ] Other User Contentを確認
- [ ] Purchase Historyを確認
- [ ] Device IDを確認
- [ ] Product Interaction/Advertising Dataを確認
- [ ] Performance/Diagnostic Dataを確認
- [ ] Coarse Locationを確認
- [ ] Linked to User判定の根拠を記録
- [ ] Tracking判定の根拠を記録
- [ ] ATT/IDFA/AdMobの実機証跡がある
- [ ] Privacy Manifestと回答が一致
- [ ] Privacy Policy URLを公開
- [ ] Privacy Choices URLの内容を確認

## 13. サポートページ

- [ ] 通知トラブル手順が現在の実装に一致
- [ ] カメラ/画像/OCRの代替手段を案内
- [ ] 通常OCRとAI解析の違いを説明
- [ ] AI結果の確認責任を案内
- [ ] 広告除去とAI分析が別商品であることを説明
- [ ] 購入復元手順を記載
- [ ] データ削除、エクスポート、DB復旧を記載
- [ ] 問い合わせ時に送らない情報を案内
- [ ] バージョン、OS、端末、再現手順等の必要情報を案内

## 14. 差分監査

- [ ] `git diff <前回承認SHA>..<対象SHA>`でSDK、権限、通信、保存、削除、課金の変更を確認
- [ ] `pubspec.yaml` / `pubspec.lock`のSDK変更を確認
- [ ] Android Manifest/Gradle変更を確認
- [ ] iOS Info.plist/Podfile/Privacy Manifest変更を確認
- [ ] Workers/API変更を確認
- [ ] 新しいURL/ドメインを確認
- [ ] 新しい設定値、Secrets、Variablesを確認
- [ ] 文書変更だけで実装変更を見落としていない

## 15. 承認記録

| 項目 | 記入 |
|---|---|
| 対象commit | |
| Android成果物/ハッシュ | |
| iOS/TestFlight build | |
| Google Play回答確認者・日付 | |
| Apple回答確認者・日付 | |
| プライバシーポリシー公開確認 | |
| サポートページ公開確認 | |
| 未解決FAIL | |
| 未解決BLOCKED | |
| 総合判定 | `APPROVED` / `CORRECTION_REQUIRED` / `BLOCKED` |
| 備考 | |
