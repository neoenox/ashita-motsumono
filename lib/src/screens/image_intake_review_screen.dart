// lib/src/screens/image_intake_review_screen.dart
// 複数画像をOCRへ渡す前に、ページ順の変更と不要画像の除外を行う。

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/image_intake_selection_state.dart';
import '../theme/app_theme.dart';

class ImageIntakeReviewScreen extends StatefulWidget {
  const ImageIntakeReviewScreen({super.key, required this.files});

  final List<XFile> files;

  @override
  State<ImageIntakeReviewScreen> createState() =>
      _ImageIntakeReviewScreenState();
}

class _ImageIntakeReviewScreenState extends State<ImageIntakeReviewScreen> {
  late final ImageIntakeSelectionState _selection;

  @override
  void initState() {
    super.initState();
    _selection = ImageIntakeSelectionState(widget.files);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('画像の順番を確認')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              Spacing.md,
              Spacing.md,
              Spacing.sm,
            ),
            child: Card(
              color: cs.primaryContainer.withValues(alpha: 0.25),
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.swap_vert, color: cs.primary),
                    const SizedBox(width: Spacing.sm),
                    const Expanded(
                      child: Text('上から順に読み取ります。右端のハンドルで並べ替え、不要な画像は削除してください。'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _selection.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.image_not_supported_outlined,
                            size: 44,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(height: Spacing.sm),
                          const Text('読み取る画像がありません'),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            '戻って画像を選び直してください。',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.md,
                      0,
                      Spacing.md,
                      96,
                    ),
                    itemCount: _selection.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() => _selection.reorder(oldIndex, newIndex));
                    },
                    itemBuilder: (context, index) {
                      final page = _selection.pageAt(index);
                      return Card(
                        key: ValueKey(page.id),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: cs.primaryContainer,
                            foregroundColor: cs.onPrimaryContainer,
                            child: Text('${index + 1}'),
                          ),
                          title: Text(
                            _displayName(page.file, page.originalIndex),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('読み取り順 ${index + 1}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                key: ValueKey('remove-${page.id}'),
                                tooltip: 'この画像を除外',
                                onPressed: () {
                                  setState(() => _selection.removeAt(index));
                                },
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: cs.error,
                                ),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Icon(Icons.drag_handle),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: FilledButton.icon(
            key: const ValueKey('confirm-image-intake-order'),
            onPressed: _selection.isEmpty
                ? null
                : () => Navigator.of(context).pop(_selection.files),
            icon: const Icon(Icons.document_scanner_outlined),
            label: Text(
              _selection.isEmpty
                  ? '画像を選び直してください'
                  : 'この順番で${_selection.length}枚を読み取る',
            ),
          ),
        ),
      ),
    );
  }

  String _displayName(XFile file, int originalIndex) {
    final name = file.name.trim();
    if (name.isNotEmpty) return name;
    final path = file.path.replaceAll('\\', '/');
    final slash = path.lastIndexOf('/');
    final basename = slash >= 0 ? path.substring(slash + 1) : path;
    return basename.isEmpty ? '画像${originalIndex + 1}' : basename;
  }
}
