// lib/src/services/document_intake_service.dart
// 画像・PDF・共有テキストの取り込みパイプラインを統一的に処理する。
// ファイル選択 → コピー → OCR → 候補抽出 → 永続化 を一貫して行う。
// 関連: pdf_render_service.dart, ocr_service.dart, extraction_service.dart, app_state.dart

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

final class IntakeSuccess extends IntakeResult {
  const IntakeSuccess({required this.document, required this.drafts});

  final DocumentRecord document;
  final List<ExtractionDraft> drafts;
}

final class IntakeDuplicate extends IntakeResult {
  const IntakeDuplicate({required this.existingDocumentId});

  final String existingDocumentId;
}

final class IntakeNoCandidates extends IntakeResult {
  IntakeNoCandidates({
    required this.document,
    required this.ocrText,
    required List<PageOcrResult> pageResults,
  }) : pageResults = List<PageOcrResult>.unmodifiable(pageResults);

  final DocumentRecord document;
  final String ocrText;
  final List<PageOcrResult> pageResults;
}

final class IntakeEmpty extends IntakeResult {
  const IntakeEmpty();
}

final class IntakeError extends IntakeResult {
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
    Future<Directory> Function()? temporaryDirectoryProvider,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _appState = appState,
       _appSettings = appSettings,
       _ocrService = ocrService ?? OcrService(),
       _pdfRenderService = pdfRenderService ?? PdfRenderService(),
       _imageFileService = imageFileService ?? ImageFileService(),
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final AppState _appState;
  final AppSettings _appSettings;
  final OcrService _ocrService;
  final PdfRenderService _pdfRenderService;
  final ImageFileService _imageFileService;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  final Future<Directory> Function() _documentsDirectoryProvider;

  Future<IntakeResult> importPdf({
    required String sourcePath,
    required String sourceType,
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      return await _runWithStaging((staging) async {
        final pdfFile = await _copyToStaging(File(sourcePath), staging);
        final fileHash = await _sha256(pdfFile);
        if (fileHash == null) {
          return const IntakeError('PDFファイルを読み込めませんでした。');
        }

        final existing = _findDocumentByFingerprint(fileHash);
        if (existing != null) {
          return IntakeDuplicate(existingDocumentId: existing.id);
        }

        final renderedPages = await _pdfRenderService.render(
          pdfFile: pdfFile,
          stagingDirectory: staging,
          onProgress: onProgress,
        );
        final pageResults = await _recognizePages(renderedPages);
        final combinedText = _combinePageText(pageResults, unitLabel: 'ページ');
        final drafts = _extractDrafts(combinedText);

        final duplicateBeforeSave = _findDocumentByFingerprint(fileHash);
        if (duplicateBeforeSave != null) {
          return IntakeDuplicate(existingDocumentId: duplicateBeforeSave.id);
        }

        final document = await _saveDocumentWithPages(
          sourceType: sourceType,
          sourceMimeType: 'application/pdf',
          sourceFingerprint: fileHash,
          ocrText: combinedText,
          pageResults: pageResults,
        );

        if (drafts.isEmpty) {
          return IntakeNoCandidates(
            document: document,
            ocrText: combinedText,
            pageResults: _pageResultsFromDocument(document),
          );
        }

        return IntakeSuccess(document: document, drafts: drafts);
      });
    } on PdfImportException catch (error) {
      return IntakeError(error.message);
    } on Object catch (error, stackTrace) {
      _debugLog('PDF import failed', error, stackTrace);
      return const IntakeError('PDFの取り込みに失敗しました。');
    }
  }

  Future<IntakeResult> importImages({
    required List<String> sourcePaths,
    required String sourceType,
  }) async {
    if (sourcePaths.isEmpty) {
      return const IntakeError('画像を読み込めませんでした。');
    }

    try {
      return await _runWithStaging((staging) async {
        final copiedImages = <File>[];
        for (final path in sourcePaths) {
          final copied = await _imageFileService.copyFromPath(
            path,
            destinationDirectory: staging,
          );
          copiedImages.add(copied);
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

        final combinedText = _combinePageText(pageResults, unitLabel: '枚目');
        final drafts = _extractDrafts(combinedText);
        final document = await _saveDocumentWithPages(
          sourceType: sourceType,
          sourceMimeType: 'image/*',
          ocrText: combinedText,
          pageResults: pageResults,
        );

        if (drafts.isEmpty) {
          return IntakeNoCandidates(
            document: document,
            ocrText: combinedText,
            pageResults: _pageResultsFromDocument(document),
          );
        }

        return IntakeSuccess(document: document, drafts: drafts);
      });
    } on Object catch (error, stackTrace) {
      _debugLog('Image import failed', error, stackTrace);
      return const IntakeError('画像の取り込みに失敗しました。');
    }
  }

  Future<IntakeResult> importText({
    required String text,
    required String sourceType,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const IntakeError('共有されたテキストが空です。');
    }

    final drafts = _extractDrafts(trimmed);
    try {
      final document = await _appState.addDocument(
        sourceType: sourceType,
        ocrText: trimmed,
      );
      if (drafts.isEmpty) {
        return IntakeNoCandidates(
          document: document,
          ocrText: trimmed,
          pageResults: const [],
        );
      }
      return IntakeSuccess(document: document, drafts: drafts);
    } on Object catch (error, stackTrace) {
      _debugLog('Text import failed', error, stackTrace);
      return const IntakeError('テキストの保存に失敗しました。');
    }
  }

  Future<List<PageOcrResult>> _recognizePages(
    List<RenderedPdfPage> renderedPages,
  ) async {
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
    return pageResults;
  }

  List<ExtractionDraft> _extractDrafts(String text) {
    if (text.trim().isEmpty) return const <ExtractionDraft>[];
    return ExtractionService.extractMany(
      text,
      learnedItemLabels: _appSettings.learnedItemLabels,
    );
  }

  String _combinePageText(
    List<PageOcrResult> pageResults, {
    required String unitLabel,
  }) {
    return pageResults
        .where((result) => result.text.isNotEmpty)
        .map(
          (result) =>
              '--- ${result.pageIndex + 1}$unitLabel ---\n${result.text}',
        )
        .join('\n\n');
  }

  DocumentRecord? _findDocumentByFingerprint(String fingerprint) {
    for (final document in _appState.documents) {
      if (document.sourceFingerprint == fingerprint) return document;
    }
    return null;
  }

  Future<DocumentRecord> _saveDocumentWithPages({
    required String sourceType,
    required String ocrText,
    required List<PageOcrResult> pageResults,
    String? sourceMimeType,
    String? sourceFingerprint,
  }) async {
    if (pageResults.isEmpty) {
      throw StateError('保存対象のページがありません。');
    }

    final imagesDir = await _createImagesDirectory();
    final documentId = const Uuid().v4();
    final now = DateTime.now();
    final pages = <DocumentPageRecord>[];
    final persistedPaths = <String>[];

    try {
      for (final pageResult in pageResults) {
        final extension = _supportedExtension(pageResult.imageFile.path);
        final destPath = p.join(
          imagesDir.path,
          '${documentId}_page_${pageResult.pageIndex.toString().padLeft(3, '0')}$extension',
        );
        await pageResult.imageFile.copy(destPath);
        persistedPaths.add(destPath);

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
    } on Object catch (error, stackTrace) {
      for (final path in persistedPaths.reversed) {
        await ImageFileService.deleteIfExists(path);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  List<PageOcrResult> _pageResultsFromDocument(DocumentRecord document) {
    final pages = [...document.pages]
      ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
    return pages
        .map(
          (page) => PageOcrResult(
            pageIndex: page.pageIndex,
            imageFile: File(page.localImagePath),
            text: page.ocrText,
          ),
        )
        .toList(growable: false);
  }

  String _supportedExtension(String path) {
    return switch (p.extension(path).toLowerCase()) {
      '.png' || '.jpg' || '.jpeg' || '.webp' => p.extension(path).toLowerCase(),
      _ => '.jpg',
    };
  }

  Future<File> _copyToStaging(File source, Directory staging) async {
    await staging.create(recursive: true);
    final extension = p.extension(source.path);
    final dest = File(p.join(staging.path, '${const Uuid().v4()}$extension'));
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
    final appDir = await _documentsDirectoryProvider();
    final imagesDir = Directory(p.join(appDir.path, 'document_images'));
    await imagesDir.create(recursive: true);
    return imagesDir;
  }

  Future<T> _runWithStaging<T>(
    Future<T> Function(Directory staging) action,
  ) async {
    final root = await _temporaryDirectoryProvider();
    final staging = Directory(p.join(root.path, 'intake_${const Uuid().v4()}'));
    await staging.create(recursive: true);

    try {
      return await action(staging);
    } finally {
      if (await staging.exists()) {
        try {
          await staging.delete(recursive: true);
        } on Object catch (error, stackTrace) {
          _debugLog('Staging cleanup failed', error, stackTrace);
        }
      }
    }
  }

  void _debugLog(String message, Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      debugPrint('DocumentIntakeService: $message: $error\n$stackTrace');
    }
  }
}

final class PageOcrResult {
  const PageOcrResult({
    required this.pageIndex,
    required this.imageFile,
    required this.text,
  });

  final int pageIndex;
  final File imageFile;
  final String text;
}
