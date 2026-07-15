// lib/src/screens/settings_screen.dart
// 通知時刻などをカスタマイズする設定画面。
// Stitch デザインに合わせてカードベースのレイアウトに刷新。
// 関連: app_settings.dart, home_screen.dart, notification_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../app_version.g.dart';
import '../services/app_settings.dart';
import '../services/purchase_provider.dart';
import '../theme/app_theme.dart';

typedef UrlAvailabilityCheck = Future<bool> Function(Uri uri);
typedef UrlLaunchAction = Future<bool> Function(Uri uri);

@visibleForTesting
Future<bool> tryOpenExternalPage({
  required Uri uri,
  required UrlAvailabilityCheck canOpen,
  required UrlLaunchAction launch,
}) async {
  try {
    if (!await canOpen(uri)) return false;
    return await launch(uri);
  } on Object {
    return false;
  }
}

final _themeModes = {
  ThemeMode.system: 'システム',
  ThemeMode.light: 'ライト',
  ThemeMode.dark: 'ダーク',
};

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings get settings => widget.settings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Spacing.md, Spacing.md, Spacing.md,
          MediaQuery.paddingOf(context).bottom + Spacing.lg,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: Text(
              '通知やサポーター機能の管理ができます',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          _SectionCard(
            icon: Icons.notifications_outlined,
            title: '通知時刻',
            description: '前日と当日のリマインド通知を設定します',
            child: Column(
              children: [
                _TimeTile(
                  icon: Icons.nightlight_round,
                  title: '夜 前日 ${_fmt(settings.previousNightHour, settings.previousNightMinute)}',
                  subtitle: '前日の持ち物を確認しましょう',
                  onTap: () => _pickTime(
                    context,
                    settings.previousNightHour,
                    settings.previousNightMinute,
                    (h, m) => settings.setPreviousNightTime(h, m),
                  ),
                ),
                const Divider(),
                _TimeTile(
                  icon: Icons.wb_sunny_outlined,
                  title: '朝 当日 ${_fmt(settings.sameMorningHour, settings.sameMorningMinute)}',
                  subtitle: '最終チェックで安心な1日を',
                  onTap: () => _pickTime(
                    context,
                    settings.sameMorningHour,
                    settings.sameMorningMinute,
                    (h, m) => settings.setSameMorningTime(h, m),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _SectionCard(
            icon: Icons.palette_outlined,
            title: 'テーマ',
            child: Consumer<AppSettings>(
              builder: (context, settings, _) {
                final current = settings.themeMode;
                return Padding(
                  padding: const EdgeInsets.only(top: Spacing.sm),
                  child: SegmentedButton<ThemeMode>(
                    segments: _themeModes.entries.map((e) {
                      return ButtonSegment<ThemeMode>(
                        value: e.key,
                        label: Text(e.value),
                      );
                    }).toList(),
                    selected: {current},
                    onSelectionChanged: (selected) {
                      settings.setThemeMode(selected.first);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _SectionCard(
            icon: Icons.volunteer_activism_outlined,
            title: 'サポーター',
            description: '広告除去と開発支援',
            child: Consumer<PurchaseProvider>(
              builder: (context, purchase, _) => _SupporterCard(purchase: purchase),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _SectionCard(
            icon: Icons.auto_awesome_outlined,
            title: 'AI分析',
            description: '手書きメモも解析できるAI画像認識',
            child: Consumer<PurchaseProvider>(
              builder: (context, purchase, _) => _AiAccessCard(purchase: purchase),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          const Divider(),
          const SizedBox(height: Spacing.sm),
          ListTile(
            leading: Icon(Icons.delete_outline, color: cs.error),
            title: const Text('登録データをすべて削除'),
            subtitle: const Text('人物、Todo、履歴、保存画像をこの端末から削除します'),
            contentPadding: EdgeInsets.zero,
            onTap: () => _confirmClearAllData(context),
          ),
          const SizedBox(height: Spacing.lg),
          const Divider(),
          const SizedBox(height: Spacing.sm),
          Text('その他', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Spacing.sm),
          ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: const Text('プライバシーポリシー'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            contentPadding: EdgeInsets.zero,
            onTap: () => _openExternalPage(
              Uri.parse('https://lp-5t7.pages.dev/apps/ashita-motsumono/privacy'),
              'リンクを開けませんでした',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('お問い合わせ'),
            trailing: const Icon(Icons.chevron_right, size: 16),
            contentPadding: EdgeInsets.zero,
            onTap: () => _openExternalPage(
              Uri.parse('https://lp-5t7.pages.dev/apps/ashita-motsumono/contact'),
              'お問い合わせページを開けませんでした',
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Center(
            child: Text(
              'Version $appVersion',
              style: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _SettingsBottomNav(),
    );
  }

  Future<void> _openExternalPage(
    Uri uri,
    String errorMessage,
  ) async {
    final opened = await tryOpenExternalPage(
      uri: uri,
      canOpen: canLaunchUrl,
      launch: (target) => launchUrl(
        target,
        mode: LaunchMode.externalApplication,
      ),
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  Future<void> _pickTime(
    BuildContext context,
    int initialHour,
    int initialMinute,
    Future<void> Function(int hour, int minute) onSave,
  ) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );
    if (time == null) return;

    try {
      await onSave(time.hour, time.minute);
      if (!mounted) return;
      setState(() {});
      await appState.rescheduleAllNotifications();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('通知時刻を保存し、既存Todoの通知も更新しました')),
      );
    } on Object catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('通知時刻の保存に失敗しました: $e')));
    }
  }

  Future<void> _confirmClearAllData(BuildContext context) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('登録データを削除しますか？'),
        content: const Text('人物、Todo、読み取り履歴、保存画像をこの端末から削除します。この操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await appState.clearAllData();
      await settings.clearLearnedItemLabels();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('登録データを削除しました')));
    } on Object catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('登録データの削除に失敗しました: $e')));
    }
  }
}

class _SettingsBottomNav extends StatelessWidget {
  const _SettingsBottomNav();

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 1,
      onTap: (index) {
        if (index == 0) {
          Navigator.of(context).pop();
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'ホーム',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          activeIcon: Icon(Icons.settings),
          label: '設定',
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: Spacing.sm),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: Spacing.xs),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(height: Spacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _SupporterCard extends StatelessWidget {
  const _SupporterCard({required this.purchase});

  final PurchaseProvider purchase;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (purchase.adRemoved) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: cs.primary, size: 20),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('サポーター登録済み',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                const Text('広告なしで使えます。ご購入ありがとうございます。'),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.favorite, color: cs.primary, size: 20),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('買い切りサポーター',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: Spacing.xs),
                  const Text('一度の購入で、アプリをずっと快適に。'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        _BenefitRow(icon: Icons.check, text: '広告なしでホーム画面を広く使える'),
        const SizedBox(height: Spacing.xs),
        _BenefitRow(icon: Icons.check, text: 'ログイン不要・端末内保存の方針はそのまま'),
        const SizedBox(height: Spacing.xs),
        _BenefitRow(icon: Icons.check, text: '今後の継続的な開発を応援'),
        const SizedBox(height: Spacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: purchase.canPurchase ? purchase.purchase : null,
            icon: purchase.busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.workspace_premium),
            label: const Text('広告を消して応援する'),
          ),
        ),
        if (purchase.statusMessage != null) ...[
          const SizedBox(height: Spacing.sm),
          Text(
            purchase.statusMessage!,
            style: TextStyle(color: cs.error, fontSize: 13),
          ),
        ],
        const SizedBox(height: Spacing.sm),
        Row(
          children: [
            Text(
              purchase.priceLabel,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const Spacer(),
            TextButton(
              onPressed: purchase.busy ? null : purchase.restore,
              child: const Text('購入を復元'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AiAccessCard extends StatelessWidget {
  const _AiAccessCard({required this.purchase});

  final PurchaseProvider purchase;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (purchase.aiAccess) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: cs.primary, size: 20),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI分析 利用可能',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                const Text('画像の手書きメモもAIが読み取ってTodoに変換します。'),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome, color: cs.primary, size: 20),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI画像認識',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: Spacing.xs),
                  const Text('手書きのメモやお便りもAIが読み取り、Todoを自動生成します。'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        _BenefitRow(icon: Icons.check, text: '手書き文字の読み取りに対応'),
        const SizedBox(height: Spacing.xs),
        _BenefitRow(icon: Icons.check, text: '¥190 買い切り／無制限に利用可能'),
        const SizedBox(height: Spacing.xs),
        _BenefitRow(icon: Icons.check, text: '広告除去とは別商品（両方購入で¥380）'),
        const SizedBox(height: Spacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: purchase.canPurchaseAi ? purchase.purchaseAi : null,
            icon: purchase.busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.workspace_premium),
            label: const Text('AI分析を購入する'),
          ),
        ),
        if (purchase.statusMessage != null) ...[
          const SizedBox(height: Spacing.sm),
          Text(
            purchase.statusMessage!,
            style: TextStyle(color: cs.error, fontSize: 13),
          ),
        ],
        const SizedBox(height: Spacing.sm),
        Row(
          children: [
            Text(
              purchase.aiPriceLabel,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const Spacer(),
          ],
        ),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: Spacing.sm),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
      trailing: const Icon(Icons.chevron_right),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }
}

String _fmt(int h, int m) =>
    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
