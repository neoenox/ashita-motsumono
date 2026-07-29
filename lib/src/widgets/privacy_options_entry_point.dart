import 'package:flutter/material.dart';

import '../services/consent_service.dart';

/// UMPが要求する場合だけ設定画面へ表示する、再同意用の恒久的な操作入口。
class PrivacyOptionsListTile extends StatefulWidget {
  const PrivacyOptionsListTile({super.key});

  @override
  State<PrivacyOptionsListTile> createState() => _PrivacyOptionsListTileState();
}

class _PrivacyOptionsListTileState extends State<PrivacyOptionsListTile> {
  bool _busy = false;

  Future<void> _showPrivacyOptions() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final error = await ConsentService.showPrivacyOptions();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error == null
                ? '広告のプライバシー設定を更新しました'
                : '広告のプライバシー設定を開けませんでした: ${error.message}',
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('広告のプライバシー設定を開けませんでした')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConsentService.privacyOptionsRequired,
      builder: (context, required, _) {
        if (!required) return const SizedBox.shrink();
        return ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('広告のプライバシー設定'),
          subtitle: const Text('広告に関する同意内容を確認・変更します'),
          trailing: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right, size: 16),
          contentPadding: EdgeInsets.zero,
          enabled: !_busy,
          onTap: _busy ? null : _showPrivacyOptions,
        );
      },
    );
  }
}
