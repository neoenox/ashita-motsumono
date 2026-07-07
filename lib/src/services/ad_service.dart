// lib/src/services/ad_service.dart
// AdMob バナー広告の初期化と生成をラップする。
// 関連: purchase_service.dart, settings_screen.dart, home_screen.dart

import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();

  static final _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static final _prodBannerAdUnitId = const String.fromEnvironment(
    'ADMOB_BANNER_AD_UNIT_ID',
    defaultValue: '',
  );

  static String get _bannerAdUnitId =>
      _prodBannerAdUnitId.isNotEmpty ? _prodBannerAdUnitId : _testBannerAdUnitId;

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  static BannerAd createBannerAd({
    required AdSize size,
    void Function(Object)? onError,
  }) {
    return BannerAd(
      adUnitId: _bannerAdUnitId,
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
