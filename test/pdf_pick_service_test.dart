import 'package:ashita_motsumono/src/services/pdf_pick_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns the selected PDF file', () async {
    final service = PdfPickService(picker: () async => '/tmp/print.pdf');

    final file = await service.pickPdf();

    expect(file?.path, '/tmp/print.pdf');
  });

  test('returns null when PDF selection is cancelled', () async {
    final service = PdfPickService(picker: () async => null);

    expect(await service.pickPdf(), isNull);
  });

  test('returns null when the picker returns an empty path', () async {
    final service = PdfPickService(picker: () async => '');

    expect(await service.pickPdf(), isNull);
  });
}
