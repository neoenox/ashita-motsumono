# Release 実機テスト 欠陥報告

> 本テンプレートを1欠陥につき1件複製します。GitHub Issueへ転記する場合も、個人情報、秘密値、購入トークン、APIキー、未加工の実画像を含めません。

## 1. 識別情報

| 項目 | 記入内容 |
|---|---|
| Defect ID | |
| Title | `[Platform][Feature] 簡潔な症状` |
| Status | `New` / `Confirmed` / `In Progress` / `Fixed` / `Retest Failed` / `Verified` / `Closed` / `Blocked` |
| Severity | `S0 Critical` / `S1 High` / `S2 Medium` / `S3 Low` |
| Priority | `P0` / `P1` / `P2` / `P3` |
| Release blocker | Yes / No |
| Reporter | |
| Reported at | |
| Owner | |
| Related test case | `DEV-xxx` |
| Related issue/PR | |

## 2. 概要

### 症状

<!-- 何が起きたかを1〜3文で記載 -->


### 利用者影響

<!-- 誰が、どの機能で、どの程度困るか -->


### データ・プライバシー・課金への影響

- データ消失/破損: Yes / No / Unknown
- 個人情報の意図しない表示/送信: Yes / No / Unknown
- 同意前の通信: Yes / No / Unknown
- 課金の誤付与/未付与/二重処理: Yes / No / Unknown
- 通知の誤送信/未送信/重複: Yes / No / Unknown
- 削除要求の不履行: Yes / No / Unknown
- ストア開示との矛盾: Yes / No / Unknown

影響の詳細:


S0/S1候補の場合、再現調査より先に必要な封じ込め（配布停止、広告/AI機能停止、商品停止等）を記載します。

## 3. 対象ビルド

| 項目 | 記入内容 |
|---|---|
| Repository | `kaenozu/ashita-motsumono` |
| Branch / Tag | |
| Commit SHA | |
| Base master SHA | |
| Android versionName/versionCode | |
| iOS version/build | |
| Application ID / Bundle ID | |
| 配布経路 | Play内部テスト / APK / TestFlight / その他 |
| Build/Run ID | |
| Artifact SHA-256 | |
| AdMob構成 | 本番 / テスト / 未設定 / 不明 |
| 商品ID | `remove_ads` / `ai_analysis` / その他 / N/A |
| Gemini Proxy host | |

秘密値、完全な広告ユニットID、APIキー、購入トークンは記録しません。

## 4. 環境

| 項目 | 記入内容 |
|---|---|
| Platform | Android / iOS |
| メーカー/機種 | |
| OS version/build | |
| 画面サイズ/表示倍率 | |
| 文字サイズ | |
| Locale | |
| Timezone | |
| Date/time automatic | On / Off |
| Network | Wi-Fi / Cellular / Offline / 制限あり |
| Battery saver | On / Off |
| Background restriction | |
| App permissions | Camera / Photos / Notifications 等 |
| Store account state | 未購入 / 広告除去購入 / AI購入 / 両方 / 不明 |
| Install state | 新規 / 更新 / 復元 / 再インストール |
| Previous app version | |
| Free storage | |

## 5. 前提条件

1. 
2. 
3. 

使用したデータ:

- 個人情報を含まない合成データ: Yes / No
- 画像タイプ:
- Todo/人物/通知状態:
- 購入状態:

## 6. 再現手順

1. 
2. 
3. 
4. 
5. 

再現手順は、別のテスターが同じビルドと端末条件で実行できる具体性で記載します。

## 7. 期待結果


## 8. 実際の結果


### 表示された文言/エラーコード

```text

```

個人情報、ファイルパス中のユーザー名、トークン等はマスクします。

## 9. 再現性

| 項目 | 記入内容 |
|---|---|
| 再現回数 | / 回 |
| 再現率 | % |
| 初回のみ | Yes / No |
| 特定端末のみ | Yes / No / Unknown |
| 特定OSのみ | Yes / No / Unknown |
| 特定ネットワークのみ | Yes / No / Unknown |
| 特定権限状態のみ | Yes / No / Unknown |
| 特定購入状態のみ | Yes / No / Unknown |
| 再起動後も再現 | Yes / No / Unknown |
| 再インストール後も再現 | Yes / No / Not tested |

## 10. 証跡

| Evidence ID | 種別 | 説明 | 保存先 | マスク確認 |
|---|---|---|---|---|
| | Screenshot | | | Yes/No |
| | Video | | | Yes/No |
| | Log | | | Yes/No |
| | dumpsys/Xcode log | | | Yes/No |
| | Network observation | | | Yes/No |

### Androidコマンド例

対象serialとpackageを明示し、無関係な端末へ実行しません。

```powershell
adb -s <serial> shell dumpsys package com.ashita_motsumono
adb -s <serial> shell dumpsys alarm
adb -s <serial> shell dumpsys notification
adb -s <serial> logcat -d
```

ログは対象package/時刻に絞り、アカウント、トークン、画像内容等を除去します。

### iOS証跡例

- TestFlight build情報
- Xcode Devices and Simulatorsのdevice log
- macOS Consoleの対象プロセスログ
- OS権限画面
- ATT表示
- StoreKit購入/復元画面

## 11. 通信・外部サービス情報

| 項目 | 記入内容 |
|---|---|
| オフラインで再現 | Yes / No |
| 対象サービス | AdMob / Play Billing / Apple IAP / Cloudflare Workers / Gemini API / N/A |
| HTTP/SDK結果 | 成功 / timeout / DNS / 4xx / 5xx / 不明 |
| 本番/テスト構成 | |
| 同意状態 | 未表示 / 同意 / 拒否 / 不明 |
| ATT状態 | Authorized / Denied / Restricted / Not Determined / N/A |
| 広告ID/IDFA | 取得有無のみ。値は記録しない |
| 外部サービスstatus | |

## 12. データ整合性調査

- 発生前のデータ件数:
- 発生後のデータ件数:
- 再起動後:
- DB読み込み失敗:
- 破損退避ファイル:
- 通知同期キュー:
- 画像削除キュー:
- 孤立文書/画像:
- 購入済みフラグ:

本番ユーザーデータベースをIssueへ添付しません。必要な場合は合成データで再現し、スキーマ・件数・エラーだけを共有します。

## 13. 回避策

<!-- 利用者が安全に回避できる手順。データ削除を安易な回避策にしない -->


回避策の副作用:


## 14. 原因仮説

### 確認できた事実

- 

### 未確認

- 

### 推測

- 

推測を事実として記載しません。

## 15. 重大度判定

### Severity基準

- **S0 Critical**: 同意なしの画像送信、秘密値漏えい、広範囲データ消失、誤課金/二重課金、削除不能など、直ちに配布停止が必要
- **S1 High**: 起動不能、主要機能不能、購入復元不能、通知の重大不整合、再現性の高いクラッシュ、ストア開示の重大な誤り
- **S2 Medium**: 回避策がある機能不良、特定端末/条件での不具合、限定的なデータ/UI不整合
- **S3 Low**: 軽微な表示、文言、操作性の問題

選択したSeverityの理由:


Priorityの理由:


## 16. 修正方針

- Root cause:
- 修正対象ファイル:
- データmigrationの要否:
- ストア文書更新の要否:
- 権限/SDK/外部設定変更の要否:
- 回帰テスト:
- 実機再テストケース:
- ロールバック/Feature disable:

## 17. 修正内容

| 項目 | 記入内容 |
|---|---|
| Fix PR | |
| Fix commit | |
| Code change summary | |
| Automated tests | |
| CI result | |
| Documentation changes | |
| Store disclosure changes | |

## 18. 再テスト

| 項目 | 記入内容 |
|---|---|
| Retest build/commit | |
| Retest device | |
| Retest date | |
| Original steps result | PASS / FAIL / BLOCKED |
| Related regression cases | |
| Data integrity confirmed | Yes / No / N/A |
| Purchase confirmed | Yes / No / N/A |
| Privacy/disclosure confirmed | Yes / No / N/A |
| Evidence | |

再テスト所見:


## 19. クローズ条件

- [ ] 原因を特定または安全に封じ込め
- [ ] 修正PRがmasterへ統合
- [ ] 自動回帰テストが成功
- [ ] 元の端末/条件で再テストPASS
- [ ] 必要な別端末/OSで回帰確認
- [ ] データ・課金・通知・削除への副作用なし
- [ ] プライバシーポリシー/ストア回答への影響を反映
- [ ] Evidenceがマスク済み
- [ ] S0/S1の場合、配布再開をRelease ownerが承認

## 20. 最終承認

| Role | Name | Date | Decision | Comment |
|---|---|---|---|---|
| Reporter | | | | |
| Fix owner | | | | |
| Retester | | | | |
| Privacy/store reviewer | | | | |
| Release owner | | | | |
