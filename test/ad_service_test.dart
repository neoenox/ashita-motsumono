// test/ad_service_test.dart
// AdMob 設定が未指定のローカル/テスト環境で広告を読み込まないことを検証する。
// 関連: lib/src/services/ad_service.dart, lib/src/screens/home_screen.dart

import 'package:ashita_motsumono/src/services/ad_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  test('does not create banner ads without a production ad unit id', () {
    expect(AdService.bannerAdsConfigured, isFalse);
    expect(AdService.createBannerAd(size: AdSize.banner), isNull);
  });
}
