// lib/src/screens/home_screen.dart
// ホーム画面。今日・明日・未設定・今後のTodoをセクション分けして表示。
// FABからTodo追加、AppBarから子ども管理画面へ遷移。
// 初回起動時に通知説明ダイアログを表示。
// 関連: screens/add_todo_screen.dart, screens/add_child_screen.dart,
//       screens/todo_detail_screen.dart, app_state.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_state.dart';
import '../models/entities.dart';
import '../theme/app_theme.dart';
import '../services/ad_service.dart';
import '../services/app_settings.dart';
import '../services/purchase_provider.dart';
import 'add_child_screen.dart';
import 'add_todo_screen.dart';
import 'settings_screen.dart';
import 'widgets/filter_bar.dart';
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
  bool _showCompleted = false;
  String? _filterPersonId;

  @override
  void dispose() {
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
        if (mounted) {
          unawaited(_showNotificationInfoIfNeeded());
        }
      });
    }
  }

  Future<void> _showNotificationInfoIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || (prefs.getBool(_notificationInfoShownKey) ?? false)) return;

    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);

    final enableNotifications = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('通知について'),
        content: const Text(
          '前日20:00と当日7:00にTodoのリマインド通知をお送りします。'
          '通知を有効にする場合は、次に表示される端末の通知許可で「許可」を選んでください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('あとで'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('通知を有効にする'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    await prefs.setBool(_notificationInfoShownKey, true);
    if (!mounted || enableNotifications != true) return;

    try {
      await appState.requestNotificationPermissions();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('通知設定を確認しました')));
    } on Object catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('通知設定を確認できませんでした: $e')));
    }
  }

  Future<void> _exportData(AppState state) async {
    final shouldExport = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データをエクスポート'),
        content: const Text(
          '人物名、Todo、OCR全文を含むJSONをクリップボードにコピーします。'
          '保存画像のファイル本体と端末内画像パスは含めません。'
          '他のアプリに貼り付けると個人情報が含まれる可能性があります。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
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
    final childMap = {for (final c in children) c.id: c};
    return todos.where((t) {
      if (!_showCompleted && t.isDone) {
        return false;
      }
      if (_filterPersonId != null && t.personId != _filterPersonId) {
        return false;
      }
      if (_searchQuery.isEmpty) {
        return true;
      }
      final q = _searchQuery.toLowerCase();
      if (t.title.toLowerCase().contains(q)) {
        return true;
      }
      if (t.category.label.contains(q)) {
        return true;
      }
      if (t.note?.toLowerCase().contains(q) == true) {
        return true;
      }
      if (t.amount?.toString().contains(q) == true) {
        return true;
      }
      final child = childMap[t.personId];
      if (child?.name.toLowerCase().contains(q) == true) {
        return true;
      }
      return false;
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
        title: const Text('あした持つもの'),
        actions: [
          IconButton(
            tooltip: '設定',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsScreen(settings: widget.settings),
              ),
            ),
          ),
          IconButton(
            tooltip: '人物を追加',
            icon: const Icon(Icons.person_add),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AddChildScreen())),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'supporter') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(settings: widget.settings),
                  ),
                );
              }
              if (value == 'export') {
                unawaited(_exportData(state));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'supporter',
                child: ListTile(
                  leading: Icon(Icons.workspace_premium),
                  title: Text('サポーター'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
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
            padding: EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '検索…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.sm,
                ),
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
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),
          FilterBar(
            showCompleted: _showCompleted,
            filterPersonId: _filterPersonId,
            children: state.children,
            onToggleCompleted: (v) => setState(() => _showCompleted = v),
            onChangeChild: (id) => setState(() => _filterPersonId = id),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
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
                    onAddPerson: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddChildScreen()),
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
                  const SizedBox(height: Spacing.lg),
                ],
                TodoSection(title: '明日の持ち物・提出', todos: tomorrowTodos),
                const SizedBox(height: Spacing.lg),
                TodoSection(title: '期限未設定・要確認', todos: undated),
                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: Spacing.lg),
                  UpcomingSection(todos: upcoming),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: context.watch<PurchaseProvider>().adRemoved
          ? null
          : SafeArea(bottom: true, child: const _AdBanner()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddTodoScreen())),
        icon: const Icon(Icons.add),
        label: const Text('追加'),
      ),
    );
  }
}

AppSnapshot createExportSnapshot(AppState state) {
  return AppSnapshot(
    children: state.children,
    todos: state.todos,
    documents: state.documents
        .map((d) => d.copyWith(clearLocalImagePath: true))
        .toList(),
  );
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
    final size = AdSize.fullBanner;
    final ad = AdService.createBannerAd(
      size: size,
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
