import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:ashita_motsumono/src/services/document_intake_service.dart';
import 'package:ashita_motsumono/src/services/ocr_pick_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 27);
  final document = DocumentRecord(
    id: 'document-1',
    sourceType: 'gallery',
    ocrText: '明日 水筒',
    createdAt: now,
    updatedAt: now,
  );

  test('maps successful intake to OcrPickSuccess', () {
    final result = ocrPickResultFromIntakeResult(
      IntakeSuccess(document: document, drafts: const []),
    );

    expect(result, isA<OcrPickSuccess>());
    expect((result as OcrPickSuccess).document, same(document));
  });

  test('maps duplicate intake to OcrPickDuplicate', () {
    final result = ocrPickResultFromIntakeResult(
      const IntakeDuplicate(existingDocumentId: 'existing-document'),
    );

    expect(result, isA<OcrPickDuplicate>());
    expect(
      (result as OcrPickDuplicate).existingDocumentId,
      'existing-document',
    );
  });

  test('maps no-candidate intake to OcrPickNoCandidates', () {
    final result = ocrPickResultFromIntakeResult(
      IntakeNoCandidates(
        document: document,
        ocrText: '読み取り結果',
        pageResults: const [],
      ),
    );

    expect(result, isA<OcrPickNoCandidates>());
    expect((result as OcrPickNoCandidates).ocrText, '読み取り結果');
  });

  test('maps empty and error intake results', () {
    expect(
      ocrPickResultFromIntakeResult(const IntakeEmpty()),
      isA<OcrPickEmpty>(),
    );

    final error = ocrPickResultFromIntakeResult(
      const IntakeError('画像の取り込みに失敗しました。'),
    );
    expect(error, isA<OcrPickError>());
    expect((error as OcrPickError).message, '画像の取り込みに失敗しました。');
  });
}
