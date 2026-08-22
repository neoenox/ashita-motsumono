part of 'receive_share_handler.dart';

extension _ReceiveShareSources on ReceiveShareHandler {
  bool _isPdfPath(String path) {
    final uriPath = Uri.tryParse(path)?.path ?? path;
    return uriPath.toLowerCase().endsWith('.pdf');
  }

  bool _isPdfFile(SharedMediaFile file) =>
      file.mimeType?.toLowerCase() == 'application/pdf' ||
      _isPdfPath(file.path);

  bool _isImageFile(SharedMediaFile file) =>
      !_isPdfFile(file) &&
      (file.type == SharedMediaType.image ||
          (file.mimeType?.toLowerCase().startsWith('image/') ?? false));

  bool _isTextFile(SharedMediaFile file) =>
      file.type == SharedMediaType.text ||
      (file.mimeType?.toLowerCase().startsWith('text/') ?? false);

  Future<ReceiveShareResult> _processPdf(SharedMediaFile file) async {
    try {
      return await _shareFileStagingService.withStagedFiles(
        files: [file],
        action: (stagedFiles) async {
          final intake = await _documentIntakeService.importPdf(
            sourcePath: stagedFiles.single.path,
            sourceType: 'shared_pdf',
          );
          return _mapPdfIntakeResult(intake);
        },
      );
    } on ShareFileStagingException catch (error) {
      return ReceiveShareFailure(
        error.message,
        kind: ReceiveShareFailureKind.pdfImportFailed,
      );
    }
  }

  Future<ReceiveShareResult> _processMultipleImages(
    List<SharedMediaFile> files,
  ) async {
    try {
      return await _shareFileStagingService.withStagedFiles(
        files: files,
        action: (stagedFiles) async {
          final intake = await _documentIntakeService.importImages(
            sourcePaths: stagedFiles
                .map((file) => file.path)
                .toList(growable: false),
            sourceType: 'shared_image',
          );
          return _mapImageIntakeResult(intake);
        },
      );
    } on ShareFileStagingException catch (error) {
      return ReceiveShareFailure(
        error.message,
        kind: ReceiveShareFailureKind.imageReadFailed,
      );
    }
  }

  ReceiveShareResult _mapPdfIntakeResult(IntakeResult intake) {
    return switch (intake) {
      IntakeSuccess() => ReceiveShareSuccess(
        drafts: intake.drafts,
        documentId: intake.document.id,
      ),
      IntakeDuplicate() => const ReceiveShareFailure(
        'このPDFは既に取り込み済みです。',
        kind: ReceiveShareFailureKind.duplicate,
      ),
      IntakeNoCandidates() => ReceiveShareSuccess(
        drafts: const [],
        documentId: intake.document.id,
        ocrText: intake.ocrText,
      ),
      IntakeEmpty() => const ReceiveShareFailure(
        'PDFから文字が見つかりませんでした。',
        kind: ReceiveShareFailureKind.ocrEmpty,
      ),
      IntakeError() => ReceiveShareFailure(
        intake.message,
        kind: ReceiveShareFailureKind.pdfImportFailed,
      ),
    };
  }

  ReceiveShareResult _mapImageIntakeResult(IntakeResult intake) {
    return switch (intake) {
      IntakeSuccess() => ReceiveShareSuccess(
        drafts: intake.drafts,
        documentId: intake.document.id,
      ),
      IntakeDuplicate() => const ReceiveShareFailure(
        'この画像は既に取り込み済みです。',
        kind: ReceiveShareFailureKind.duplicate,
      ),
      IntakeNoCandidates() => ReceiveShareSuccess(
        drafts: const [],
        documentId: intake.document.id,
        ocrText: intake.ocrText,
      ),
      IntakeEmpty() => const ReceiveShareFailure(
        '画像から文字が見つかりませんでした。',
        kind: ReceiveShareFailureKind.ocrEmpty,
      ),
      IntakeError() => ReceiveShareFailure(
        intake.message,
        kind: ReceiveShareFailureKind.imageReadFailed,
      ),
    };
  }

  Future<ReceiveShareResult> _processText(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) {
      return const ReceiveShareFailure(
        '共有されたテキストが空です。',
        kind: ReceiveShareFailureKind.textEmpty,
      );
    }

    final fingerprint = TextFingerprint.calculate(text);
    if (_isCompleted(fingerprint)) {
      return const ReceiveShareFailure(
        'このテキストは既に取り込み済みです。',
        kind: ReceiveShareFailureKind.duplicate,
      );
    }

    final drafts = ExtractionService.extractMany(
      text,
      learnedItemLabels: _appSettings.learnedItemLabels,
    );
    if (drafts.isEmpty) {
      return const ReceiveShareFailure(
        '共有テキストから日付や持ち物を抽出できませんでした。',
        kind: ReceiveShareFailureKind.extractionEmpty,
      );
    }

    try {
      final document = await _appState.addDocument(
        sourceType: 'shared_text',
        ocrText: text,
      );
      _recordCompleted(fingerprint);
      return ReceiveShareSuccess(drafts: drafts, documentId: document.id);
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('ReceiveShareHandler: save failed: $error\n$stackTrace');
      }
      return const ReceiveShareFailure(
        'テキストの保存に失敗しました。',
        kind: ReceiveShareFailureKind.saveFailed,
      );
    }
  }

  Future<ReceiveShareResult> _processImage(SharedMediaFile file) async {
    final source = XFile(file.path);

    int sourceLength;
    try {
      sourceLength = await source.length();
    } on Object {
      return const ReceiveShareFailure(
        '画像を読み込めませんでした。対応形式（JPEG/PNG）か確認してください。',
        kind: ReceiveShareFailureKind.imageReadFailed,
      );
    }

    if (sourceLength <= 0) {
      return const ReceiveShareFailure(
        '共有された画像が空です。',
        kind: ReceiveShareFailureKind.imageReadFailed,
      );
    }
    if (sourceLength > ReceiveShareHandler._maxImageBytes) {
      return const ReceiveShareFailure(
        '画像サイズが大きすぎます（上限5MB）。縮小してから共有してください。',
        kind: ReceiveShareFailureKind.imageTooLarge,
      );
    }

    try {
      return await _shareFileStagingService.withStagedFiles(
        files: [file],
        action: (stagedFiles) => _importStagedImage(stagedFiles.single),
      );
    } on ShareFileStagingException {
      return const ReceiveShareFailure(
        '画像の保存に失敗しました。',
        kind: ReceiveShareFailureKind.saveFailed,
      );
    }
  }

  Future<ReceiveShareResult> _importStagedImage(
    StagedShareFile stagedFile,
  ) async {
    File copiedImage;
    try {
      copiedImage = await _imageFileService.copyFromXFile(
        XFile(stagedFile.path),
      );
    } on Object {
      return const ReceiveShareFailure(
        '画像の保存に失敗しました。',
        kind: ReceiveShareFailureKind.saveFailed,
      );
    }

    try {
      final ocrText = await _ocrService.recognize(copiedImage);
      if (ocrText.trim().isEmpty) {
        await ImageFileService.deleteIfExists(copiedImage.path);
        return const ReceiveShareFailure(
          '画像から文字が見つかりませんでした。文字がはっきり写った画像を共有してください。',
          kind: ReceiveShareFailureKind.ocrEmpty,
        );
      }

      final ocrFingerprint = TextFingerprint.calculate(ocrText);
      if (_isCompleted(ocrFingerprint)) {
        await ImageFileService.deleteIfExists(copiedImage.path);
        return const ReceiveShareFailure(
          'この画像は既に取り込み済みです。',
          kind: ReceiveShareFailureKind.duplicate,
        );
      }

      final drafts = ExtractionService.extractMany(
        ocrText,
        learnedItemLabels: _appSettings.learnedItemLabels,
      );
      if (drafts.isEmpty) {
        await ImageFileService.deleteIfExists(copiedImage.path);
        return const ReceiveShareFailure(
          '画像からTodo情報を抽出できませんでした。日付や持ち物が含まれているか確認してください。',
          kind: ReceiveShareFailureKind.extractionEmpty,
        );
      }

      try {
        final document = await _appState.addDocument(
          sourceType: 'shared_image',
          localImagePath: copiedImage.path,
          ocrText: ocrText,
        );
        _recordCompleted(ocrFingerprint);
        return ReceiveShareSuccess(drafts: drafts, documentId: document.id);
      } on Object catch (error, stackTrace) {
        await ImageFileService.deleteIfExists(copiedImage.path);
        if (kDebugMode) {
          debugPrint('ReceiveShareHandler: save failed: $error\n$stackTrace');
        }
        return const ReceiveShareFailure(
          '画像の保存に失敗しました。',
          kind: ReceiveShareFailureKind.saveFailed,
        );
      }
    } on Object {
      await ImageFileService.deleteIfExists(copiedImage.path);
      rethrow;
    }
  }
}
