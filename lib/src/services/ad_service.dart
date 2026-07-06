// lib/src/services/ad_service.dart
// AdMob バナー広告の初期化と生成をラップする。
// 関連: purchase_service.dart, settings_screen.dart, home_screen.dart

import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();

  static final _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  static BannerAd createBannerAd({
    required AdSize size,
    void Function(Object)? onError,
  }) {
    return BannerAd(
      adUnitId: _testBannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {},
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onError?.call(error);
        },
      ),
    );
  }
}
