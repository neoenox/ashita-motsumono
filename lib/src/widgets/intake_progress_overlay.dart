import 'package:flutter/material.dart';

import '../services/document_intake_service.dart';
import '../theme/app_theme.dart';

class IntakeProgressOverlay extends StatelessWidget {
  const IntakeProgressOverlay({
    super.key,
    required this.progress,
    required this.onCancel,
    this.cancelling = false,
  });

  final IntakeProgress progress;
  final VoidCallback? onCancel;
  final bool cancelling;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final message = cancelling ? 'キャンセルしています...' : progress.message;

    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: message,
            child: Card(
              margin: const EdgeInsets.all(Spacing.lg),
              child: Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        value: cancelling ? null : progress.fraction,
                      ),
                      const SizedBox(height: Spacing.md),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        '処理中はこの画面を閉じないでください。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      OutlinedButton.icon(
                        onPressed: cancelling ? null : onCancel,
                        icon: const Icon(Icons.close),
                        label: Text(cancelling ? 'キャンセル中' : 'キャンセル'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
