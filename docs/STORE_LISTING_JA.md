# Google Play ストア掲載文（日本語）

Play Console へ登録する説明文・分類・審査メモの下書きです。実際の提出前に、スクリーンショット、価格、サポート連絡先、プライバシーポリシー公開URLを最終確認してください。

## アプリ名

あしたもつもの

## 短い説明（80文字以内）

園・学校の連絡文やプリントから、持ち物・提出物・集金をTodo化。

## 詳細説明

「あしたもつもの」は、園・学校・習い事のプリント、スクリーンショット、連絡文から、持ち物・提出物・集金をTodoとして整理するためのアプリです。

カメラ撮影、画像選択、テキスト貼り付けから日本語の連絡内容を読み取り、日付、金額、持ち物、提出物を候補として作成します。通常の文字認識は端末上で処理し、OCR結果は登録前に必ず確認・修正できます。購入者向けのAI画像解析を選択した場合は、手書きを含む画像からTodo候補を作成できます。

主な機能:

- 子ども別にTodoを整理
- カメラ撮影・画像選択・テキスト貼り付けからTodo候補を作成
- 持ち物、提出物、集金、予定を自動分類
- 1つの連絡文から複数のTodo候補を作成
- 「今月末」「始業式の日」など曖昧な期限は要確認として登録
- 前日夜と当日朝のリマインド通知
- 通知時刻の変更と既存Todoの再予約
- 手直しした持ち物を次回以降の候補に反映
- 購入者向けAI画像解析で手書きメモにも対応
- ログイン不要、端末内保存

こんな人におすすめ:

- 園や学校からの連絡を見落としたくない
- 明日の持ち物や提出物を家族で確認しやすくしたい
- 集金袋、申込書、体操着、水筒などをTodoとしてまとめたい
- 連絡アプリや紙プリントの内容を手入力する手間を減らしたい

登録した人物名、Todo、OCR全文、保存画像は原則として端末内に保存されます。通常の日本語OCRでは画像を外部サービスへ送信しません。ユーザーがAI画像解析を選択した場合のみ、解析画像、画像形式、解析基準日、タイムゾーンを開発者管理のCloudflare Workers経由でGoogle Gemini APIへ送信します。広告表示とアプリ内課金には、Google Mobile Ads と Google Play Billing を使用します。

## キーワード候補

持ち物, 提出物, 集金, プリント, 学校, 幼稚園, 保育園, 習い事, Todo, リマインダー, OCR, 連絡帳

## カテゴリ候補

- メインカテゴリ: ツール
- 代替候補: ライフスタイル、教育

## 審査メモ

- 通常の日本語OCRは端末上の ML Kit Text Recognition を使用します。
- AI画像解析は購入者が専用ボタンを選択した場合のみ実行します。
- AI画像解析では、解析画像、画像形式、解析基準日、タイムゾーンをCloudflare Workers経由でGoogle Gemini APIへ送信します。
- カメラ権限は、プリントや連絡文の撮影に使用します。
- 通知権限は、登録したTodoのリマインド通知に使用します。
- インターネット通信は、広告表示、アプリ内課金、外部ページ表示、AI画像解析に使用します。
- 人物名、Todo、OCR全文、保存画像は原則端末内に保存し、独自の同期・家族共有機能は提供しません。
- 広告表示には Google Mobile Ads、広告削除とAI画像解析の買い切り課金には Google Play Billing を使用します。

## データセーフティ回答メモ

このメモは Play Console 入力時の確認用です。Google Play の質問文は変更されることがあるため、提出画面の最新項目と各SDK提供元の最新データ開示資料に合わせて読み替えてください。

- 端末内に保存するデータ: 人物名、Todo、OCR全文、撮影・選択画像、学習済み持ち物候補、アプリ設定
- 外部送信するデータ: ユーザーがAI画像解析を選択した場合の解析画像、画像形式、解析基準日、タイムゾーン
- AI解析の送信経路: 開発者管理のCloudflare WorkersからGoogle Gemini APIへ中継
- 通常OCR: 端末上で処理し、画像をCloudflare WorkersまたはGoogle Gemini APIへ送信しない
- 転送時の保護: リリース前に本番`GEMINI_PROXY_URL`がHTTPSであることを確認する
- データ削除方法: アプリ内の「設定」から「登録データをすべて削除」を実行すると、人物、Todo、読み取り履歴、保存画像、学習済み持ち物候補を端末内から削除可能。個別Todo削除でも未使用の読み取り履歴と保存画像を削除する
- 外部サービスへ送信済みのAI解析データ: CloudflareおよびGoogleの保持・削除方針が適用される
- 第三者サービス: Google Mobile Ads、Google Play Billing、Cloudflare Workers、Google Gemini API
- 広告関連データ: 広告配信のため、Google Mobile Adsが広告ID、端末情報、広告の表示・操作に関する情報などを処理する場合がある
- 購入関連データ: アプリ内課金と購入復元のため、Google Play Billingが商品情報および購入情報を処理する

## スクリーンショット案

ストアアイコン候補: `assets/store/icon-512.png`

生成スクリプト: `tool/generate_store_screenshots.py`

1. `assets/store/screenshots/01-home.png`: 今日・明日・期限未設定のTodoが並ぶ状態
2. `assets/store/screenshots/02-add-todo.png`: OCR/貼り付け追加画面と連絡文から候補を作る導線
3. `assets/store/screenshots/03-review-candidates.png`: 持ち物・集金・提出が複数候補に分かれた状態
4. `assets/store/screenshots/04-todo-detail.png`: チェック項目、期限、メモを確認するTodo詳細
5. `assets/store/screenshots/05-settings-supporter.png`: 通知時刻と買い切りサポーター

## リリース前チェック

- [ ] `flutter analyze` が通る
- [ ] `flutter test` が通る
- [ ] 実機でカメラ撮影、画像選択、日本語OCR、通知許可、通知予約を確認する
- [ ] AI画像解析の実行前に外部送信をユーザーへ明示する導線を確認する
- [ ] 本番`GEMINI_PROXY_URL`がHTTPSのCloudflare Workers URLであることを確認する
- [ ] Play Console にプライバシーポリシーURLを登録する
- [ ] Play Consoleのデータセーフティ回答を最新のGoogle Mobile Ads、Google Play Billing、Cloudflare、Gemini APIの開示内容と照合する
- [ ] AdMob 本番 App ID / 広告ユニット ID を GitHub Secrets に登録する
- [ ] Google Play Billing の買い切り商品IDと `IAP_REMOVE_ADS_PRODUCT_ID`（未設定時は `remove_ads`）を一致させる
- [ ] AI画像解析の商品IDと `IAP_AI_ACCESS_PRODUCT_ID`（未設定時は `ai_analysis`）を一致させる
- [ ] 設定画面の買い切り価格が Play Console の商品価格で表示されることを内部テストで確認する
- [ ] 署名済みAABを `Release Android` ワークフローで生成する
