// lib/src/screens/settings_screen.dart
// 通知時刻などをカスタマイズする設定画面。
// 関連: app_settings.dart, home_screen.dart, notification_service.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/app_settings.dart';

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
            subtitle: '前日の${_fmt(settings.previousNightHour, settings.previousNightMinute)}に通知',
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
            subtitle: '当日の${_fmt(settings.sameMorningHour, settings.sameMorningMinute)}に通知',
            onTap: () => _pickTime(
              context,
              settings.sameMorningHour,
              settings.sameMorningMinute,
              (h, m) => settings.setSameMorningTime(h, m),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '通知時刻を変更すると、登録済みの未完了Todo通知も新しい時刻で再予約されます。',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
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
      messenger.showSnackBar(
        SnackBar(content: Text('通知時刻の保存に失敗しました: $e')),
      );
    }
  }
}

String _fmt(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
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
