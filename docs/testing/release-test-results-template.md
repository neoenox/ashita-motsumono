# Release 実機テスト結果

> 本ファイルをテスト実施ごとに複製し、`docs/validation/release-device/<YYYY-MM-DD>-<platform>-<version>.md`等へ保存します。秘密値、購入トークン、APIキー、個人情報を記録しません。

## 1. 基本情報

| 項目 | 記入内容 |
|---|---|
| テスト結果ID | |
| テスト計画 | [release-device-test-plan.md](./release-device-test-plan.md) |
| 実施日 | |
| 開始時刻 / 終了時刻 | |
| タイムゾーン | `Asia/Tokyo` / その他: |
| 実施者 | |
| レビュー者 | |
| 総合判定 | `PASS` / `CONDITIONAL_PASS` / `FAIL` / `BLOCKED` / `NOT_ASSESSED` |
| 判定理由 | |

## 2. 対象ビルド

| 項目 | 記入内容 |
|---|---|
| Repository | `kaenozu/ashita-motsumono` |
| Branch / Tag | |
| Commit SHA | |
| Base master SHA | |
| Application ID / Bundle ID | `com.ashita_motsumono` / |
| Android versionName/versionCode | |
| iOS version/build | |
| 配布経路 | Play内部テスト / APK / TestFlight / その他 |
| Play/TestFlight build識別情報 | |
| Release workflow run | |
| `release-manifest.json` SHA-256 | |
| APK/AAB/IPA SHA-256 | |
| 署名証明書照合 | PASS / FAIL / BLOCKED |
| AdMob構成 | 本番 / テスト / 未設定 / 不明 |
| Gemini Proxy host | |
| 広告除去商品ID | |
| AI分析商品ID | |

## 3. 端末・環境

| Device ID | Platform | メーカー/機種 | OS | 画面/文字サイズ | Store account種別 | Network | Battery/省電力 | 備考 |
|---|---|---|---|---|---|---|---|---|
| D1 | Android/iOS | | | | 未購入/購入済み等 | Wi-Fi/Cellular | | |
| D2 | | | | | | | | |
| D3 | | | | | | | | |

端末のシリアル番号、Apple ID、Googleアカウント、注文番号は公開文書へ記録しません。

## 4. 前提条件

| 条件 | 状態 | 証跡/備考 |
|---|---|---|
| 対象commitが承認済みmaster | PASS/FAIL/BLOCKED | |
| CI Analyze/Test成功 | | |
| 正式署名済み成果物 | | |
| Play内部テスト/TestFlight配布 | | |
| AdMob本番設定 | | |
| Gemini Proxy HTTPS設定 | | |
| 2つの課金商品が利用可能 | | |
| Privacy/Support URL公開 | | |
| 個人情報を含まないテスト画像 | | |

## 5. サマリー

| 結果 | 件数 |
|---|---:|
| PASS | 0 |
| FAIL | 0 |
| BLOCKED | 0 |
| INCONCLUSIVE | 0 |
| N/A | 0 |
| 未実施 | 0 |

| Severity | Open | Fixed/Re-tested | Accepted |
|---|---:|---:|---:|
| S0 Critical | 0 | 0 | 0 |
| S1 High | 0 | 0 | 0 |
| S2 Medium | 0 | 0 | 0 |
| S3 Low | 0 | 0 | 0 |

## 6. ケース結果

| Case ID | Device | 結果 | 実施日時 | 期待結果との差分 | Evidence | Defect ID | 備考 |
|---|---|---|---|---|---|---|---|
| DEV-001 | | | | | | | |
| DEV-002 | | | | | | | |
| DEV-003 | | | | | | | |
| DEV-010 | | | | | | | |
| DEV-011 | | | | | | | |
| DEV-012 | | | | | | | |
| DEV-020 | | | | | | | |
| DEV-021 | | | | | | | |
| DEV-022 | | | | | | | |
| DEV-023 | | | | | | | |
| DEV-030 | | | | | | | |
| DEV-031 | | | | | | | |
| DEV-032 | | | | | | | |
| DEV-033 | | | | | | | |
| DEV-034 | | | | | | | |
| DEV-040 | | | | | | | |
| DEV-041 | | | | | | | |
| DEV-042 | | | | | | | |
| DEV-043 | | | | | | | |
| DEV-044 | | | | | | | |
| DEV-045 | | | | | | | |
| DEV-050 | | | | | | | |
| DEV-051 | | | | | | | |
| DEV-052 | | | | | | | |
| DEV-060 | | | | | | | |
| DEV-061 | | | | | | | |
| DEV-062 | | | | | | | |
| DEV-063 | | | | | | | |
| DEV-064 | | | | | | | |
| DEV-070 | | | | | | | |
| DEV-071 | | | | | | | |
| DEV-072 | | | | | | | |
| DEV-073 | | | | | | | |
| DEV-080 | | | | | | | |
| DEV-081 | | | | | | | |
| DEV-082 | | | | | | | |
| DEV-090 | | | | | | | |
| DEV-091 | | | | | | | |
| DEV-100 | | | | | | | |

## 7. 主要機能の詳細結果

### 7.1 インストール・更新・起動

- 新規インストール:
- 旧版から更新:
- 再起動:
- データ維持:
- DB migration:
- 起動失敗/復旧UI:

Evidence:

- 

### 7.2 人物・Todo・チェックリスト

- CRUD:
- 期限・金額・持ち物:
- 完了状態:
- 関連人物・文書:
- 削除後の整合性:
- 再起動後:

Evidence:

- 

### 7.3 カメラ・画像選択・通常OCR

- カメラ許可:
- カメラ拒否:
- 画像選択:
- 日本語OCR:
- OCR空/失敗:
- 通常OCR時の外部送信なし確認方法:

使用した画像は個人情報を含まないテスト素材である: Yes / No

Evidence:

- 

### 7.4 AI画像解析

- 購入権限:
- 同意文:
- キャンセル時に画像選択なし:
- キャンセル時に通信なし:
- 同意後のHTTPS送信:
- 送信先host:
- 送信項目確認:
- 成功時の候補:
- 修正可能性:
- オフライン:
- タイムアウト/5xx:
- APIキー非露出:

Evidence:

- 

### 7.5 通知

| ケース | 予定時刻 | 実着時刻 | 差分 | 権限 | Alarm/Notification証跡 | 結果 |
|---|---|---|---|---|---|---|
| normal | | | | | | |
| reboot | | | | | | |
| update/install-r | | | | | | |

- 編集後の旧通知取消:
- Todo削除後の通知取消:
- 重複通知:
- タイムゾーン:
- ロック画面表示内容:

Evidence:

- 

### 7.6 広告

- 本番広告表示:
- 広告ロード失敗時の主要機能:
- 広告除去前:
- 広告除去後:
- 再起動後:
- 同意フロー:
- Android広告ID:
- iOS ATT/IDFA:
- パーソナライズ/非パーソナライズ/Limited Ads:

Evidence:

- 

### 7.7 課金

| 商品 | 商品ID | 価格 | 購入 | 取消 | 保留/失敗 | 復元 | 再起動後 | 結果 |
|---|---|---|---|---|---|---|---|---|
| 広告除去 | | | | | | | | |
| AI分析 | | | | | | | | |

購入トークン・注文番号を証跡から除外/マスクした: Yes / No

Evidence:

- 

### 7.8 データ削除・エクスポート・復旧

- JSONが有効:
- 含まれるデータ:
- 画像本体を含まない:
- ローカル画像パスを含まない:
- 一括削除:
- 孤立画像削除:
- 通知取消:
- アンインストール後:
- DB破損時の書き込み停止:
- 退避情報:
- 初期化確認:

Evidence:

- 

### 7.9 オフライン・バックグラウンド・低ストレージ

- オフラインCRUD:
- OCR:
- AdMob失敗:
- Billing失敗:
- AI失敗:
- バックグラウンド復帰:
- 二重保存/二重購入:
- 低ストレージ:

Evidence:

- 

### 7.10 UI・アクセシビリティ

- 小画面:
- 大画面:
- 文字サイズ拡大:
- ダーク/ライト:
- 回転:
- 読み上げ:
- 広告による遮蔽:
- 同意/購入/削除文言の表示:

Evidence:

- 

## 8. ストア開示整合性

参照: [store-disclosure-consistency-checklist.md](../store/store-disclosure-consistency-checklist.md)

| 文書/回答 | 状態 | 差分・修正 |
|---|---|---|
| Privacy Policy | PASS/FAIL/BLOCKED | |
| Support Page | | |
| Google Play Data safety | | |
| Apple App Privacy | | |
| Data Inventory | | |
| Android権限 | | |
| iOS権限/Privacy Manifest | | |
| AdMob/ATT/同意 | | |
| AI画像送信 | | |
| 課金 | | |
| 削除/エクスポート | | |

総合判定: `APPROVED` / `CORRECTION_REQUIRED` / `BLOCKED`

## 9. 欠陥一覧

| Defect ID | Title | Severity | Priority | Platform/Device | Status | Workaround | Release blocker |
|---|---|---|---|---|---|---|---|
| | | | | | | | |

## 10. BLOCKED / INCONCLUSIVE

| Case ID | 状態 | 理由 | 解消に必要なもの | Owner | 期限 |
|---|---|---|---|---|---|
| | | | | | |

## 11. 受容した既知問題

| Defect ID | 影響 | 回避策 | 受容理由 | 承認者 | 修正予定 |
|---|---|---|---|---|---|
| | | | | | |

S0/S1は受容しません。S2を受容する場合も、データ保護、課金、通知、削除、ストア開示への影響がないことを確認します。

## 12. 証跡索引

| Evidence ID | 種別 | 対象ケース | 保存先 | 個人情報/秘密値の除去確認 |
|---|---|---|---|---|
| | screenshot/video/log/json | | | Yes/No |

## 13. 最終チェック

- [ ] すべての必須ケースを実行
- [ ] すべての結果にEvidenceまたは理由がある
- [ ] S0/S1 openが0件
- [ ] BLOCKED/INCONCLUSIVEを解消または対象外として承認
- [ ] Android内部テスト経由インストール済み
- [ ] iOS公開対象ならTestFlight経由インストール済み
- [ ] normal/reboot/update通知PASS
- [ ] カメラ/画像選択/通常OCR PASS
- [ ] AI同意キャンセル/成功/失敗 PASS
- [ ] 本番広告/広告失敗/広告除去 PASS
- [ ] 2商品購入/取消/復元 PASS
- [ ] 一括削除/エクスポート/復旧 PASS
- [ ] ストア開示整合性 `APPROVED`
- [ ] 証跡に個人情報、秘密値、購入トークンがない

## 14. 承認

| Role | Name | Date | Decision | Comment |
|---|---|---|---|---|
| Tester | | | | |
| Engineering review | | | | |
| Privacy/store review | | | | |
| Release owner | | | | |

最終判定:

`PASS / READY_FOR_SUBMISSION`  
`CONDITIONAL_PASS`  
`FAIL / RELEASE_BLOCKED`  
`BLOCKED`  
`NOT_ASSESSED`

判定根拠:

- 
