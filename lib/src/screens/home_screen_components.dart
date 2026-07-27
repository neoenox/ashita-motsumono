part of 'home_screen.dart';

class _MainBottomNav extends StatelessWidget {
  const _MainBottomNav({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: (index) {
        if (index == 1 && selectedIndex != 1) {
          pushAdaptive<void>(
            context,
            (_) => SettingsScreen(settings: context.read<AppSettings>()),
          );
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'ホーム',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: '設定',
        ),
      ],
    );
  }
}

class _AdBanner extends StatefulWidget {
  const _AdBanner();

  @override
  State<_AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<_AdBanner> {
  BannerAd? _ad;
  BannerAd? _loadingAd;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final ad = AdService.createBannerAd(
      size: AdSize.fullBanner,
      onLoaded: (loadedAd) {
        if (!mounted) {
          loadedAd.dispose();
          return;
        }
        setState(() {
          _loadingAd = null;
          _ad = loadedAd;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _loadingAd = null;
          _ad = null;
        });
      },
    );
    if (ad == null) return;
    _loadingAd = ad;
    ad.load();
  }

  @override
  void dispose() {
    _loadingAd?.dispose();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return Container(
      color: Colors.grey.shade100,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
