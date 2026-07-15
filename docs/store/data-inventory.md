# データインベントリ

基準日: 2026年7月15日  
基準commit: PR #115 最新HEAD

プライバシーポリシー正本: [`../privacy_policy.md`](../privacy_policy.md)

本書は「あしたもつもの」のコード、権限、SDK、端末内保存、外部通信をストア開示へ対応付けるための内部管理資料です。

## 判定記号

- **確認済み**: リポジトリのコードまたは設定で確認できた
- **要実機確認**: コード上の予定動作は確認したが、本番構成・実端末で未確認
- **要管理画面確認**: AdMob、Play Console、App Store Connect、Cloudflare、Google Cloud等の管理画面が必要
- **対象外**: 現在の実装に取得・送信処理がない

## 1. ファーストパーティの端末内データ

| データ要素 | 入力元 | 保存先・形式 | 目的 | 外部送信 | 削除 | 状態・コード証跡 |
|---|---|---|---|---|---|---|
| 人物名・人物ID | 利用者入力 | SQLite/Drift | Todoの対象人物管理 | なし | 一括削除、人物削除 | 確認済み: `lib/src/models/entities.dart`, `lib/src/repositories/drift_store.dart`, `lib/src/app_state.dart` |
| Todo | 利用者入力、OCR/AI候補 | SQLite/Drift | 期限・持ち物・金額・メモ・完了状態等の管理 | 通常はなし | 個別削除、一括削除 | 確認済み |
| チェックリスト | 利用者入力 | SQLite/Drift | Todo内の確認項目 | なし | Todo連動、一括削除 | 確認済み |
| 読み取り文書 | OCR/AI処理 | SQLite/Drift | OCR結果、画像参照、Todoとの関連付け | 通常OCRはなし。AI解析時は画像等を送信 | 孤立時削除、一括削除 | 確認済み: `lib/src/services/ocr_pick_service.dart` |
| OCRテキスト | ML Kit、利用者修正 | SQLite/Drift | Todo候補生成、履歴、エクスポート | 通常OCRはなし | 文書削除、一括削除 | 確認済み: `lib/src/services/ocr_service.dart` |
| 画像ファイル | カメラ、画像選択 | アプリ専用ファイル領域 | OCR/AI解析、読み取り文書の参照 | AI解析を選び同意した場合のみ送信 | 孤立時削除、一括削除、失敗時再試行 | 確認済み: `lib/src/services/image_file_service.dart`, `lib/src/services/ocr_pick_service.dart` |
| 学習済み持ち物候補 | 利用者が確定した候補 | SharedPreferences | 候補抽出の改善 | なし | 一括削除/設定処理 | 確認済み: `lib/src/services/app_settings.dart` |
| 通知時刻設定 | 利用者設定 | SharedPreferences | 前日・当日通知の時刻決定 | なし | 設定変更、アプリ削除 | 確認済み |
| 広告除去フラグ | ストア購入状態 | SharedPreferences | 広告表示の制御 | なし。ストア照会の結果を端末保存 | データ初期化またはアプリ削除。ただし復元可能 | 確認済み: `lib/src/services/purchase_provider.dart` |
| AI利用権フラグ | ストア購入状態 | SharedPreferences | AI画像解析の利用可否 | なし。ストア照会の結果を端末保存 | データ初期化またはアプリ削除。ただし復元可能 | 確認済み |
| 通知ID | アプリ生成 | SQLite/Drift | Todoごとの通知識別、衝突回避 | なし | Todo削除・一括削除後に解放 | 確認済み |
| 通知同期キュー | アプリ生成 | SQLite/Drift | 予約・取消失敗の再試行 | OS通知APIのみ | 成功後削除 | 確認済み |
| 画像削除キュー | アプリ生成 | SQLite/Drift | 画像削除失敗の再試行 | なし | 成功後削除 | 確認済み |
| クラッシュログ | Flutter/Dart例外 | アプリ専用 `crash.log` | ローカル診断 | 自動送信なし | アプリデータ削除/アンインストール | 確認済み: `lib/src/services/crash_reporter.dart` |
| DB破損退避ファイル | 読み込み失敗時 | アプリ専用ファイル領域 | 復旧・上書き防止 | 自動送信なし | 利用者の初期化/OS管理。保持期限は未実装 | 確認済み: `lib/src/bootstrap_app.dart`, `lib/src/repositories/drift_store.dart` |
| JSONエクスポート | 人物、Todo、OCRテキスト | クリップボード | 利用者による持ち出し | 利用者が貼付・共有した場合のみ | クリップボードはOS/他アプリの管理 | 確認済み。画像本体・ローカル画像パスは除外 |

## 2. 外部通信データ

| 機能/送信先 | アプリから送信するデータ | アプリが受信するデータ | 必須/任意 | 目的 | ストア分類候補 | 状態・証跡 |
|---|---|---|---|---|---|---|
| Cloudflare Workers → Google Gemini API | 解析画像、MIME形式、基準日、`Asia/Tokyo`、通信メタデータ | 生成されたTodo候補の解析結果 | 任意。AI商品購入者が毎回同意して実行 | Todo候補生成 | Photos、Other User Content。Diagnostics/Device dataは管理画面・提供元仕様で再確認 | 確認済み: `lib/src/services/gemini_api_service.dart`, `workers/gemini-proxy/src/index.ts` |
| Google Mobile Ads / AdMob | IPアドレス、広告ID/App Set ID等、アプリ・広告操作、診断情報 | 広告コンテンツ、配信結果 | 広告除去前。SDK設定・同意状態に依存 | 広告、測定、分析、不正防止 | Approximate Location、App Interactions、Diagnostics、Device or Other IDs | コード確認済み: `lib/src/services/ad_service.dart`。本番SDK挙動・同意設定は要実機/管理画面確認 |
| Google Play Billing / Apple IAP | 商品照会、購入、復元のリクエスト | 商品ID、価格表示、購入・復元状態 | 購入・復元時 | 非消費型商品の販売・復元 | アプリによるPurchase History収集は対象外。購入状態は端末内のみ | 確認済み: `lib/src/services/purchase_provider.dart`。購入トークン等を開発者サーバーへ送信する実装なし |
| プライバシー/サポートWeb | IP、User-Agent等の通常のWeb通信情報 | Webページ | 利用者がリンクを開く場合 | 情報提供・問い合わせ | Web閲覧は開いた外部ブラウザの扱いも確認 | URLコード確認済み。アクセスログ/フォーム項目は要管理画面確認 |

Google Gemini APIの解析結果はAPI側で生成され、本アプリが受信する情報です。解析結果を、AI解析の入力として本アプリからAPIへ送信するものではありません。

Google PlayまたはAppleがストア運営者として決済・購入管理のために処理する取引情報は、アプリまたは統合SDKが端末外へ送信するデータとは分けて評価します。将来、購入トークン、レシート、取引IDまたは購入履歴を開発者サーバーへ送信する場合は、Purchase Historyの分類を再評価します。

## 3. 権限・OS機能

| Android権限/機能 | 実装目的 | 個人データへの影響 | 状態 |
|---|---|---|---|
| `CAMERA` | お知らせ等の撮影 | 写真をアプリ専用領域へコピーしOCR/AI解析 | Manifest確認済み |
| `POST_NOTIFICATIONS` | ローカル通知 | Todoタイトル等が通知面に表示され得る | Manifest確認済み、実機表示は要確認 |
| `INTERNET` | 広告、課金、AI解析、Web | SDK/外部サービスへ通信 | Manifest確認済み |
| `RECEIVE_BOOT_COMPLETED` | 再起動後の通知再予約 | Todo通知スケジュールを端末内で再設定 | Manifest確認済み |
| 写真選択 | OSのImage Picker | 利用者が選択した画像へアクセス | 実装確認済み。OS別権限表示は要実機確認 |

### 要求していない権限

現在のAndroid Manifestでは、正確/おおよその位置情報、連絡先、マイク、SMS、通話履歴、カレンダー、外部ストレージ全体への権限を宣言していません。

## 4. SDK・外部サービス一覧

| SDK/サービス | 用途 | バージョン/設定元 | 開示上の注意 |
|---|---|---|---|
| `google_mobile_ads` | AdMobバナー広告 | `pubspec.yaml` | SDKの自動収集・共有を含める。本番広告ID・同意フロー確認必須 |
| `in_app_purchase` | 広告除去・AI利用権 | `pubspec.yaml` | 購入状態は端末内。外部サーバー検証を追加した場合はPurchase Historyを再評価 |
| `google_mlkit_text_recognition` | iOS通常OCR | `pubspec.yaml` | 通常OCRは端末内処理。モデル配布方式とネットワーク挙動を実機確認 |
| Android native ML Kit OCR | Android通常OCR | MethodChannel/Android依存 | 通常OCR画像を独自サーバーへ送信しない |
| `image_picker` | カメラ・画像選択 | `pubspec.yaml` | 利用者が選んだ写真のみ |
| `flutter_local_notifications` | ローカル通知 | `pubspec.yaml` | リモートPushトークンなし。通知本文への個人情報表示に注意 |
| `shared_preferences` | 設定・購入済みフラグ | `pubspec.yaml` | 端末内。暗号化ストレージではない |
| Drift/SQLite | 主要データ永続化 | `lib/src/repositories/drift_store.dart` | 端末内。破損退避、削除、再試行キューを含む |
| Cloudflare Workers | Gemini中継 | `workers/gemini-proxy` | IP/セキュリティログ等は提供元設定を確認 |
| Google Gemini API | AI画像解析 | Workerの `gemini-2.5-flash` | 入力・出力の保持/学習設定を本番契約で確認 |
| `url_launcher` | 外部ページ表示 | `pubspec.yaml` | 外部ブラウザへ遷移 |

## 5. ストア開示へ反映する確認済み事項

- アプリがAdMobおよび任意AI画像解析で外部へデータを送信するため、Google Play Data safetyの「収集なし」回答は不適切。
- 通常OCRのみの画像処理は端末内であり、通常OCR画像を外部送信するデータとして扱わない。
- AI画像解析の写真は任意収集で、アプリ機能目的。毎回の明示説明・同意後に送信する。
- AdMob SDKのデータ処理を、開発者自身が直接利用しない場合も含めて申告する。
- 端末内の購入済みフラグはGoogle Play/Appleの収集対象外。ストア事業者自身の取引処理と、アプリによる端末外送信を区別する。
- 端末内クラッシュログは自動送信されないため、現実装だけを根拠にストアのCrash Logs収集へ含めない。ただしAdMobのDiagnosticsは別途含める。
- 位置情報権限はないが、AdMobがIPアドレスからおおよその地域を推定し得るため、Approximate Locationを申告候補に含める。

## 6. 未確認・公開前ブロッカー

- [ ] 本番AdMobで使用されるGoogle Mobile Ads SDKの実バージョンとSDK Data Safety情報
- [ ] UMP/同意フロー、年齢設定、パーソナライズ広告、Limited Adsの本番挙動
- [ ] Android Manifestで広告ID収集を無効化する設定の有無と方針
- [ ] iOS側のPrivacy Manifest、ATT表示、IDFA取得、広告構成
- [ ] Cloudflare Workersのログ設定、Logpush、Analytics、保持期間
- [ ] Google Gemini APIの本番契約、入力/出力ログ、保持、モデル改善利用の設定
- [ ] Google Play Billing/App Storeの実商品ID、価格、商品状態
- [ ] 購入トークン、レシート、取引IDが開発者サーバーへ送信されないことの正式成果物確認
- [ ] サポートフォームの収集項目、メール配信、保持期間、削除手順
- [ ] Android/iOSのOSバックアップに含まれる端末内データ範囲
- [ ] 破損DB退避ファイルの自動削除・保持期限
- [ ] App Store向けiOSプロジェクト、権限説明文、Privacy Manifestの正式生成物

## 7. 更新ルール

次の変更を行うPRでは、本書、プライバシーポリシー正本、Google Play Data safety、Apple App Privacy、サポートページを同時に再確認します。

- SDK追加・更新
- 権限追加・削除
- 外部API追加・送信項目変更
- 広告・分析・クラッシュ送信設定変更
- 課金商品追加・購入検証方式変更
- ログイン、同期、家族共有、バックアップ機能の追加
- 保存項目・保持期間・削除方法の変更
- 子ども向け対象年齢またはストアカテゴリ変更
