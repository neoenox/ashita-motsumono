# Google Play Data safety 回答案

基準日: 2026年7月14日  
対象Application ID: `com.ashita_motsumono`  
対象基準commit: `cc420074efb9f61d5d314885481f10f9c694c3ea`

> **重要**
> 本書はPlay Consoleへ転記するための保守的な回答案です。最終回答では、正式AAB、依存SDKの解決済みバージョン、AdMob/UMP設定、Play Billingの商品、Cloudflare Workers/Geminiの本番設定を実機・管理画面で確認してください。開発者が回答の正確性に責任を持ちます。

## 1. 最初の質問

### アプリは必要なユーザーデータを収集または共有しますか

**回答案: はい**

理由:

- AdMob SDKがIPアドレス、端末・アカウント識別子、アプリ/広告操作、診断情報を外部送信する。
- 任意のAI画像解析で、利用者が同意した場合に写真、MIME形式、基準日、タイムゾーンをCloudflare Workers経由でGoogle Gemini APIへ送信する。
- アプリ内課金・購入復元でストア課金基盤と購入情報を処理する。

端末内だけで処理・保存する人物、Todo、通常OCR画像、通常OCRテキスト、ローカル障害ログは、この質問の「収集」の根拠にはしません。

## 2. セキュリティに関する質問

| 質問 | 回答案 | 根拠・条件 |
|---|---|---|
| 収集するすべてのデータは転送中に暗号化されますか | **はい（条件付き）** | Gemini URLは本番でHTTPS必須。AdMobはTLS。Play BillingはストアSDK。正式AABの通信先とWorkers URLがすべてHTTPSであることを確認してから確定 |
| データ削除をリクエストする方法を提供しますか | **はい（説明要）** | 端末内データはアプリ内一括削除が可能。外部サービスに送信済みのログ・取引情報は直接削除できない。問い合わせURLを公開し、外部処理分の相談範囲を明記する |
| 独立したセキュリティ審査 | **いいえ** | MASA等の完了証跡なし |
| Families Policy準拠バッジ | **現時点では選択しない** | 対象年齢・子ども向け指定が未決定。子ども向け公開する場合は別途全面確認 |

## 3. データタイプ別回答案

### 3.1 おおよその位置情報

| 項目 | 回答案 |
|---|---|
| データタイプ | Location → Approximate location |
| 収集/共有 | **収集・共有** |
| 一時的処理 | **いいえ**（広告目的のプロファイル等に使われ得るため保守的に回答） |
| 必須/任意 | **広告が表示される利用者について必須**。広告除去購入後は広告表示なし |
| 目的 | Advertising or marketing、Analytics、Fraud prevention, security, and compliance |
| 根拠 | Google Mobile Ads SDKがIPアドレスを収集し、おおよその地域推定に使い得る。アプリは位置情報権限を要求しない |

### 3.2 写真

| 項目 | 回答案 |
|---|---|
| データタイプ | Photos and videos → Photos |
| 収集/共有 | **収集**。Sharingは**いいえ候補**だが最終確認必須 |
| 一時的処理 | **はい候補**。WorkersとGeminiがリクエスト処理後に保持しない契約・設定を確認できた場合のみ |
| 必須/任意 | **任意**。AI分析購入者が毎回説明を読み、同意した場合のみ |
| 目的 | App functionality |
| 根拠 | AI画像解析で画像をWorkers経由でGeminiへ送信。通常OCR画像は端末内のみ |

Sharingを「いいえ」とする候補理由は、Cloudflare/Googleが開発者の指示で処理するサービスプロバイダーに該当する、または明確な利用者操作・顕著な説明・同意に基づく移転としてGoogle PlayのSharing除外条件に該当し得るためです。ただし、契約、Gemini APIのデータ利用、Cloudflareログ設定を確認できない限り確定しません。該当性を確認できない場合は**収集・共有**として申告します。

### 3.3 その他のユーザー生成コンテンツ

| 項目 | 回答案 |
|---|---|
| データタイプ | App activity → Other user-generated content |
| 収集/共有 | **収集**。Sharingは写真と同じ基準で判断 |
| 一時的処理 | **はい候補** |
| 必須/任意 | **任意** |
| 目的 | App functionality |
| 根拠 | AI解析画像にメモ、学校・園のお知らせ、氏名、期限、金額等の自由記述が含まれ得る。MIME形式、基準日、タイムゾーンも送信 |

Play Console上で「Files and docs」を併記するかは、AI解析対象が主に紙文書の写真であることと、実際に送信するデータが画像であることを踏まえ、Consoleの最新定義で確認します。重複申告が必要と判断した場合は追加します。

### 3.4 アプリの操作

| 項目 | 回答案 |
|---|---|
| データタイプ | App activity → App interactions |
| 収集/共有 | **収集・共有** |
| 一時的処理 | **いいえ** |
| 必須/任意 | **広告表示利用者について必須** |
| 目的 | Advertising or marketing、Analytics、Fraud prevention, security, and compliance |
| 根拠 | Google Mobile Ads SDKがアプリ起動、タップ、広告/動画表示等の操作情報を自動処理し得る |

### 3.5 診断情報

| 項目 | 回答案 |
|---|---|
| データタイプ | App info and performance → Diagnostics |
| 収集/共有 | **収集・共有** |
| 一時的処理 | **いいえ** |
| 必須/任意 | **広告表示利用者について必須** |
| 目的 | Analytics、Fraud prevention, security, and compliance、Advertising or marketing |
| 根拠 | Google Mobile Ads SDKが起動時間、ハング率、エネルギー使用量等を処理し得る |

アプリ独自の `crash.log` は端末内だけに保存し、自動送信しないため、Crash logsの収集根拠にはしません。将来クラッシュ送信SDKを追加した場合は再申告します。

### 3.6 端末またはその他のID

| 項目 | 回答案 |
|---|---|
| データタイプ | Device or other IDs → Device or other IDs |
| 収集/共有 | **収集・共有** |
| 一時的処理 | **いいえ** |
| 必須/任意 | **広告表示利用者について必須**。広告IDはOS設定やLimited Ads等により利用されない場合あり |
| 目的 | Advertising or marketing、Analytics、Fraud prevention, security, and compliance |
| 根拠 | Google Mobile Ads SDKが広告ID、App Set ID、場合により端末アカウント関連識別子を処理し得る |

正式AABのmerged manifestを確認し、広告ID収集を無効化する宣言を採用する場合は回答を更新します。

### 3.7 購入履歴

| 項目 | 回答案 |
|---|---|
| データタイプ | Financial info → Purchase history |
| 収集/共有 | **収集候補**。Google Play自身がストア運営者として処理する範囲との境界をConsoleで確認 |
| 一時的処理 | **いいえ候補** |
| 必須/任意 | **任意**。購入・復元を選択した場合のみ |
| 目的 | App functionality、Fraud prevention, security, and compliance |
| 根拠 | アプリは商品情報、商品ID、購入/復元状態を受け取り、広告除去/AI利用権を有効化する |

アプリはカード番号、銀行口座等の決済手段情報を取得しません。「User payment info」は**選択しない**案です。

## 4. 選択しないデータタイプ案

現在のアプリ実装だけを根拠とする限り、次は選択しません。

- Precise location
- Name（人物名は端末内保存のみ。AI画像に氏名が写る可能性はOther user-generated content/Photosで包括し、特定入力項目として外部送信を要求しない）
- Email address、User IDs、Address、Phone number
- Race and ethnicity、Political or religious beliefs、Sexual orientation
- Health info、Fitness info
- Emails、SMS or MMS、Other in-app messages
- Videos、Audio files
- Calendar events、Contacts
- In-app search history、Installed apps、Web browsing history
- Crash logs（アプリ独自ログは端末内のみ）

ただし、AI画像に上記情報が偶発的に含まれる可能性があります。Play Consoleの自由記述・ユーザー生成コンテンツの扱いと、対象年齢方針を踏まえて再確認します。

## 5. 「共有」の最終判定表

| 処理 | 回答案 | 最終確認 |
|---|---|---|
| AdMob SDK | 共有: **はい** | Google公式SDK開示、本番SDKバージョン、媒介広告SDKの有無 |
| AI画像 → Cloudflare Workers | 共有: **いいえ候補** | Workersがサービスプロバイダーか、ログ/二次利用、契約 |
| Workers → Gemini API | 共有: **いいえ候補** | Gemini APIの契約、データ保持・モデル改善、利用者同意の適合性 |
| Play Billing | 共有: **いいえ候補** | Play Consoleのストア処理除外、アプリが外部事業者へ追加送信しないこと |
| 外部ブラウザで開く公開ページ | アプリによる共有: **通常は対象外候補** | アプリ制御WebViewではなく外部ブラウザであること、問い合わせフォームの導線 |

## 6. 削除説明案

ストア掲載用の説明:

> アプリ内の設定から、人物、Todo、読み取り履歴、保存画像、学習済み候補等の端末内登録データを削除できます。アプリはログインアカウントや独自同期サーバーを使用していません。AI画像解析、広告、課金等で外部サービスへ送信・処理された情報には各提供元の保持・削除方針が適用されます。外部処理に関する相談はサポートページから受け付けます。

削除URL欄が必要な場合の候補:

`https://lp-5t7.pages.dev/apps/ashita-motsumono/contact`

公開前に、削除相談を実際に受け付けられるフォームまたは連絡先があることを確認します。

## 7. Play Console転記前チェック

- [ ] 正式AABのcommitが本書の対象commit以降である
- [ ] `flutter pub deps` またはlockfileでSDK実バージョンを確認
- [ ] merged manifestで権限、AdMob App ID、広告ID設定を確認
- [ ] 本番AdMobバナーを実機表示し、同意状態別の通信を確認
- [ ] mediation SDKが追加されていないことを確認。追加されている場合は全SDKを調査
- [ ] AI解析同意画面で、画像、MIME形式、基準日、タイムゾーン、送信先が表示される
- [ ] 同意キャンセル時に画像選択もHTTP送信も行われない
- [ ] Workers/Geminiの保持・ログ・二次利用条件を確認
- [ ] Play Billingの商品ID `remove_ads` と `ai_analysis`（または本番上書き値）を確認
- [ ] 端末内一括削除、孤立画像削除、アンインストール後の状態を確認
- [ ] プライバシーポリシー公開URLと本文が本回答に一致
- [ ] サポート/削除相談URLが公開済み
- [ ] Play Consoleプレビューを保存し、`store-disclosure-consistency-checklist.md`で承認

## 8. 未確認情報

次はコードだけでは確定できないため、現時点で断定しません。

- AdMobの本番同意モード、パーソナライズ広告、年齢設定、Limited Ads
- CloudflareおよびGemini APIの本番ログ保持・データ利用条件
- Google PlayがPlay Billing処理をData safety上どこまで開発者アプリの収集として求めるか
- Play Consoleの最新画面における各回答ラベルと選択肢
- 本番AABに追加される間接SDKまたはManifest権限
