// lib/src/services/pdf_render_service.dart
// PDFファイルを検証し、ページ単位でJPEG画像にレンダリングする。
// 1ページずつ逐次処理し、メモリ使用量を抑える。
// 関連: pdf_pick_service.dart, document_intake_service.dart, add_todo_screen.dart

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:uuid/uuid.dart';

class PdfImportException implements Exception {
  const PdfImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RenderedPdfPage {
  const RenderedPdfPage({
    required this.pageIndex,
    required this.imageFile,
  });

  final int pageIndex;
  final File imageFile;
}

class PdfImportLimits {
  const PdfImportLimits({
    this.maxBytes = 25 * 1024 * 1024,
    this.maxPages = 20,
    this.maxLongEdge = 2048,
    this.jpegQuality = 90,
    this.retryLongEdge = 1600,
  });

  final int maxBytes;
  final int maxPages;
  final double maxLongEdge;
  final int jpegQuality;
  final double retryLongEdge;
}

class PdfRenderService {
  PdfRenderService({PdfImportLimits? limits})
    : _limits = limits ?? const PdfImportLimits();

  final PdfImportLimits _limits;

  Future<List<RenderedPdfPage>> render({
    required File pdfFile,
    required Directory stagingDirectory,
    void Function(int current, int total)? onProgress,
  }) async {
    if (!await pdfFile.exists()) {
      throw const PdfImportException('PDFファイルが見つかりません。');
    }

    final fileSize = await pdfFile.length();
    if (fileSize <= 0) {
      throw const PdfImportException('PDFファイルが空です。');
    }
    if (fileSize > _limits.maxBytes) {
      throw PdfImportException(
        'PDFは${_formatBytes(_limits.maxBytes)}以下にしてください。',
      );
    }

    await _validatePdfHeader(pdfFile);
    await stagingDirectory.create(recursive: true);
    final stagingPath = stagingDirectory.path;

    final document = await PdfDocument.openFile(pdfFile.path);
    final renderedPages = <RenderedPdfPage>[];

    try {
      if (document.pagesCount <= 0) {
        throw const PdfImportException('PDFにページがありません。');
      }
      if (document.pagesCount > _limits.maxPages) {
        throw PdfImportException(
          'PDFは${_limits.maxPages}ページ以下にしてください。',
        );
      }

      for (var pageNumber = 1;
          pageNumber <= document.pagesCount;
          pageNumber++) {
        final page = await document.getPage(pageNumber);

        try {
          final rendered = await _renderPage(
            page,
            pageNumber,
            stagingPath: stagingPath,
          );

          if (rendered == null) {
            throw PdfImportException(
              '${pageNumber}ページ目を画像化できませんでした。',
            );
          }

          renderedPages.add(rendered);
          onProgress?.call(pageNumber, document.pagesCount);
        } finally {
          await page.close();
        }
      }

      return renderedPages;
    } finally {
      await document.close();
    }
  }

  Future<RenderedPdfPage?> _renderPage(
    PdfPage page,
    int pageNumber, {
    required String stagingPath,
  }) async {
    final longEdge = math.max(page.width, page.height);
    final scale = _limits.maxLongEdge / longEdge;

    final rendered = await page.render(
      width: (page.width * scale).ceilToDouble(),
      height: (page.height * scale).ceilToDouble(),
      format: PdfPageImageFormat.jpeg,
      backgroundColor: '#FFFFFF',
      quality: _limits.jpegQuality,
    );

    if (rendered == null || rendered.bytes.isEmpty) {
      if (scale > 0.9) {
        final retryScale = _limits.retryLongEdge / longEdge;
        if (retryScale < scale) {
          final retry = await page.render(
            width: (page.width * retryScale).ceilToDouble(),
            height: (page.height * retryScale).ceilToDouble(),
            format: PdfPageImageFormat.jpeg,
            backgroundColor: '#FFFFFF',
            quality: _limits.jpegQuality,
          );
          if (retry != null && retry.bytes.isNotEmpty) {
            return _savePageImage(
              retry.bytes,
              pageNumber,
              stagingDirectoryPath: stagingPath,
            );
          }
        }
      }
      return null;
    }

    return _savePageImage(
      rendered.bytes,
      pageNumber,
      stagingDirectoryPath: stagingPath,
    );
  }

  Future<RenderedPdfPage> _savePageImage(
    Uint8List bytes,
    int pageNumber,
    {required String stagingDirectoryPath,
  }) async {
    final output = File(
      p.join(
        stagingDirectoryPath,
        'pdf_page_${pageNumber.toString().padLeft(3, '0')}_${const Uuid().v4()}.jpg',
      ),
    );
    await output.writeAsBytes(bytes, flush: true);
    return RenderedPdfPage(pageIndex: pageNumber - 1, imageFile: output);
  }

  Future<void> _validatePdfHeader(File file) async {
    final handle = await file.open();
    try {
      final header = await handle.read(5);
      final valid = header.length == 5 &&
          header[0] == 0x25 &&
          header[1] == 0x50 &&
          header[2] == 0x44 &&
          header[3] == 0x46 &&
          header[4] == 0x2D;

      if (!valid) {
        throw const PdfImportException(
          '選択されたファイルは有効なPDFではありません。',
        );
      }
    } finally {
      await handle.close();
    }
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${bytes ~/ (1024 * 1024)}MB';
    }
    return '${bytes ~/ 1024}KB';
  }
}
