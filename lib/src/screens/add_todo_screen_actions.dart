part of 'add_todo_screen.dart';

extension _AddTodoScreenActions on _AddTodoScreenState {
  Future<void> _selectDueDate() async {
    final result = await pickDueDate(context, initial: _dueDate);
    if (!mounted || result == null) return;
    _update(() => _dueDate = result);
  }

  Future<void> _saveManual() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('タイトルを入力してください')));
      return;
    }
    final parsed = parseAmount(_amountController.text);
    if (!parsed.valid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('金額は数字で入力してください')));
      return;
    }

    final appState = context.read<AppState>();
    final settings = context.read<AppSettings>();
    final navigator = Navigator.of(context);
    final items = splitItems(_itemsController.text);
    final draft = ExtractionDraft(
      title: title,
      category: _category,
      dueDate: _dueDate,
      amount: parsed.amount,
      items: items,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );
    await appState.addTodoFromDraft(draft: draft, personId: _personId);
    await settings.addLearnedItemLabels(items);
    if (!mounted) return;
    navigator.pop();
  }

  Future<void> _extractFromText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final appState = context.read<AppState>();
    final settings = context.read<AppSettings>();
    final navigator = Navigator.of(context);
    final drafts = ExtractionService.extractMany(
      trimmed,
      learnedItemLabels: settings.learnedItemLabels,
    );
    if (drafts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テキストからTodo情報を抽出できませんでした。手入力で登録してください。')),
      );
      return;
    }
    final document = await appState.addDocument(
      sourceType: 'text',
      ocrText: trimmed,
    );
    if (!mounted) return;
    await navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            _reviewScreenFor(drafts: drafts, documentId: document.id),
      ),
    );
  }

  Future<void> _importFromClipboard() async {
    final text = await getClipboardText();
    if (text == null || text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('クリップボードにテキストがありません')));
      return;
    }
    _pasteController.text = text;
    await _extractFromText(text);
  }

  Future<void> _pickAndOcr(ImageSource source) async {
    _update(() => _busy = true);
    try {
      final service = _ocrPickService();
      final result = await service.pickAndProcess(source);
      if (result == null || !mounted) return;
      await _handleOcrPickResult(result);
    } on OcrException catch (error) {
      if (kDebugMode) debugPrint('OCR error: ${error.cause ?? error}');
      _showOcrError(error.message);
    } on Object catch (error) {
      if (kDebugMode) debugPrint('OCR error: $error');
      _showOcrError('読み取りに失敗しました。画像を撮り直すか、テキスト貼り付けを使ってください。');
    } finally {
      if (mounted) _update(() => _busy = false);
    }
  }

  Future<void> _pickImages() async {
    _update(() => _busy = true);
    try {
      final service = _ocrPickService();
      final picked = await service.pickGalleryImages();
      if (picked.isEmpty || !mounted) return;

      if (picked.length == 1) {
        final result = await service.processPickedImage(picked.single);
        if (!mounted) return;
        await _handleOcrPickResult(result, showNoCandidates: true);
        return;
      }

      final token = IntakeCancellationToken();
      _beginIntake(
        token,
        IntakeProgress(
          stage: IntakeProgressStage.recognizingImages,
          current: 1,
          total: picked.length,
        ),
      );
      final intake = DocumentIntakeService(
        appState: context.read<AppState>(),
        appSettings: context.read<AppSettings>(),
      );
      final result = await intake.importImages(
        sourcePaths: picked.map((file) => file.path).toList(growable: false),
        sourceType: 'gallery',
        cancellationToken: token,
        onProgress: _updateIntakeProgress,
      );
      if (!mounted || token.isCancelled) return;
      await _handleIntakeResult(result, duplicateLabel: 'この画像は取り込み済みです');
    } on OcrException catch (error) {
      if (kDebugMode) debugPrint('Image intake error: ${error.cause ?? error}');
      _showOcrError(error.message);
    } on Object catch (error) {
      if (kDebugMode) debugPrint('Image intake error: $error');
      _showOcrError('画像の取り込みに失敗しました。');
    } finally {
      _endIntake();
    }
  }

  Future<void> _pickPdf() async {
    _update(() => _busy = true);
    try {
      final file = await PdfPickService().pickPdf();
      if (file == null || !mounted) return;

      final token = IntakeCancellationToken();
      _beginIntake(
        token,
        const IntakeProgress(stage: IntakeProgressStage.loadingPdf),
      );
      final intake = DocumentIntakeService(
        appState: context.read<AppState>(),
        appSettings: context.read<AppSettings>(),
      );
      final result = await intake.importPdf(
        sourcePath: file.path,
        sourceType: 'pdf',
        cancellationToken: token,
        onProgress: _updateIntakeProgress,
      );
      if (!mounted || token.isCancelled) return;
      await _handleIntakeResult(result, duplicateLabel: 'このPDFは取り込み済みです');
    } on Object catch (error) {
      if (kDebugMode) debugPrint('PDF intake error: $error');
      _showOcrError('PDFの取り込みに失敗しました。');
    } finally {
      _endIntake();
    }
  }

  Future<void> _handleOcrPickResult(
    OcrPickResult result, {
    bool showNoCandidates = false,
  }) async {
    switch (result) {
      case OcrPickEmpty():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('文字を読み取れませんでした。撮り直すか、テキスト貼り付けを使ってください。'),
          ),
        );
      case OcrPickSuccess():
        if (result.drafts.isEmpty) {
          if (showNoCandidates) {
            await Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => NoCandidatesScreen(
                  documentId: result.document.id,
                  ocrText: result.document.ocrText ?? '',
                ),
              ),
            );
            return;
          }
          await context.read<AppState>().deleteDocument(result.document.id);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Todo情報を抽出できませんでした。手入力で登録してください。')),
          );
          return;
        }
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => _reviewScreenFor(
              drafts: result.drafts,
              documentId: result.document.id,
            ),
          ),
        );
    }
  }

  Future<void> _handleIntakeResult(
    IntakeResult result, {
    required String duplicateLabel,
  }) async {
    switch (result) {
      case IntakeSuccess():
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => _reviewScreenFor(
              drafts: result.drafts,
              documentId: result.document.id,
            ),
          ),
        );
      case IntakeDuplicate():
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('取り込み済み'),
            content: Text(duplicateLabel),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      case IntakeNoCandidates():
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => NoCandidatesScreen(
              documentId: result.document.id,
              ocrText: result.ocrText,
            ),
          ),
        );
      case IntakeEmpty():
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('文字を読み取れませんでした。')));
      case IntakeError():
        if (result.message == DocumentIntakeService.cancelledMessage) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  Future<void> _pickAndOcrWithAi() async {
    _update(() => _busy = true);
    try {
      final service = _ocrPickService();
      final proxyUrl = GeminiApiService.defaultInstance().proxyUrl ?? '';
      final result = await service.pickAndProcessWithAi(proxyUrl);
      if (result == null || !mounted) return;
      switch (result) {
        case OcrPickEmpty():
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Todo情報を抽出できませんでした。撮り直すか、テキスト貼り付けを使ってください。'),
            ),
          );
        case OcrPickSuccess(document: final doc, drafts: final drafts):
          final appState = context.read<AppState>();
          final document = await appState.addDocument(
            sourceType: 'camera',
            localImagePath: doc.localImagePath ?? '',
            ocrText: doc.ocrText,
          );
          if (!mounted) return;
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) =>
                  _reviewScreenFor(drafts: drafts, documentId: document.id),
            ),
          );
      }
    } on OcrException catch (error) {
      if (kDebugMode) debugPrint('Gemini error: ${error.cause ?? error}');
      _showOcrError(error.message);
    } on Object catch (error) {
      if (kDebugMode) debugPrint('Gemini error: $error');
      _showOcrError('AI解析に失敗しました。画像を撮り直すか、テキスト貼り付けを使ってください。');
    } finally {
      if (mounted) _update(() => _busy = false);
    }
  }

  OcrPickService _ocrPickService() {
    return OcrPickService(
      appState: context.read<AppState>(),
      appSettings: context.read<AppSettings>(),
    );
  }

  void _beginIntake(IntakeCancellationToken token, IntakeProgress progress) {
    if (!mounted) return;
    _update(() {
      _cancellationToken = token;
      _cancelRequested = false;
      _intakeProgress = progress;
    });
  }

  void _updateIntakeProgress(IntakeProgress progress) {
    if (!mounted) return;
    _update(() => _intakeProgress = progress);
  }

  void _cancelIntake() {
    final token = _cancellationToken;
    if (token == null || token.isCancelled) return;
    if (_intakeProgress?.stage == IntakeProgressStage.saving) return;
    token.cancel();
    _update(() => _cancelRequested = true);
  }

  void _endIntake() {
    if (!mounted) return;
    _update(() {
      _busy = false;
      _intakeProgress = null;
      _cancellationToken = null;
      _cancelRequested = false;
    });
  }

  void _showOcrError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 10)),
    );
  }

  Widget _reviewScreenFor({
    required List<ExtractionDraft> drafts,
    required String documentId,
  }) {
    if (drafts.length == 1) {
      return ReviewExtractionScreen(
        draft: drafts.single,
        documentId: documentId,
      );
    }
    return ReviewExtractionsScreen(drafts: drafts, documentId: documentId);
  }
}
