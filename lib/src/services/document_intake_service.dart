// lib/src/services/document_intake_service.dart
// 画像・PDF・共有テキストの取り込みパイプラインを統一的に処理する。
// ファイル選択 → コピー → OCR → 候補抽出 → 永続化 を一貫して行う。
// 関連: pdf_render_service.dart, ocr_service.dart, extraction_service.dart, app_state.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../app_state.dart';
import '../models/entities.dart';
import 'app_settings.dart';
import 'extraction_service.dart';
import 'image_file_service.dart';
import 'ocr_service.dart';
import 'pdf_render_service.dart';

sealed class IntakeResult {
  const IntakeResult();
}

class IntakeSuccess extends IntakeResult {
  const IntakeSuccess({
    required this.document,
    required this.drafts,
  });

  final DocumentRecord document;
  final List<ExtractionDraft> drafts;
}

class IntakeEmpty extends IntakeResult {
  const IntakeEmpty();
}

class IntakeError extends IntakeResult {
  const IntakeError(this.message);

  final String message;
}

class DocumentIntakeService {
  DocumentIntakeService({
    required AppState appState,
    required AppSettings appSettings,
    OcrService? ocrService,
    PdfRenderService? pdfRenderService,
    ImageFileService? imageFileService,
  }) : _appState = appState,
       _appSettings = appSettings,
       _ocrService = ocrService ?? OcrService(),
       _pdfRenderService = pdfRenderService ?? PdfRenderService(),
       _imageFileService = imageFileService ?? ImageFileService();

  final AppState _appState;
  final AppSettings _appSettings;
  final OcrService _ocrService;
  final PdfRenderService _pdfRenderService;
  final ImageFileService _imageFileService;

  Future<IntakeResult> importPdf({
    required String sourcePath,
    required String sourceType,
    void Function(int current, int total)? onProgress,
  }) async {
    return _runWithStaging((staging) async {
      final pdfFile = await _copyToStaging(File(sourcePath), staging);

      final fileHash = await _sha256(pdfFile);
      if (fileHash == null) {
        return const IntakeError('PDFファイルを読み込めませんでした。');
      }

      final renderedPages = await _pdfRenderService.render(
        pdfFile: pdfFile,
        stagingDirectory: staging,
        onProgress: onProgress,
      );

      final pageResults = <PageOcrResult>[];
      for (final page in renderedPages) {
        final text = await _ocrService.recognize(page.imageFile);
        pageResults.add(
          PageOcrResult(
            pageIndex: page.pageIndex,
            imageFile: page.imageFile,
            text: text.trim(),
          ),
        );
      }

      final nonEmptyResults =
          pageResults.where((r) => r.text.isNotEmpty).toList();

      if (nonEmptyResults.isEmpty) {
        return const IntakeError(
          'PDFから文字が見つかりませんでした。'
          '文字がはっきり写ったPDFを選択してください。',
        );
      }

      final combinedText = nonEmptyResults
          .map(
            (r) =>
                '--- ${r.pageIndex + 1}ページ ---\n'
                '${r.text}',
          )
          .join('\n\n');

      final drafts = ExtractionService.extractMany(
        combinedText,
        learnedItemLabels: _appSettings.learnedItemLabels,
      );

      if (drafts.isEmpty) {
        return IntakeSuccess(
          document: DocumentRecord(
            id: '',
            sourceType: sourceType,
            ocrText: combinedText,
            sourceMimeType: 'application/pdf',
            sourceFingerprint: fileHash,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          drafts: drafts,
        );
      }

      final document = await _saveDocumentWithPages(
        sourceType: sourceType,
        sourceMimeType: 'application/pdf',
        sourceFingerprint: fileHash,
        ocrText: combinedText,
        pageResults: nonEmptyResults,
        staging: staging,
      );

      return IntakeSuccess(document: document, drafts: drafts);
    });
  }

  Future<IntakeResult> importImages({
    required List<String> sourcePaths,
    required String sourceType,
  }) async {
    return _runWithStaging((staging) async {
      final copiedImages = <File>[];
      for (final path in sourcePaths) {
        final copied = await _imageFileService.copyFromPath(path);
        copiedImages.add(copied);
      }

      if (copiedImages.isEmpty) {
        return const IntakeError('画像を読み込めませんでした。');
      }

      final pageResults = <PageOcrResult>[];
      for (var i = 0; i < copiedImages.length; i++) {
        final text = await _ocrService.recognize(copiedImages[i]);
        pageResults.add(
          PageOcrResult(
            pageIndex: i,
            imageFile: copiedImages[i],
            text: text.trim(),
          ),
        );
      }

      final nonEmptyResults =
          pageResults.where((r) => r.text.isNotEmpty).toList();

      if (nonEmptyResults.isEmpty) {
        return const IntakeError(
          '画像から文字が見つかりませんでした。',
        );
      }

      final combinedText = nonEmptyResults
          .map(
            (r) =>
                '--- ${r.pageIndex + 1}枚目 ---\n'
                '${r.text}',
          )
          .join('\n\n');

      final drafts = ExtractionService.extractMany(
        combinedText,
        learnedItemLabels: _appSettings.learnedItemLabels,
      );

      final document = await _saveDocumentWithPages(
        sourceType: sourceType,
        ocrText: combinedText,
        pageResults: nonEmptyResults,
        staging: staging,
      );

      return IntakeSuccess(document: document, drafts: drafts);
    });
  }

  Future<IntakeResult> importText({
    required String text,
    required String sourceType,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const IntakeError('共有されたテキストが空です。');
    }

    final drafts = ExtractionService.extractMany(
      trimmed,
      learnedItemLabels: _appSettings.learnedItemLabels,
    );

    try {
      final document = await _appState.addDocument(
        sourceType: sourceType,
        ocrText: trimmed,
      );

      return IntakeSuccess(document: document, drafts: drafts);
    } on Object catch (e) {
      return IntakeError('テキストの保存に失敗しました: $e');
    }
  }

  Future<DocumentRecord> _saveDocumentWithPages({
    required String sourceType,
    required String ocrText,
    required List<PageOcrResult> pageResults,
    required Directory staging,
    String? sourceMimeType,
    String? sourceFingerprint,
  }) async {
    final imagesDir = await _createImagesDirectory();

    final documentId = const Uuid().v4();
    final now = DateTime.now();
    final pages = <DocumentPageRecord>[];

    for (final pageResult in pageResults) {
      final destPath = p.join(
        imagesDir.path,
        '${documentId}_page_${pageResult.pageIndex.toString().padLeft(3, '0')}.jpg',
      );
      await pageResult.imageFile.copy(destPath);

      pages.add(
        DocumentPageRecord(
          id: '${documentId}_p${pageResult.pageIndex}',
          documentId: documentId,
          pageIndex: pageResult.pageIndex,
          localImagePath: destPath,
          ocrText: pageResult.text,
        ),
      );
    }

    final document = DocumentRecord(
      id: documentId,
      sourceType: sourceType,
      localImagePath: pages.first.localImagePath,
      ocrText: ocrText,
      sourceMimeType: sourceMimeType,
      sourceFingerprint: sourceFingerprint,
      createdAt: now,
      updatedAt: now,
      pages: pages,
    );

    await _appState.addDocumentRecord(document);

    return document;
  }

  Future<File> _copyToStaging(File source, Directory staging) async {
    final dest = File(p.join(staging.path, const Uuid().v4()));
    await source.copy(dest.path);
    return dest;
  }

  Future<String?> _sha256(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return sha256.convert(bytes).toString();
    } on Object {
      return null;
    }
  }

  Future<Directory> _createImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'document_images'));
    await imagesDir.create(recursive: true);
    return imagesDir;
  }

  Future<T> _runWithStaging<T>(
    Future<T> Function(Directory staging) action,
  ) async {
    final root = await getTemporaryDirectory();
    final staging = Directory(
      p.join(root.path, 'intake_${const Uuid().v4()}'),
    );

    try {
      return await action(staging);
    } finally {
      if (await staging.exists()) {
        try {
          await staging.delete(recursive: true);
        } on Object catch (e, s) {
          if (kDebugMode) {
            debugPrint('DocumentIntakeService: cleanup failed: $e\n$s');
          }
        }
      }
    }
  }
}

class PageOcrResult {
  const PageOcrResult({
    required this.pageIndex,
    required this.imageFile,
    required this.text,
  });

  final int pageIndex;
  final File imageFile;
  final String text;
}
