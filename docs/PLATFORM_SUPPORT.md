# プラットフォームサポート方針

基準日: 2026-08-23

## 現行MVPの正式サポート

| プラットフォーム | 状態 | 根拠 |
|---|---|---|
| Android | **正式サポート** | Flutter/Android CI、Android release validation、Play内部テスト向けのrelease手順を運用中 |
| iOS | **未保証・将来対応** | 正式iOSビルド、macOS CI、TestFlight、iOS実機受入を未完了 |
| Web / Windows / macOS / Linux | 対象外 | 現行MVPの対象外 |

iOS向けコード、ネイティブ設定、Apple App Privacy回答案は将来対応の準備として保持します。これらのファイルが存在すること、またはローカルでFlutterプロジェクトを生成できることだけでは、iOSの正式サポートや公開準備完了を意味しません。

## iOSを正式サポートへ戻す条件

次の証跡を同一のrelease sessionで揃えるまで、iOSをsupported platformとして記載しません。

- macOS runnerで `flutter build ios --no-codesign` が成功すること
- CocoaPods、Xcode project、Deployment Target、Info.plist、Privacy Manifestの整合性を確認すること
- iOSのカメラ/写真、PDF・複数画像取り込み、日本語OCR、通知、課金・復元、AI解析同意、データ削除・exportを実機またはTestFlightで受入すること
- iOS向けのストア申告とプライバシー回答を、正式成果物・SDK設定・実機結果に基づいて確定すること
- 実行結果、OS/device、version/build、commit SHA、未確認項目を `docs/testing/` の証跡へ記録すること

未検証項目が残る場合は `BLOCKED` としてAndroidの合格判定から分離します。Apple signing credential、TestFlight upload、App Store公開は、この文書の更新だけでは実行しません。

## ドキュメントの読み方

- `README.md` は現行MVPの公開サポート範囲を示します。
- `docs/NATIVE_SETUP.md` のiOS節は将来対応用の設定メモです。
- `docs/store/apple-app-privacy.md` はiOS正式成果物未確認の申告下書きです。App Store Connectへ転記する正本ではありません。
