import 'package:flutter/material.dart';

import '../services/consent_service.dart';

/// UMPが要求する場合だけ表示する、再同意用の恒久的な操作入口。
class PrivacyOptionsEntryPoint extends StatefulWidget {
  const PrivacyOptionsEntryPoint({super.key});

  @override
  State<PrivacyOptionsEntryPoint> createState() =>
      _PrivacyOptionsEntryPointState();
}

class _PrivacyOptionsEntryPointState extends State<PrivacyOptionsEntryPoint> {
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
    return Align(
      alignment: Alignment.bottomRight,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        child: ValueListenableBuilder<bool>(
          valueListenable: ConsentService.privacyOptionsRequired,
          builder: (context, required, _) {
            if (!required) return const SizedBox.shrink();
            return FloatingActionButton.extended(
              heroTag: 'ump-privacy-options',
              onPressed: _busy ? null : _showPrivacyOptions,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.privacy_tip_outlined),
              label: const Text('広告の設定'),
              tooltip: '広告のプライバシー設定を変更',
            );
          },
        ),
      ),
    );
  }
}
