// test/document_image_orphan_sweep_test.dart
// 起動時のオーファン画像スイープ（DB未参照ファイルの一掃）を検証する。
// 関連: lib/src/app_state_cleanup.dart, lib/src/services/document_image_cleaner.dart

import 'dart:io';

import 'package:ashita_motsumono/src/app_state.dart';
import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/repositories/drift_store.dart';
import 'package:ashita_motsumono/src/services/document_image_cleaner.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService() : super(timezoneName: 'Asia/Tokyo');

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> scheduleTodo(AppTodo todo) async {}

  @override
  Future<void> cancelTodo(String todoId) async {}
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory tempDir;
  late Directory imagesDir;
  late DriftStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('orphan_sweep_test_');
    imagesDir = Directory('${tempDir.path}/document_images');
    await imagesDir.create(recursive: true);
    store = await DriftStore.createInMemory();
  });

  tearDown(() async {
    await store.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  File writeFile(String name) {
    final file = File('${imagesDir.path}/$name');
    file.writeAsStringSync('image', flush: true);
    return file;
  }

  Future<AppState> createState() async {
    final state = AppState(
      store: store,
      notifications: _FakeNotificationService(),
      documentImageCleaner: DocumentImageCleaner(
        directoryProvider: () async => tempDir,
      ),
    );
    await state.load();
    return state;
  }

  test('deletes images not referenced by any document', () async {
    final kept = writeFile('kept.jpg');
    final orphan = writeFile('orphan.jpg');
    final state = await createState();

    await state.addDocument(sourceType: 'camera', localImagePath: kept.path);

    await state.deleteOrphanDocumentImages();

    expect(kept.existsSync(), isTrue);
    expect(orphan.existsSync(), isFalse);
  });

  test('keeps page images referenced by document pages', () async {
    final keptPage = writeFile('page-0.jpg');
    final orphan = writeFile('orphan.jpg');
    final state = await createState();

    final doc = await state.addDocument(
      sourceType: 'pdf',
      pages: [
        DocumentPageRecord(
          id: 'page-0',
          documentId: 'sweep-doc',
          pageIndex: 0,
          localImagePath: keptPage.path,
          ocrText: '',
        ),
      ],
    );
    expect(doc.pages.single.localImagePath, keptPage.path);

    await state.deleteOrphanDocumentImages();

    expect(keptPage.existsSync(), isTrue);
    expect(orphan.existsSync(), isFalse);
  });

  test('completes silently when the images directory is missing', () async {
    final state = await createState();
    await state.addDocument(sourceType: 'paste', ocrText: 'OCR');

    await imagesDir.delete(recursive: true);

    await state.deleteOrphanDocumentImages();

    expect(imagesDir.existsSync(), isFalse);
  });
}
