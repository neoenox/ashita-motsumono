// test/store_listing_docs_test.dart
// Play Console 提出に必要な文書が、実装済みの広告・課金・削除導線と
// 矛盾しない説明を含むことを検証する。
// 関連: docs/STORE_LISTING_JA.md, docs/PLAY_CONSOLE_SUBMISSION.md

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('store listing documents privacy-sensitive behavior', () {
    final listing = File('docs/STORE_LISTING_JA.md').readAsStringSync();

    expect(listing, contains('独自サーバーには送信しません'));
    expect(listing, contains('Google Mobile Ads'));
    expect(listing, contains('Google Play Billing'));
    expect(listing, contains('設定」>「データ管理」>「登録データをすべて削除'));
    expect(listing, contains('学習済み持ち物候補'));
  });

  test('privacy policy documents local storage, export, and deletion', () {
    final privacyPolicy = File('docs/privacy_policy.md').readAsStringSync();

    expect(privacyPolicy, contains('独自サーバーを運用しておらず'));
    expect(privacyPolicy, contains('Google Mobile Ads'));
    expect(privacyPolicy, contains('Google Play Billing'));
    expect(privacyPolicy, contains('保存画像のファイル本体と端末内画像パス'));
    expect(privacyPolicy, contains('登録データをすべて削除'));
  });

  test('submission checklist includes store assets and monetization checks', () {
    final checklist = File('docs/PLAY_CONSOLE_SUBMISSION.md').readAsStringSync();

    expect(checklist, contains('assets/store/icon-512.png'));
    expect(checklist, contains('assets/store/screenshots/01-home.png'));
    expect(checklist, contains('ADMOB_APP_ID'));
    expect(checklist, contains('ADMOB_BANNER_AD_UNIT_ID'));
    expect(checklist, contains('IAP_REMOVE_ADS_PRODUCT_ID'));
    expect(checklist, contains('広告削除の購入・復元'));
  });

  test('todo document points release work to the Play Console checklist', () {
    final todo = File('docs/TODO.md').readAsStringSync();

    expect(todo, contains('docs/PLAY_CONSOLE_SUBMISSION.md'));
    expect(todo, isNot(contains('v0.2.4')));
    expect(todo, isNot(contains('0.2.0+1')));
  });
}
