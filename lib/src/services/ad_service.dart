// lib/src/services/ad_service.dart
// AdMob バナー広告の初期化と生成をラップする。
// 関連: purchase_service.dart, settings_screen.dart, home_screen.dart

import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();

  static final _prodBannerAdUnitId = const String.fromEnvironment(
    'ADMOB_BANNER_AD_UNIT_ID',
    defaultValue: '',
  );

  static bool get bannerAdsConfigured => _prodBannerAdUnitId.isNotEmpty;

  static Future<void> initialize() async {
    if (!bannerAdsConfigured) return;

    await MobileAds.instance.initialize();
  }

  static BannerAd? createBannerAd({
    required AdSize size,
    void Function(BannerAd)? onLoaded,
    void Function(Object)? onError,
  }) {
    if (!bannerAdsConfigured) return null;

    return BannerAd(
      adUnitId: _prodBannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (ad is BannerAd) {
            onLoaded?.call(ad);
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onError?.call(error);
        },
      ),
    );
  }
}
