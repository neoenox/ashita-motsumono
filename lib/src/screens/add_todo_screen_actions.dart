part of 'add_todo_screen.dart';

extension _AddTodoScreenActions on _AddTodoScreenState {
  Future<void> _selectDueDate() async {
    final result = await pickDueDate(context, initial: _dueDate);
    if (!mounted || result == null) return;
    _update(() => _dueDate = result);
  }

  Future<void> _saveManual() async {
    if (_busy) return;
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
    _update(() => _busy = true);
    try {
      await appState.addTodoFromDraft(draft: draft, personId: _personId);
      await settings.addLearnedItemLabels(items);
      if (!mounted) return;
      navigator.pop();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('登録に失敗しました: $error')));
    } finally {
      if (mounted) _update(() => _busy = false);
    }
  }

  Future<void> _extractFromText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _busy) return;
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
    _update(() => _busy = true);
    try {
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
    } on Object catch (error) {
      if (kDebugMode) debugPrint('Text extraction error: $error');
      _showOcrError('テキストからTodo情報を抽出できませんでした。手入力で登録してください。');
    } finally {
      if (mounted) _update(() => _busy = false);
    }
  }

  Future<void> _importFromClipboard() async {
    final text = await getClipboardText();
    if (!mounted) return;
    if (text == null || text.trim().isEmpty) {
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
    final appState = context.read<AppState>();
    OcrPickSuccess? pendingSuccess;
    var handedOff = false;
    try {
      final result = await _ocrPickService().pickAndProcess(source);
      if (result == null) return;

      switch (result) {
        case OcrPickSuccess():
          pendingSuccess = result;
          if (!mounted) return;
          if (result.drafts.isEmpty) {
            await appState.deleteDocument(result.document.id);
            pendingSuccess = null;
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Todo情報を抽出できませんでした。手入力で登録してください。')),
            );
            return;
          }
          final navigation = Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => _reviewScreenFor(
                drafts: result.drafts,
                documentId: result.document.id,
              ),
            ),
          );
          handedOff = true;
          await navigation;
        case OcrPickEmpty():
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('文字を読み取れませんでした。撮り直すか、テキスト貼り付けを使ってください。'),
            ),
          );
        case OcrPickDuplicate():
          if (!mounted) return;
          await _showDuplicateDialog('この画像は取り込み済みです');
        case OcrPickNoCandidates():
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('候補が見つかりませんでした')));
        case OcrPickAiSuccess():
          // AI結果は_pickAndOcrWithAi経由でのみ返るため、この経路では発生しない。
          break;
        case OcrPickError():
          if (!mounted ||
              result.message == DocumentIntakeService.cancelledMessage) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result.message)));
      }
    } on OcrException catch (error) {
      if (kDebugMode) debugPrint('OCR error: ${error.cause ?? error}');
      _showOcrError(error.message);
    } on Object catch (error) {
      if (kDebugMode) debugPrint('OCR error: $error');
      _showOcrError('読み取りに失敗しました。画像を撮り直すか、テキスト貼り付けを使ってください。');
    } finally {
      if (!handedOff && pendingSuccess != null) {
        await _cleanupAbandonedOcrResult(appState, pendingSuccess);
      }
      if (mounted) _update(() => _busy = false);
    }
  }

  Future<void> _pickImages() async {
    _update(() => _busy = true);
    try {
      final service = _ocrPickService();
      final picked = await service.pickMultipleImageFiles();
      if (!mounted || picked.isEmpty) return;

      _update(() => _busy = false);
      final selected = picked.length == 1
          ? picked
          : await Navigator.of(context).push<List<XFile>>(
              MaterialPageRoute(
                builder: (_) => ImageIntakeReviewScreen(files: picked),
              ),
            );
      if (!mounted || selected == null || selected.isEmpty) return;

      final token = IntakeCancellationToken();
      _update(() {
        _busy = true;
        _cancellationToken = token;
      });
      final result = await service.processPickedImages(
        selected,
        cancellationToken: token,
        onProgress: (progress) {
          if (!mounted) return;
          if (_intakeProgress == null) {
            _beginIntake(token, progress);
          } else {
            _updateIntakeProgress(progress);
          }
        },
      );
      if (!mounted || token.isCancelled) return;
      await _handleOcrPickResult(result, showNoCandidates: true);
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
      final appState = context.read<AppState>();
      final appSettings = context.read<AppSettings>();
      final intake = DocumentIntakeService(
        appState: appState,
        appSettings: appSettings,
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
      case OcrPickDuplicate():
        await _showDuplicateDialog('この画像は取り込み済みです');
      case OcrPickNoCandidates():
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('候補が見つかりませんでした')));
      case OcrPickAiSuccess():
        break;
      case OcrPickError():
        if (result.message == DocumentIntakeService.cancelledMessage) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  Future<void> _handleIntakeResult(
    IntakeResult result, {
    required String duplicateLabel,
  }) async {
    switch (result) {
      case IntakeSuccess():
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _reviewScreenFor(
              drafts: result.drafts,
              documentId: result.document.id,
            ),
          ),
        );
      case IntakeDuplicate():
        await _showDuplicateDialog(duplicateLabel);
      case IntakeNoCandidates():
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('候補が見つかりませんでした')));
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

  Future<void> _showDuplicateDialog(String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('取り込み済み'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndOcrWithAi() async {
    _update(() => _busy = true);
    final appState = context.read<AppState>();
    String? pendingImagePath;
    String? persistedDocumentId;
    var handedOff = false;
    try {
      final service = _ocrPickService();
      final proxyUrl = GeminiApiService.defaultInstance().proxyUrl ?? '';
      final result = await service.pickAndProcessWithAi(proxyUrl);
      if (result == null) return;

      switch (result) {
        case OcrPickAiSuccess(imagePath: final imagePath):
          pendingImagePath = imagePath;
          if (!mounted) return;
          if (result.drafts.isEmpty) {
            await ImageFileService.deleteIfExists(imagePath);
            pendingImagePath = null;
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Todo情報を抽出できませんでした。撮り直すか、テキスト貼り付けを使ってください。'),
              ),
            );
            return;
          }
          final document = await appState.addDocument(
            sourceType: 'camera',
            localImagePath: imagePath,
            ocrText: result.ocrText,
          );
          persistedDocumentId = document.id;
          pendingImagePath = null;
          if (!mounted) return;
          final navigation = Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => _reviewScreenFor(
                drafts: result.drafts,
                documentId: document.id,
              ),
            ),
          );
          handedOff = true;
          await navigation;
        case OcrPickEmpty():
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Todo情報を抽出できませんでした。撮り直すか、テキスト貼り付けを使ってください。'),
            ),
          );
        case OcrPickDuplicate():
        case OcrPickNoCandidates():
        case OcrPickSuccess():
        case OcrPickError():
          // 通常OCR結果は_pickAndOcr経由でのみ返るため、この経路では発生しない。
          _showOcrError('AI解析に失敗しました。画像を撮り直すか、テキスト貼り付けを使ってください。');
      }
    } on OcrException catch (error) {
      if (kDebugMode) debugPrint('Gemini error: ${error.cause ?? error}');
      _showOcrError(error.message);
    } on Object catch (error) {
      if (kDebugMode) debugPrint('Gemini error: $error');
      _showOcrError('AI解析に失敗しました。画像を撮り直すか、テキスト貼り付けを使ってください。');
    } finally {
      if (!handedOff) {
        if (persistedDocumentId != null) {
          try {
            await appState.deleteDocument(persistedDocumentId);
          } on Object catch (error, stackTrace) {
            if (kDebugMode) {
              debugPrint(
                'Failed to clean up abandoned AI document: '
                '$error\n$stackTrace',
              );
            }
          }
        } else if (pendingImagePath != null) {
          final path = pendingImagePath;
          try {
            await ImageFileService.deleteIfExists(path);
          } on Object catch (error, stackTrace) {
            if (kDebugMode) {
              debugPrint(
                'Failed to clean up abandoned AI image: '
                '$error\n$stackTrace',
              );
            }
          }
        }
      }
      if (mounted) _update(() => _busy = false);
    }
  }

  Future<void> _cleanupAbandonedOcrResult(
    AppState appState,
    OcrPickSuccess result,
  ) async {
    try {
      await appState.deleteDocument(result.document.id);
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Failed to clean up abandoned OCR result: '
          '$error\n$stackTrace',
        );
      }
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
