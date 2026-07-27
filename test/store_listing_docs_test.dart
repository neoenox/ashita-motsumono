// test/store_listing_docs_test.dart
// Play Console 提出に必要な文書が、実装済みの広告・課金・削除導線と
// 矛盾しない説明を含むことを検証する。
// 関連: docs/STORE_LISTING_JA.md, docs/PLAY_CONSOLE_SUBMISSION.md

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('store listing documents privacy-sensitive behavior', () {
    final listing = File('docs/STORE_LISTING_JA.md').readAsStringSync();

    expect(listing, contains('通常の日本語OCRは端末上'));
    expect(listing, contains('Cloudflare Workers'));
    expect(listing, contains('Google Gemini API'));
    expect(listing, contains('Google Mobile Ads'));
    expect(listing, contains('Google Play Billing'));
    expect(listing, contains('設定」から「登録データをすべて削除'));
    expect(listing, contains('学習済み持ち物候補'));
    expect(listing, isNot(contains('子ども名、Todo、OCR全文、画像は外部サーバーへ送信しません')));
  });

  test('privacy policy documents local storage, export, and deletion', () {
    final privacyPolicy = File('docs/privacy_policy.md').readAsStringSync();

    expect(privacyPolicy, contains('ログイン機能、家族共有機能、独自サーバーとのTodo同期機能はありません'));
    expect(privacyPolicy, contains('通常の文字認識'));
    expect(privacyPolicy, contains('Cloudflare Workers'));
    expect(privacyPolicy, contains('Google Gemini API'));
    expect(privacyPolicy, contains('Google Mobile Ads'));
    expect(privacyPolicy, contains('Google Play Billing'));
    expect(privacyPolicy, contains('保存画像のファイル本体および端末内画像パス'));
    expect(privacyPolicy, contains('登録データをすべて削除'));
    expect(privacyPolicy, isNot(contains('外部サーバーに送信されることはありません')));
  });

  test(
    'submission checklist includes store assets and monetization checks',
    () {
      final checklist = File(
        'docs/PLAY_CONSOLE_SUBMISSION.md',
      ).readAsStringSync();

      expect(checklist, contains('assets/store/icon-512.png'));
      expect(checklist, contains('assets/store/screenshots/01-home.png'));
      expect(checklist, contains('ADMOB_APP_ID'));
      expect(checklist, contains('ADMOB_BANNER_AD_UNIT_ID'));
      expect(checklist, contains('IAP_REMOVE_ADS_PRODUCT_ID'));
      expect(checklist, contains('IAP_AI_ACCESS_PRODUCT_ID'));
      expect(checklist, contains('広告削除商品の価格表示、購入・復元、広告非表示'));
      expect(checklist, contains('AI分析商品の価格表示、同意、購入・復元、実行'));
    },
  );

  test('submission checklist matches AI image data flow', () {
    final checklist = File(
      'docs/PLAY_CONSOLE_SUBMISSION.md',
    ).readAsStringSync();

    expect(checklist, contains('通常の日本語OCRは端末上'));
    expect(checklist, contains('解析対象の画像、画像形式、解析基準日およびタイムゾーン'));
    expect(checklist, contains('Cloudflare Workers経由でGoogle Gemini API'));
    expect(checklist, contains('外部送信の説明に同意'));
    expect(checklist, isNot(contains('独自サーバーへ子ども名、Todo、OCR全文、画像を送信しない')));
  });

  test('todo document describes v0.7.0 roadmap', () {
    final todo = File('docs/TODO.md').readAsStringSync();

    expect(todo, contains('v0.7.0'));
    expect(todo, contains('PDF取り込み'));
    expect(todo, isNot(contains('v0.2.4')));
  });
}
