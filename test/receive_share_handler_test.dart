import 'dart:io';

import 'package:ashita_motsumono/src/app_state.dart';
import 'package:ashita_motsumono/src/repositories/drift_store.dart';
import 'package:ashita_motsumono/src/services/app_settings.dart';
import 'package:ashita_motsumono/src/services/document_intake_service.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';
import 'package:ashita_motsumono/src/services/receive_share_handler.dart';
import 'package:ashita_motsumono/src/services/share_file_staging_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService() : super(timezoneName: 'Asia/Tokyo');

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async => true;
}

class _RecordingDocumentIntakeService extends DocumentIntakeService {
  _RecordingDocumentIntakeService({
    required super.appState,
    required super.appSettings,
  });

  List<String>? importedImagePaths;
  String? imageSourceType;
  String? importedPdfPath;
  String? pdfSourceType;

  @override
  Future<IntakeResult> importImages({
    required List<String> sourcePaths,
    required String sourceType,
    IntakeProgressCallback? onProgress,
    IntakeCancellationToken? cancellationToken,
  }) async {
    importedImagePaths = List<String>.of(sourcePaths);
    imageSourceType = sourceType;
    return const IntakeError('recorded image import');
  }

  @override
  Future<IntakeResult> importPdf({
    required String sourcePath,
    required String sourceType,
    IntakeProgressCallback? onProgress,
    IntakeCancellationToken? cancellationToken,
  }) async {
    importedPdfPath = sourcePath;
    pdfSourceType = sourceType;
    return const IntakeError('recorded PDF import');
  }
}

class _PassthroughStagingService extends ShareFileStagingService {
  @override
  Future<T> withStagedFiles<T>({
    required List<SharedMediaFile> files,
    required Future<T> Function(List<StagedShareFile> files) action,
  }) {
    return action(
      files
          .map(
            (file) => StagedShareFile(
              path: file.path,
              type: file.type,
              mimeType: file.mimeType,
            ),
          )
          .toList(growable: false),
    );
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
  test('routes all shared images to one importImages call in order', () async {
    final (state, settings) = await _createState();
    addTearDown(() async {
      await state.close();
      state.dispose();
    });
    final intake = _RecordingDocumentIntakeService(
      appState: state,
      appSettings: settings,
    );
    final handler = ReceiveShareHandler(
      appState: state,
      appSettings: settings,
      documentIntakeService: intake,
      shareFileStagingService: _PassthroughStagingService(),
    );

    final result = await handler.process([
      SharedMediaFile(
        path: '/shared/front.jpg',
        type: SharedMediaType.image,
        mimeType: 'image/jpeg',
      ),
      SharedMediaFile(
        path: '/shared/back.png',
        type: SharedMediaType.image,
        mimeType: 'image/png',
      ),
    ]);

    expect(result, isA<ReceiveShareFailure>());
    expect(intake.importedImagePaths, [
      '/shared/front.jpg',
      '/shared/back.png',
    ]);
    expect(intake.imageSourceType, 'shared_image');
    expect(intake.importedPdfPath, isNull);
  });

  test('keeps a single image on the existing single-image flow', () async {
    final (state, settings) = await _createState();
    addTearDown(() async {
      await state.close();
      state.dispose();
    });
    final intake = _RecordingDocumentIntakeService(
      appState: state,
      appSettings: settings,
    );
    final handler = ReceiveShareHandler(
      appState: state,
      appSettings: settings,
      documentIntakeService: intake,
      shareFileStagingService: _PassthroughStagingService(),
    );

    final result = await handler.process([
      SharedMediaFile(
        path: '/missing/single.jpg',
        type: SharedMediaType.image,
        mimeType: 'image/jpeg',
      ),
    ]);

    expect(result, isA<ReceiveShareFailure>());
    expect(
      (result as ReceiveShareFailure).kind,
      ReceiveShareFailureKind.imageReadFailed,
    );
    expect(intake.importedImagePaths, isNull);
  });

  test('rejects a mixed image and PDF share before importing', () async {
    final (state, settings) = await _createState();
    addTearDown(() async {
      await state.close();
      state.dispose();
    });
    final intake = _RecordingDocumentIntakeService(
      appState: state,
      appSettings: settings,
    );
    final handler = ReceiveShareHandler(
      appState: state,
      appSettings: settings,
      documentIntakeService: intake,
      shareFileStagingService: _PassthroughStagingService(),
    );

    final result = await handler.process([
      SharedMediaFile(
        path: '/shared/front.jpg',
        type: SharedMediaType.image,
        mimeType: 'image/jpeg',
      ),
      SharedMediaFile(
        path: '/shared/notice.pdf',
        type: SharedMediaType.file,
        mimeType: 'application/pdf',
      ),
    ]);

    expect(result, isA<ReceiveShareFailure>());
    final failure = result as ReceiveShareFailure;
    expect(failure.message, '画像とPDFの同時共有は対応していません。');
    expect(failure.kind, ReceiveShareFailureKind.unsupportedFormat);
    expect(intake.importedImagePaths, isNull);
    expect(intake.importedPdfPath, isNull);
  });

  test('routes an ACTION_VIEW-like PDF by MIME type', () async {
    final (state, settings) = await _createState();
    addTearDown(() async {
      await state.close();
      state.dispose();
    });
    final intake = _RecordingDocumentIntakeService(
      appState: state,
      appSettings: settings,
    );
    final handler = ReceiveShareHandler(
      appState: state,
      appSettings: settings,
      documentIntakeService: intake,
      shareFileStagingService: _PassthroughStagingService(),
    );

    final result = await handler.process([
      SharedMediaFile(
        path: 'content://school.documents/document/42',
        type: SharedMediaType.file,
        mimeType: 'application/pdf',
      ),
    ]);

    expect(result, isA<ReceiveShareFailure>());
    expect(intake.importedPdfPath, 'content://school.documents/document/42');
    expect(intake.pdfSourceType, 'shared_pdf');
    expect(intake.importedImagePaths, isNull);
  });

  test('stages local shared files and removes the staging directory', () async {
    final root = await Directory.systemTemp.createTemp('share_staging_test_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final source = File('${root.path}/source.jpg');
    await source.writeAsBytes([1, 2, 3]);
    final service = ShareFileStagingService(
      temporaryDirectoryProvider: () async => root,
    );
    String? stagedPath;

    await service.withStagedFiles<void>(
      files: [
        SharedMediaFile(
          path: source.path,
          type: SharedMediaType.image,
          mimeType: 'image/jpeg',
        ),
      ],
      action: (files) async {
        stagedPath = files.single.path;
        expect(await File(stagedPath!).readAsBytes(), [1, 2, 3]);
      },
    );

    expect(stagedPath, isNotNull);
    expect(await File(stagedPath!).exists(), isFalse);
  });

  test('Android share contract declares multiple images and PDF view', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android.intent.action.SEND_MULTIPLE'));
    expect(manifest, contains('android.intent.action.VIEW'));
    expect(manifest, contains('android:mimeType="application/pdf"'));

    final mainActivity = File(
      'android/app/src/main/kotlin/com/ashita_motsumono/MainActivity.kt',
    ).readAsStringSync();
    expect(mainActivity, contains('contentResolver.openInputStream(uri)'));
    expect(mainActivity, contains('cacheDir.canonicalFile'));
    expect(mainActivity, contains('copyContentUriToStaging'));
  });
}
