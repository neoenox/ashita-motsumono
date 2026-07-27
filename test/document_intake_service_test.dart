import 'dart:convert';
import 'dart:io';

import 'package:ashita_motsumono/src/app_state.dart';
import 'package:ashita_motsumono/src/repositories/drift_store.dart';
import 'package:ashita_motsumono/src/services/app_settings.dart';
import 'package:ashita_motsumono/src/services/document_intake_service.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';
import 'package:ashita_motsumono/src/services/ocr_service.dart';
import 'package:ashita_motsumono/src/services/pdf_render_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService() : super(timezoneName: 'Asia/Tokyo');

  @override
  Future<void> initialize() async {}

  @override
  Future<void> requestPermissions() async {}
}

class _NeverRenderPdfService extends PdfRenderService {
  _NeverRenderPdfService() : super();

  var calls = 0;

  @override
  Future<List<RenderedPdfPage>> render({
    required File pdfFile,
    required Directory stagingDirectory,
    void Function(int current, int total)? onProgress,
  }) async {
    calls++;
    throw StateError('render should not be called');
  }
}

class _TwoPagePdfService extends PdfRenderService {
  _TwoPagePdfService({this.reportProgress = false}) : super();

  final bool reportProgress;

  @override
  Future<List<RenderedPdfPage>> render({
    required File pdfFile,
    required Directory stagingDirectory,
    void Function(int current, int total)? onProgress,
  }) async {
    await stagingDirectory.create(recursive: true);
    final first = File('${stagingDirectory.path}/page-0.jpg');
    final second = File('${stagingDirectory.path}/page-1.jpg');
    await first.writeAsBytes([1, 2, 3]);
    await second.writeAsBytes([4, 5, 6]);
    if (reportProgress) {
      onProgress?.call(1, 2);
      onProgress?.call(2, 2);
    }
    return [
      RenderedPdfPage(pageIndex: 0, imageFile: first),
      RenderedPdfPage(pageIndex: 1, imageFile: second),
    ];
  }
}

class _QueueOcrService extends OcrService {
  _QueueOcrService(this._results) : super();

  final List<String> _results;
  var _index = 0;

  @override
  Future<String> recognize(File imageFile) async {
    return _results[_index++];
  }
}

Future<(AppState, AppSettings)> _createState() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = await DriftStore.createInMemory();
  final state = AppState(
    store: store,
    notifications: _FakeNotificationService(),
  );
  await state.load();
  return (state, AppSettings(prefs));
}

void main() {
  test('returns duplicate before rendering an imported PDF', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'document_intake_duplicate_',
    );
    final (state, settings) = await _createState();
    addTearDown(() async {
      await state.close();
      state.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final source = File('${tempDir.path}/source.pdf');
    final bytes = utf8.encode('%PDF-1.4\n%%EOF');
    await source.writeAsBytes(bytes);
    final fingerprint = sha256.convert(bytes).toString();
    final existing = await state.addDocument(
      sourceType: 'pdf',
      sourceFingerprint: fingerprint,
    );
    final renderer = _NeverRenderPdfService();
    final service = DocumentIntakeService(
      appState: state,
      appSettings: settings,
      pdfRenderService: renderer,
      temporaryDirectoryProvider: () async => tempDir,
      documentsDirectoryProvider: () async => tempDir,
    );

    final result = await service.importPdf(
      sourcePath: source.path,
      sourceType: 'pdf',
    );

    expect(result, isA<IntakeDuplicate>());
    expect((result as IntakeDuplicate).existingDocumentId, existing.id);
    expect(renderer.calls, 0);
    expect(state.documents, hasLength(1));
  });

  test('persists empty OCR pages and returns no-candidates details', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'document_intake_empty_pages_',
    );
    final (state, settings) = await _createState();
    addTearDown(() async {
      await state.close();
      state.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final source = File('${tempDir.path}/source.pdf');
    await source.writeAsString('%PDF-1.4\n%%EOF');
    final service = DocumentIntakeService(
      appState: state,
      appSettings: settings,
      pdfRenderService: _TwoPagePdfService(),
      ocrService: _QueueOcrService(['', '']),
      temporaryDirectoryProvider: () async => tempDir,
      documentsDirectoryProvider: () async => tempDir,
    );

    final result = await service.importPdf(
      sourcePath: source.path,
      sourceType: 'pdf',
    );

    expect(result, isA<IntakeNoCandidates>());
    final noCandidates = result as IntakeNoCandidates;
    expect(noCandidates.ocrText, isEmpty);
    expect(noCandidates.document.pages, hasLength(2));
    expect(noCandidates.document.pages.map((page) => page.ocrText), ['', '']);
    expect(noCandidates.pageResults, hasLength(2));
    for (final page in noCandidates.pageResults) {
      expect(await page.imageFile.exists(), isTrue);
      expect(page.imageFile.path, contains('document_images'));
    }
    expect(state.documents.single.pages, hasLength(2));
  });

  test('reports PDF rendering and OCR progress separately', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'document_intake_progress_',
    );
    final (state, settings) = await _createState();
    addTearDown(() async {
      await state.close();
      state.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final source = File('${tempDir.path}/source.pdf');
    await source.writeAsString('%PDF-1.4\n%%EOF');
    final progress = <IntakeProgress>[];
    final service = DocumentIntakeService(
      appState: state,
      appSettings: settings,
      pdfRenderService: _TwoPagePdfService(reportProgress: true),
      ocrService: _QueueOcrService(['', '']),
      temporaryDirectoryProvider: () async => tempDir,
      documentsDirectoryProvider: () async => tempDir,
    );

    final result = await service.importPdf(
      sourcePath: source.path,
      sourceType: 'pdf',
      onProgress: progress.add,
    );

    expect(result, isA<IntakeNoCandidates>());
    expect(
      progress.map((entry) => entry.message),
      containsAllInOrder([
        'PDFを読み込み中...',
        '1/2ページを画像化中',
        '2/2ページを画像化中',
        '1/2ページを読み取り中',
        '2/2ページを読み取り中',
        '読み取り結果を保存中...',
      ]),
    );
  });

  test('cooperatively cancels multiple images before the next image', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'document_intake_cancel_',
    );
    final (state, settings) = await _createState();
    addTearDown(() async {
      await state.close();
      state.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final first = File('${tempDir.path}/first.jpg')..writeAsBytesSync([1]);
    final second = File('${tempDir.path}/second.jpg')..writeAsBytesSync([2]);
    final token = IntakeCancellationToken();
    final progress = <IntakeProgress>[];
    final service = DocumentIntakeService(
      appState: state,
      appSettings: settings,
      ocrService: _QueueOcrService(['first', 'second']),
      temporaryDirectoryProvider: () async => tempDir,
      documentsDirectoryProvider: () async => tempDir,
    );

    final result = await service.importImages(
      sourcePaths: [first.path, second.path],
      sourceType: 'gallery',
      cancellationToken: token,
      onProgress: (entry) {
        progress.add(entry);
        if (entry.stage == IntakeProgressStage.recognizingImages &&
            entry.current == 1) {
          token.cancel();
        }
      },
    );

    expect(result, isA<IntakeError>());
    expect(
      (result as IntakeError).message,
      DocumentIntakeService.cancelledMessage,
    );
    expect(
      progress.where(
        (entry) => entry.stage == IntakeProgressStage.recognizingImages,
      ),
      hasLength(1),
    );
    expect(state.documents, isEmpty);
  });

  test('removes copied images when database persistence fails', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'document_intake_rollback_',
    );
    final (state, settings) = await _createState();
    addTearDown(() async {
      state.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final source = File('${tempDir.path}/source.jpg');
    await source.writeAsBytes([1, 2, 3]);
    await state.close();
    final service = DocumentIntakeService(
      appState: state,
      appSettings: settings,
      ocrService: _QueueOcrService(['']),
      temporaryDirectoryProvider: () async => tempDir,
      documentsDirectoryProvider: () async => tempDir,
    );

    final result = await service.importImages(
      sourcePaths: [source.path],
      sourceType: 'image',
    );

    expect(result, isA<IntakeError>());
    final imagesDir = Directory('${tempDir.path}/document_images');
    final remaining = await imagesDir.exists()
        ? await imagesDir.list().toList()
        : const <FileSystemEntity>[];
    expect(remaining, isEmpty);
    expect(state.documents, isEmpty);
  });
}
