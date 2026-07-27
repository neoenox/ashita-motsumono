// lib/src/screens/review_extractions_screen.dart
// OCR抽出結果が複数ある場合の確認画面。候補を編集・選択・一括修正してまとめて登録する。
// 関連: review_extraction_screen.dart, bulk_extraction_review_state.dart, app_state.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_navigation.dart';
import '../app_state.dart';
import '../models/bulk_extraction_review_state.dart';
import '../models/entities.dart';
import '../services/app_settings.dart';
import '../theme/app_theme.dart';
import 'review_extraction_screen.dart';
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
  late final BulkExtractionReviewState _reviewState;
  late AppState _appState;
  String? _personId;
  bool _saved = false;
  bool _busy = false;
  int get _selectedCount => _reviewState.selectedCount;

  @override
  void initState() {
    super.initState();
    _reviewState = BulkExtractionReviewState(widget.drafts);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = context.read<AppState>();
  }

  @override
  void dispose() {
    unawaited(
      _appState.tryDeleteDocumentOnDispose(
        saved: _saved,
        documentId: widget.documentId,
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final children = context.watch<AppState>().children;
    final hasSelection = _selectedCount > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_reviewState.length}件の候補を確認'),
        actions: [
          if (_reviewState.length > 0)
            IconButton(
              tooltip: _reviewState.allSelected ? 'すべて解除' : 'すべて選択',
              icon: Icon(
                _reviewState.allSelected
                    ? Icons.deselect
                    : Icons.select_all,
              ),
              onPressed: () {
                setState(() => _reviewState.toggleAll());
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.md,
          Spacing.md,
          Spacing.md,
          120,
        ),
        children: [
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
                      'OCRで読み取った候補を登録前に編集できます。'
                      '日付と持ち物に誤りがないか最終チェックしてください。',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          if (_reviewState.length == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
              child: Center(
                child: Text(
                  'すべての候補を削除しました',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            ...List.generate(_reviewState.length, (index) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < _reviewState.length - 1 ? Spacing.sm : 0,
                ),
                child: _DraftCard(
                  draft: _reviewState.draftAt(index),
                  selected: _reviewState.isSelected(index),
                  onChanged: (value) => setState(
                    () => _reviewState.setSelected(index, value ?? false),
                  ),
                  onEdit: () => _editDraft(index),
                ),
              );
            }),
          if (widget.drafts.any((d) => (d.rawText?.isNotEmpty ?? false)))
            Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  leading: Icon(Icons.text_snippet_outlined, size: 20, color: cs.primary),
                  title: Text(
                    'OCR元テキスト',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  initiallyExpanded: false,
                  childrenPadding: const EdgeInsets.fromLTRB(
                    Spacing.md + 20 + Spacing.sm,
                    0,
                    Spacing.md,
                    Spacing.md,
                  ),
                  children: [
                    Text(
                      widget.drafts.first.rawText ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_reviewState.length > 0 && hasSelection)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.sm),
                  child: Row(
                    children: [
                      if (_selectedCount < _reviewState.length) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showBatchFixDialog,
                            icon: const Icon(Icons.find_replace, size: 18),
                            label: const Text('一括修正'),
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.error,
                          ),
                          onPressed: _deleteSelected,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(
                            '削除($_selectedCount)',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              FilledButton.icon(
                onPressed: (_busy || _reviewState.length == 0)
                    ? null
                    : _saveSelected,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_task),
                label: Text(
                  _reviewState.length == 0
                      ? '登録する候補がありません'
                      : '$_selectedCount件を登録',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editDraft(int index) async {
    final edited = await pushAdaptive<ExtractionDraft>(
      context,
      (_) => ReviewExtractionScreen(
        draft: _reviewState.draftAt(index),
        editOnly: true,
      ),
    );
    if (!mounted || edited == null) return;
    setState(() => _reviewState.updateDraft(index, edited));
  }

  void _deleteSelected() {
    if (_selectedCount == 0) return;
    showAdaptiveDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('選択した候補を削除'),
        content: Text('$_selectedCount件の候補を削除しますか？\nこの操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed != true || !mounted) return;
      setState(() {
        _reviewState.removeSelected();
      });
    });
  }

  void _showBatchFixDialog() {
    final findController = TextEditingController();
    final replaceController = TextEditingController();
    var target = 'title';

    showAdaptiveDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('一括修正'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '全候補のタイトルから文字列を検索して置換します',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  DropdownButtonFormField<String>(
                    value: target,
                    decoration: const InputDecoration(
                      labelText: '対象フィールド',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'title', child: Text('タイトル')),
                      DropdownMenuItem(value: 'items', child: Text('持ち物')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => target = value);
                      }
                    },
                  ),
                  const SizedBox(height: Spacing.sm),
                  TextField(
                    controller: findController,
                    decoration: const InputDecoration(
                      labelText: '検索文字列',
                      border: OutlineInputBorder(),
                      hintText: '例: 水筒',
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  TextField(
                    controller: replaceController,
                    decoration: const InputDecoration(
                      labelText: '置換文字列',
                      border: OutlineInputBorder(),
                      hintText: '例: 水筒（水の代わり）',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    final find = findController.text.trim();
                    if (find.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('検索文字列を入力してください')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    _applyBatchFix(
                      find: find,
                      replace: replaceController.text,
                      target: target,
                    );
                  },
                  child: const Text('置換'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _applyBatchFix({
    required String find,
    required String replace,
    required String target,
  }) {
    var count = 0;
    setState(() {
      if (target == 'items') {
        count = _reviewState.batchReplaceItems(find, replace);
      } else {
        count = _reviewState.batchReplaceTitle(find, replace);
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count件の候補を修正しました')),
    );
  }

  Future<void> _saveSelected() async {
    if (_selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登録する候補を1件以上選んでください')),
      );
      return;
    }

    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final settings = context.read<AppSettings>();
    final selectedDrafts = _reviewState.selectedDrafts;

    try {
      await _appState.addTodosFromDrafts(
        drafts: selectedDrafts,
        personId: _personId,
        documentId: widget.documentId,
      );
      await settings.addLearnedItemLabels(_reviewState.selectedItemLabels);
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
    required this.onEdit,
  });

  final ExtractionDraft draft;
  final bool selected;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onEdit;

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
          color: selected
              ? cs.primary.withValues(alpha: 0.3)
              : cs.outlineVariant,
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
              Checkbox(value: selected, onChanged: onChanged),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.title,
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
              IconButton(
                key: ValueKey('edit-draft-${draft.title}'),
                tooltip: '候補を編集',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) => '${date.year}/${date.month}/${date.day}';
