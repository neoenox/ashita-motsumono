// lib/src/screens/review_extractions_screen.dart
// OCR抽出結果が複数ある場合の確認画面。候補を選んでまとめて登録する。
// Stitch デザインに合わせてカード+チェックのレイアウトに刷新。
// 関連: add_todo_screen.dart, review_extraction_screen.dart, app_state.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/entities.dart';
import '../services/app_settings.dart';
import '../theme/app_theme.dart';
import 'widgets/child_dropdown.dart';

class ReviewExtractionsScreen extends StatefulWidget {
  const ReviewExtractionsScreen({
    super.key,
    required this.drafts,
    this.documentId,
  });

  final List<ExtractionDraft> drafts;
  final String? documentId;

  @override
  State<ReviewExtractionsScreen> createState() =>
      _ReviewExtractionsScreenState();
}

class _ReviewExtractionsScreenState extends State<ReviewExtractionsScreen> {
  late final List<bool> _selected;
  late AppState _appState;
  String? _personId;
  bool _saved = false;
  bool _busy = false;

  int get _selectedCount => _selected.where((selected) => selected).length;

  @override
  void initState() {
    super.initState();
    _selected = List<bool>.filled(widget.drafts.length, true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = context.read<AppState>();
  }

  @override
  void dispose() {
    unawaited(_appState.tryDeleteDocumentOnDispose(
      saved: _saved,
      documentId: widget.documentId,
    ));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final children = context.watch<AppState>().children;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.drafts.length}件の候補を確認')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.md, Spacing.md, Spacing.md, 96,
        ),
        children: [
          // 人物選択
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 18, color: cs.primary),
                      const SizedBox(width: Spacing.sm),
                      Text('対象', style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: Spacing.sm),
                  ChildDropdown(
                    value: _personId,
                    children: children,
                    onChanged: (value) => setState(() => _personId = value),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),

          // Tips
          Card(
            color: cs.primaryContainer.withValues(alpha: 0.2),
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.tips_and_updates, size: 18, color: cs.primary),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      'OCRで読み取ったプリントから、日付と持ち物を自動で抽出しました。'
                      '漏れがないか最終チェックをお願いします。',
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),

          // 候補一覧
          ...List.generate(widget.drafts.length, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: i < widget.drafts.length - 1 ? Spacing.sm : 0),
              child: _DraftCard(
                draft: widget.drafts[i],
                selected: _selected[i],
                onChanged: (value) =>
                    setState(() => _selected[i] = value ?? false),
              ),
            );
          }),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: FilledButton.icon(
            onPressed: _busy ? null : _saveSelected,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_task),
            label: Text('$_selectedCount件を登録'),
          ),
        ),
      ),
    );
  }

  Future<void> _saveSelected() async {
    if (_selectedCount == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登録する候補を1件以上選んでください')));
      return;
    }

    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final settings = context.read<AppSettings>();
    final learnedLabels = <String>[];
    final selectedDrafts = <ExtractionDraft>[];

    for (var i = 0; i < widget.drafts.length; i++) {
      if (!_selected[i]) continue;
      selectedDrafts.add(widget.drafts[i]);
      learnedLabels.addAll(widget.drafts[i].items);
    }

    try {
      await _appState.addTodosFromDrafts(
        drafts: selectedDrafts,
        personId: _personId,
        documentId: widget.documentId,
      );
      await settings.addLearnedItemLabels(learnedLabels);
      _saved = true;
      if (!mounted) return;
      navigator.popUntil((route) => route.isFirst);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.draft,
    required this.selected,
    required this.onChanged,
  });

  final ExtractionDraft draft;
  final bool selected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final details = <String>[
      draft.category.label,
      if (draft.dueDate != null) _formatDate(draft.dueDate!),
      if (draft.amount != null) '${draft.amount}円',
      if (draft.items.isNotEmpty) draft.items.join('・'),
    ];

    return Card(
      color: selected ? cs.surface : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? cs.primary.withValues(alpha: 0.3) : cs.outlineVariant,
          width: selected ? 1.5 : 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!selected),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                onChanged: onChanged,
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(draft.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      details.join(' / '),
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) => '${date.year}/${date.month}/${date.day}';
