import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_navigation.dart';
import '../app_state.dart';
import '../models/entities.dart';
import '../services/ad_service.dart';
import '../services/app_settings.dart';
import '../services/export_service.dart';
import '../services/purchase_provider.dart';
import '../services/receive_share_handler.dart';
import '../theme/app_theme.dart';
import 'add_child_screen.dart';
import 'add_todo_screen.dart';
import 'review_extraction_screen.dart';
import 'review_extractions_screen.dart';
import 'settings_screen.dart';
import 'widgets/home_status_cards.dart';
import 'widgets/todo_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _notificationInfoShownKey = 'notification_info_shown_v1';

  bool _notificationDialogShown = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _filterPersonId;
  ReceiveShareHandler? _receiveShareHandler;
  bool _shareListenerInitialized = false;
  bool _fabPressed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initShareIntentListener();
      }
    });
  }

  void _initShareIntentListener() {
    if (_shareListenerInitialized) return;
    _shareListenerInitialized = true;

    final handler = ReceiveShareHandler(
      appState: context.read<AppState>(),
      appSettings: widget.settings,
    );

    _receiveShareHandler = handler;

    unawaited(
      handler.start(
        onResult: _handleShareResult,
        onError: (error, stackTrace) {
          if (kDebugMode) {
            debugPrint(
              'Share intent error: '
              '$error\n$stackTrace',
            );
          }

          if (!mounted) return;

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('共有データを受信できませんでした。')));
        },
      ),
    );
  }

  Future<void> _handleShareResult(ReceiveShareResult result) async {
    if (!mounted) return;

    switch (result) {
      case ReceiveShareFailure():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            duration: const Duration(seconds: 8),
          ),
        );

      case ReceiveShareSuccess():
        final navigator = Navigator.of(context);

        navigator.popUntil((route) => route.isFirst);

        final Widget reviewScreen;

        if (result.drafts.length == 1) {
          reviewScreen = ReviewExtractionScreen(
            draft: result.drafts.single,
            documentId: result.documentId,
          );
        } else {
          reviewScreen = ReviewExtractionsScreen(
            drafts: result.drafts,
            documentId: result.documentId,
          );
        }

        await pushAdaptive<void>(context, (_) => reviewScreen);
    }
  }

  @override
  void dispose() {
    final handler = _receiveShareHandler;
    if (handler != null) {
      unawaited(handler.dispose());
    }
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loaded = context.read<AppState>().loaded;
    if (loaded && !_notificationDialogShown) {
      _notificationDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_showNotificationInfoIfNeeded());
      });
    }
  }

  Future<void> _showNotificationInfoIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || (prefs.getBool(_notificationInfoShownKey) ?? false)) return;

    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final previousNight = _fmtNotificationTime(
      widget.settings.previousNightHour,
      widget.settings.previousNightMinute,
    );
    final sameMorning = _fmtNotificationTime(
      widget.settings.sameMorningHour,
      widget.settings.sameMorningMinute,
    );

    final enableNotifications = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('通知について'),
        content: Text(
          '前日$previousNightと当日$sameMorningにTodoのリマインド通知をお送りします。'
          '通知を有効にする場合は、次に表示される端末の通知許可で「許可」を選んでください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('あとで'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('通知を有効にする'),
          ),
        ],
      ),
    );

    // "あとで" is a true deferral: do not persist the shown flag.
    if (!mounted || enableNotifications != true) return;
    await prefs.setBool(_notificationInfoShownKey, true);
    if (!mounted) return;

    try {
      await appState.requestNotificationPermissions();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('通知設定を確認しました')));
    } on Object {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('通知設定を確認できませんでした')));
    }
  }

  String _fmtNotificationTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Future<void> _exportData(AppState state) async {
    final shouldExport = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('データをエクスポート'),
        content: const Text(
          '人物名、Todo、OCR全文を含むJSONをクリップボードにコピーします。'
          '保存画像のファイル本体と端末内画像パスは含めません。'
          '他のアプリに貼り付けると個人情報が含まれる可能性があります。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('コピーする'),
          ),
        ],
      ),
    );
    if (!mounted || shouldExport != true) return;

    final sanitized = createExportSnapshot(state);
    final json = const JsonEncoder.withIndent('  ').convert(sanitized.toJson());
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('データをクリップボードにコピーしました')));
  }

  Future<void> _copyCorruptBackup(AppState state) async {
    final backup = state.loadCorruptBackup();
    if (backup == null || backup.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('退避データが見つかりませんでした')));
      return;
    }
    await Clipboard.setData(ClipboardData(text: backup));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('退避データをクリップボードにコピーしました')));
  }

  List<AppTodo> _filter(List<AppTodo> todos, List<PersonProfile> children) {
    final childMap = {for (final child in children) child.id: child};
    return todos.where((todo) {
      if (_filterPersonId != null && todo.personId != _filterPersonId) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      if (todo.title.toLowerCase().contains(query)) return true;
      if (todo.category.label.contains(query)) return true;
      if (todo.note?.toLowerCase().contains(query) == true) return true;
      if (todo.amount?.toString().contains(query) == true) return true;
      final child = childMap[todo.personId];
      return child?.name.toLowerCase().contains(query) == true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final todayTodos = _filter(state.todosForDate(today), state.children);
    final tomorrowTodos = _filter(state.todosForDate(tomorrow), state.children);
    final undated = _filter(state.undatedTodos(), state.children);
    final upcoming = _filter(state.futureTodos(), state.children);
    final allFiltered =
        todayTodos.isEmpty &&
        tomorrowTodos.isEmpty &&
        undated.isEmpty &&
        upcoming.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('あしたもつもの'),
        actions: [
          IconButton(
            tooltip: '人物を追加',
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () =>
                pushAdaptive<void>(context, (_) => const AddChildScreen()),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'export') unawaited(_exportData(state));
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download_outlined),
                  title: Text('データをエクスポート'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              Spacing.sm,
              Spacing.md,
              0,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '検索…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
            ),
          ),
          if (state.children.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.sm,
                Spacing.md,
                0,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: state.children
                      .map(
                        (child) => Padding(
                          padding: const EdgeInsets.only(right: Spacing.sm),
                          child: FilterChip(
                            label: Text(child.name),
                            selected: _filterPersonId == child.id,
                            onSelected: (selected) {
                              setState(
                                () => _filterPersonId = selected
                                    ? child.id
                                    : null,
                              );
                            },
                            selectedColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            labelStyle: TextStyle(
                              color: _filterPersonId == child.id
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : null,
                            ),
                            checkmarkColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                            avatar: CircleAvatar(
                              radius: 10,
                              backgroundColor: Color(child.colorValue),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.sm,
                Spacing.md,
                96,
              ),
              children: [
                if (state.lastLoadHadCorruptData) ...[
                  CorruptDataCard(
                    onCopy: () => unawaited(_copyCorruptBackup(state)),
                  ),
                  const SizedBox(height: Spacing.sm),
                ],
                if (state.children.isEmpty)
                  FirstRunCard(
                    onAddPerson: () => pushAdaptive<void>(
                      context,
                      (_) => const AddChildScreen(),
                    ),
                  ),
                if (state.children.isNotEmpty &&
                    allFiltered &&
                    _searchQuery.isEmpty &&
                    state.todos.isEmpty)
                  const EmptyState(),
                if (state.children.isNotEmpty &&
                    allFiltered &&
                    _searchQuery.isNotEmpty)
                  NoSearchResults(query: _searchQuery),
                if (todayTodos.isNotEmpty || _searchQuery.isEmpty) ...[
                  TodoSection(title: '今日やること', todos: todayTodos),
                  const SizedBox(height: Spacing.md),
                ],
                TodoSection(title: '明日の持ち物・提出', todos: tomorrowTodos),
                const SizedBox(height: Spacing.md),
                TodoSection(title: '期限未設定・要確認', todos: undated),
                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: Spacing.md),
                  UpcomingSection(todos: upcoming),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _MainBottomNav(selectedIndex: 0),
      bottomSheet: context.watch<PurchaseProvider>().adRemoved
          ? null
          : const SafeArea(bottom: true, child: _AdBanner()),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildFab(BuildContext context) {
    final button = FloatingActionButton.extended(
      onPressed: () =>
          pushAdaptive<void>(context, (_) => const AddTodoScreen()),
      icon: const Icon(Icons.add),
      label: const Text('追加'),
    );
    if (context.isReducedMotion) return button;

    return Listener(
      onPointerDown: (_) => _setFabPressed(true),
      onPointerUp: (_) => _setFabPressed(false),
      onPointerCancel: (_) => _setFabPressed(false),
      child: AnimatedScale(
        duration: AppMotion.quick,
        curve: AppMotion.standardCurve,
        scale: _fabPressed ? 0.96 : 1,
        child: button,
      ),
    );
  }

  void _setFabPressed(bool pressed) {
    if (!mounted || _fabPressed == pressed) return;
    setState(() => _fabPressed = pressed);
  }
}

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
