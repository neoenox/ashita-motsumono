part of 'add_todo_screen.dart';

extension _AddTodoScreenLayout on _AddTodoScreenState {
  Widget _buildContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final children = context.watch<AppState>().children;
    return Scaffold(
      appBar: AppBar(title: const Text('追加')),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              Spacing.md,
              Spacing.md,
              Spacing.md,
              Spacing.md + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Card(
                color: cs.primaryContainer.withValues(alpha: 0.3),
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Row(
                    children: [
                      Icon(Icons.auto_fix_high, color: cs.primary, size: 24),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OCRアシスタント有効',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(color: cs.primary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '入力をラクに。お手元の資料やスクリーンショットからTodoを自動生成します。',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              Text(
                '画像・スクショから登録',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Spacing.sm),
              if (Platform.isWindows)
                const Padding(
                  padding: EdgeInsets.only(bottom: Spacing.sm),
                  child: Text(
                    'カメラ・OCRはWindows未対応です。テキスト貼り付けまたは手入力を使ってください。',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _IntakeButton(
                        onPressed: _busy
                            ? null
                            : () => _pickAndOcr(ImageSource.camera),
                        icon: Icons.photo_camera,
                        label: '写真を撮る',
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    Expanded(
                      child: _IntakeButton(
                        onPressed: _busy ? null : _pickImagesWithReview,
                        icon: Icons.add_photo_alternate_outlined,
                        label: '画像を選ぶ',
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    IconButton.outlined(
                      tooltip: 'PDFを選ぶ',
                      onPressed: _busy ? null : _pickPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                    ),
                  ],
                ),
              if (_busy && _intakeProgress == null)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.md),
                  child: LinearProgressIndicator(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              if (context.watch<PurchaseProvider>().aiAccess) ...[
                const SizedBox(height: Spacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => requestAiImageAnalysisWithDisclosure(
                            context,
                            startAnalysis: _pickAndOcrWithAi,
                          ),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('AIで解析（手書きも対応）'),
                  ),
                ),
              ],
              if (!_showManual) ...[
                const SizedBox(height: Spacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _update(() => _showManual = true),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('手動で入力する'),
                  ),
                ),
              ],
              const SizedBox(height: Spacing.lg),
              Text(
                'OCRテキストを貼り付けて抽出',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Spacing.sm),
              TextField(
                controller: _pasteController,
                decoration: const InputDecoration(
                  hintText: '園アプリやLINE連絡の文面を貼り付け',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 48),
                    child: Icon(Icons.content_paste, size: 20),
                  ),
                ),
                minLines: 4,
                maxLines: 8,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: Spacing.sm),
                child: Text(
                  'Powered by OCR Engine',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _extractFromText(_pasteController.text),
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('貼り付け文からTodo候補を作る'),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _importFromClipboard,
                      icon: const Icon(Icons.content_paste),
                      label: const Text('クリップボードから貼り付け'),
                    ),
                  ),
                ],
              ),
              if (_showManual) ...[
                const SizedBox(height: Spacing.lg),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: Spacing.sm),
                      child: Text('または', style: TextStyle(fontSize: 13)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                Text('手入力', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: Spacing.md),
                ChildDropdown(
                  value: _personId,
                  children: children,
                  onChanged: _busy
                      ? null
                      : (value) => _update(() => _personId = value),
                ),
                const SizedBox(height: Spacing.md),
                TextField(
                  controller: _titleController,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'タイトル',
                    hintText: '例：集金袋を提出',
                  ),
                ),
                const SizedBox(height: Spacing.md),
                DropdownButtonFormField<TodoCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: '種類'),
                  items: TodoCategory.values
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category.label),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (value) => _update(
                          () => _category = value ?? TodoCategory.other,
                        ),
                ),
                const SizedBox(height: Spacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _selectDueDate,
                        icon: const Icon(Icons.event),
                        label: Text(
                          _dueDate == null
                              ? '期限を選ぶ'
                              : '${_dueDate!.year}/${_dueDate!.month}/${_dueDate!.day}',
                        ),
                      ),
                    ),
                    if (_dueDate != null) ...[
                      const SizedBox(width: Spacing.sm),
                      IconButton.outlined(
                        tooltip: '期限をクリア',
                        onPressed: _busy
                            ? null
                            : () => _update(() => _dueDate = null),
                        icon: const Icon(Icons.clear),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: Spacing.md),
                TextField(
                  controller: _itemsController,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: '持ち物・チェック項目',
                    hintText: '水筒、体操着、集金袋',
                  ),
                ),
                const SizedBox(height: Spacing.md),
                TextField(
                  controller: _amountController,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: '金額',
                    hintText: '500',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: Spacing.md),
                TextField(
                  controller: _noteController,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'メモ'),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: Spacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _saveManual,
                    icon: const Icon(Icons.check),
                    label: const Text('登録'),
                  ),
                ),
              ],
              const SizedBox(height: Spacing.xl),
              Center(
                child: Text(
                  '"一日の始まりを、もっと軽やかに。"',
                  style: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (_intakeProgress != null)
            Positioned.fill(
              child: IntakeProgressOverlay(
                progress: _intakeProgress!,
                cancelling: _cancelRequested,
                onCancel: _cancelIntake,
              ),
            ),
        ],
      ),
    );
  }
}

class _IntakeButton extends StatelessWidget {
  const _IntakeButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 21),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
