# Apple App Privacy 回答案

基準日: 2026年7月14日  
対象基準commit: `cc420074efb9f61d5d314885481f10f9c694c3ea`

> **提出状態: 下書き / iOS正式成果物未確認**
>
> App Store Connectへの最終転記前に、正式なiOSプロジェクト、Privacy Manifest、Info.plistの権限説明、ATT表示、Google Mobile Ads SDKのiOS版構成、Apple In-App Purchaseの商品を確認してください。現在のリポジトリではiOS正式生成物の一部を直接確認できないため、追跡（Tracking）とIDFAの最終回答は未確定です。

## 1. Data Collectionの全体回答

**「Yes, we collect data from this app」回答案**

理由:

- AdMobを有効にしたiOS版では、広告SDKが識別子、広告/アプリ操作、診断情報、IPアドレス等を処理する可能性がある。
- 任意のAI画像解析で、利用者の同意後に写真、MIME形式、基準日、タイムゾーンをCloudflare Workers経由でGoogle Gemini APIへ送信する。
- アプリ内課金で購入情報を処理する。

端末上だけに保存する人物、Todo、通常OCR画像、通常OCR結果、端末内クラッシュログは、Appleの「Collected」の対象外として扱う案です。

## 2. データタイプ別回答案

### 2.1 Photos or Videos → Photos

| 項目 | 回答案 |
|---|---|
| Collected | **Yes** |
| Purpose | App Functionality |
| Linked to User | **No候補** |
| Used for Tracking | **No** |
| 条件 | AI画像解析を購入済みの利用者が、毎回の説明に同意して実行した場合のみ |
| 根拠 | 画像をWorkers経由でGeminiへ送信してTodo候補を生成 |

Appleの定義では、送信データがリアルタイムのリクエスト処理に必要な時間を超えて読み取り可能な形で保存されない場合、Collectedに含めない可能性があります。しかし、Cloudflare/Geminiの実際の保持条件を未確認であるため、本案では保守的に**Collected: Yes**とします。

### 2.2 User Content → Other User Content

| 項目 | 回答案 |
|---|---|
| Collected | **Yes** |
| Purpose | App Functionality |
| Linked to User | **No候補** |
| Used for Tracking | **No** |
| 根拠 | AI解析対象画像には自由記述の学校・園のお知らせ、メモ、氏名、期限、金額等が含まれ得る。基準日・タイムゾーンも解析文脈として送信 |

利用者に特定の氏名、健康情報等の入力を要求する外部送信フォームではありません。自由記述画像の内容をすべて個別カテゴリへ展開するのではなく、PhotosとOther User Contentを中心に申告する案です。App Store Connectの最新ガイダンスと審査方針で確認します。

### 2.3 Purchases → Purchase History

| 項目 | 回答案 |
|---|---|
| Collected | **Yes候補** |
| Purpose | App Functionality |
| Linked to User | **Yes候補**（Apple ID/ストア取引に関連し得る） |
| Used for Tracking | **No** |
| 根拠 | 広告除去とAI分析の非消費型商品について、商品情報、購入、復元、購入状態を処理 |

Apple自身がApp Store取引として収集する情報と、アプリ/第三者パートナーが収集する情報の境界をApp Store Connectで確認します。アプリはカード番号等のPayment Infoを直接取得しないため、Payment Infoは**No**案です。

### 2.4 Identifiers → Device ID

| 項目 | 回答案 |
|---|---|
| Collected | **Yes候補**（AdMob本番有効時） |
| Purpose | Third-Party Advertising、Analytics、App Functionality（不正防止を含む場合） |
| Linked to User | **Yes候補** |
| Used for Tracking | **未確定** |
| 根拠 | Google Mobile Ads SDKが広告識別子等を扱う可能性 |

最終回答には次の確認が必要です。

- iOS版Google Mobile Ads SDKのPrivacy Manifest
- `NSUserTrackingUsageDescription`の有無
- ATTプロンプトの実装と表示条件
- IDFA取得の有無
- パーソナライズ広告/広告測定の設定
- mediation SDKの有無

ATTを表示しない、IDFAを取得しない、追跡を行わない構成を実証できた場合はUsed for TrackingをNoとします。第三者SDKが他社データと結合してターゲティングまたは広告測定に利用する場合はYesです。

### 2.5 Usage Data → Product Interaction

| 項目 | 回答案 |
|---|---|
| Collected | **Yes候補**（AdMob本番有効時） |
| Purpose | Third-Party Advertising、Analytics |
| Linked to User | **YesまたはNo: SDK構成確認** |
| Used for Tracking | **未確定** |
| 根拠 | 広告SDKがアプリ起動、広告表示、タップ等の操作を処理し得る |

### 2.6 Usage Data → Advertising Data

| 項目 | 回答案 |
|---|---|
| Collected | **Yes候補** |
| Purpose | Third-Party Advertising、Analytics |
| Linked to User | **SDK構成確認** |
| Used for Tracking | **未確定** |
| 根拠 | 広告の表示・操作・測定に関するデータ |

### 2.7 Diagnostics → Performance Data / Other Diagnostic Data

| 項目 | 回答案 |
|---|---|
| Collected | **Yes候補**（AdMob SDK分） |
| Purpose | Analytics、App Functionality |
| Linked to User | **No候補** |
| Used for Tracking | **No候補** |
| 根拠 | 広告SDKの起動時間、ハング、SDK性能等の診断情報 |

アプリ独自の `crash.log` は端末内にのみ保存し、自動送信しません。この実装だけを理由にCrash DataをYesにはしません。iOS SDKまたはOSレポートを開発者がApp Store Connect等で取得する場合、その情報がApple自身の収集か、アプリ/第三者パートナーの収集かを区別します。

### 2.8 Location → Coarse Location

| 項目 | 回答案 |
|---|---|
| Collected | **Yes候補** |
| Purpose | Third-Party Advertising、Analytics |
| Linked to User | **SDK構成確認** |
| Used for Tracking | **未確定** |
| 根拠 | AdMobがIPアドレスからおおよその地域を推定し得る |

本アプリは位置情報権限を要求せず、GPS等のPrecise Locationを取得しません。Precise Locationは**No**案です。

## 3. 「Data Not Collected」扱いの端末内処理

次は現実装では端末外へ送信しないため、App PrivacyではCollectedに含めない案です。

- 人物名・人物ID
- Todoのタイトル、期限、カテゴリ、持ち物、金額、メモ、完了状態、通知設定
- 通常OCRに使う写真
- 通常OCR結果
- 読み取り文書とローカル画像パス
- 学習済み持ち物候補
- 通知時刻、通知ID、再試行キュー
- 広告除去/AI利用権の端末内フラグそのもの
- 端末内 `crash.log`
- DB破損時の退避ファイル

ただし、利用者がAI画像解析を選択した写真と、その画像内に含まれる内容は別途Collectedとして扱います。

## 4. 現時点でNoとするデータタイプ案

アプリ自身または統合SDKが取得している証跡がない限り、次はNoとします。

- Contact Info: Email Address、Phone Number、Physical Address、Other User Contact Info
- Health & Fitness
- Financial Info: Payment Info、Credit Info、Other Financial Info
- Sensitive Info
- Contacts
- Browsing History
- Search History
- Location: Precise Location
- User Content: Emails or Text Messages、Audio Data、Gameplay Content、Customer Support（問い合わせフォームの実装確認前）

「Name」は、端末内人物プロフィールとしてはCollectedではありません。AI画像に氏名が写り込む可能性についてはPhotos/Other User Contentで扱う案です。

## 5. Tracking判定

### 確認済み

- アプリ独自コードに、利用者データをデータブローカーへ販売・提供する処理はない。
- アプリ独自コードに、複数アプリ/サイト横断の識別子を独自生成・結合する処理はない。

### 未確認

- iOS版AdMobのIDFA利用
- ATT実装
- パーソナライズ広告および広告測定
- Googleまたは広告パートナーが、アプリ由来データをThird-Party Dataと結合するか
- mediation SDK

したがって、**Tracking: Noを現時点で確定しません**。正式iOSビルドと広告設定を確認してから、App Store Connectの「Data Used to Track You」を決定します。

## 6. Privacy Policy / Privacy Choices URL

Privacy Policy:

`https://lp-5t7.pages.dev/apps/ashita-motsumono/privacy`

Privacy Choices候補:

`https://lp-5t7.pages.dev/apps/ashita-motsumono/contact`

Privacy Choices URLには、少なくとも次を掲載します。

- 端末内データの一括削除手順
- 通知、カメラ、写真、広告のOS設定
- AI解析を利用しない選択
- 広告除去購入と復元
- 外部サービス送信済み情報に関する相談方法

## 7. App Store Connect転記前チェック

- [ ] 正式iOSプロジェクトを生成/確認し、Bundle IDを確定
- [ ] Info.plistのカメラ・写真・通知関連説明文を確認
- [ ] Privacy Manifestを収集し、Required Reason APIsとSDK宣言を確認
- [ ] Google Mobile Ads SDK、ML Kit、IAP等の解決済みバージョンを確認
- [ ] ATTプロンプトの有無と表示条件を実機確認
- [ ] IDFA取得をネットワークログ/SDK設定で確認
- [ ] AdMob同意状態別に広告表示・通信を確認
- [ ] mediation SDKの有無を確認
- [ ] AI解析の同意、キャンセル、送信内容、HTTPS通信を確認
- [ ] Workers/Geminiの保持期間、ログ、モデル改善利用を確認
- [ ] Apple IAPの商品ID、価格、購入、復元をTestFlight実機で確認
- [ ] Privacy PolicyとPrivacy Choices URLを公開
- [ ] App Store Connectの最終回答スクリーンショットまたはエクスポートを保存
- [ ] `store-disclosure-consistency-checklist.md`を全項目確認

## 8. 未確認情報

- iOS版の正式な権限宣言とPrivacy Manifest
- App Tracking TransparencyとIDFA
- iOS版AdMobの実データ処理
- Apple IAPがApp Privacy質問上どの範囲でアプリのCollected dataとなるか
- Cloudflare/Geminiの保持がAppleのリアルタイム処理例外を満たすか
- App Store Connectの提出時点の最新質問・カテゴリ
