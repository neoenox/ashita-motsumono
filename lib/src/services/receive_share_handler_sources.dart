part of 'receive_share_handler.dart';

extension _ReceiveShareSources on ReceiveShareHandler {
  bool _isPdfPath(String path) => path.toLowerCase().endsWith('.pdf');

  Future<ReceiveShareResult> _processPdf(String sourcePath) async {
    final intake = await _documentIntakeService.importPdf(
      sourcePath: sourcePath,
      sourceType: 'shared_pdf',
    );

    switch (intake) {
      case IntakeSuccess():
        return ReceiveShareSuccess(
          drafts: intake.drafts,
          documentId: intake.document.id,
        );
      case IntakeDuplicate():
        return const ReceiveShareFailure(
          'このPDFは既に取り込み済みです。',
          kind: ReceiveShareFailureKind.duplicate,
        );
      case IntakeNoCandidates():
        return ReceiveShareSuccess(
          drafts: const [],
          documentId: intake.document.id,
          ocrText: intake.ocrText,
        );
      case IntakeEmpty():
        return const ReceiveShareFailure(
          'PDFから文字が見つかりませんでした。',
          kind: ReceiveShareFailureKind.ocrEmpty,
        );
      case IntakeError():
        return ReceiveShareFailure(
          intake.message,
          kind: ReceiveShareFailureKind.pdfImportFailed,
        );
    }
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

  Future<ReceiveShareResult> _processImage(
    String sourcePath, {
    String? mimeType,
  }) async {
    final source = XFile(sourcePath, mimeType: mimeType);

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

    File copiedImage;
    try {
      copiedImage = await _imageFileService.copyFromXFile(source);
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
