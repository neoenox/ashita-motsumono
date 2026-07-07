// lib/src/screens/settings_screen.dart
// 通知時刻などをカスタマイズする設定画面。
// 関連: app_settings.dart, home_screen.dart, notification_service.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/app_settings.dart';
import '../services/purchase_provider.dart';
import '../theme/app_theme.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          const _SectionHeader('通知時刻'),
          _TimeTile(
            icon: Icons.nightlight_round,
            title: '前日（夜）',
            subtitle:
                '前日の${_fmt(settings.previousNightHour, settings.previousNightMinute)}に通知',
            onTap: () => _pickTime(
              context,
              settings.previousNightHour,
              settings.previousNightMinute,
              (h, m) => settings.setPreviousNightTime(h, m),
            ),
          ),
          _TimeTile(
            icon: Icons.wb_sunny_outlined,
            title: '当日（朝）',
            subtitle:
                '当日の${_fmt(settings.sameMorningHour, settings.sameMorningMinute)}に通知',
            onTap: () => _pickTime(
              context,
              settings.sameMorningHour,
              settings.sameMorningMinute,
              (h, m) => settings.setSameMorningTime(h, m),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(Spacing.md),
            child: Text(
              '通知時刻を変更すると、登録済みの未完了Todo通知も新しい時刻で再予約されます。',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          const Divider(),
          const _SectionHeader('サポーター'),
          Consumer<PurchaseProvider>(
            builder: (context, purchase, _) {
              return _SupporterCard(purchase: purchase);
            },
          ),
          const Divider(),
          const _SectionHeader('データ管理'),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('登録データをすべて削除'),
            subtitle: const Text('人物、Todo、読み取り履歴、保存画像をこの端末から削除します'),
            onTap: () => _confirmClearAllData(context),
          ),
          const SizedBox(height: Spacing.lg),
        ],
      ),
    );
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
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('登録データを削除しました')));
    } on Object catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('登録データの削除に失敗しました: $e')));
    }
  }
}

String _fmt(int h, int m) =>
    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

class _SupporterCard extends StatelessWidget {
  const _SupporterCard({required this.purchase});

  final PurchaseProvider purchase;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (purchase.adRemoved) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        child: Card(
          color: cs.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, color: cs.primary),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'サポーター登録済み',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: Spacing.xs),
                      const Text('広告なしで使えます。ご購入ありがとうございます。'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      child: Card(
        color: cs.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    foregroundColor: cs.primary,
                    child: const Icon(Icons.favorite),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '買い切りサポーター',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: Spacing.xs),
                        const Text('広告を消して、朝の支度確認に集中できます。'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              const _SupporterBenefit(
                icon: Icons.block,
                text: '広告なしでホーム画面を広く使える',
              ),
              const _SupporterBenefit(
                icon: Icons.lock_outline,
                text: 'ログイン不要・端末内保存の方針はそのまま',
              ),
              const _SupporterBenefit(
                icon: Icons.auto_awesome,
                text: '今後の改善を買い切りで応援',
              ),
              const SizedBox(height: Spacing.md),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: purchase.busy ? null : purchase.purchase,
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
                ],
              ),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  Text(
                    purchase.priceLabel,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: purchase.busy ? null : purchase.restore,
                    child: const Text('購入を復元'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupporterBenefit extends StatelessWidget {
  const _SupporterBenefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: Spacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.lg, Spacing.md, Spacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
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
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
