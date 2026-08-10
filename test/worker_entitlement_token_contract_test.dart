import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('worker validates entitlement token structure and lifetime', () {
    final source = File(
      'workers/gemini-proxy/src/index.ts',
    ).readAsStringSync().replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    expect(source, contains("header.alg !== 'HS256'"));
    expect(source, contains("header.typ !== 'JWT'"));
    expect(source, contains('function isEntitlementPayload'));
    expect(source, contains(r'/^[a-f0-9]{64}$/.test(value.receiptHash)'));
    expect(source, contains('payload.iat > now + 60'));
    expect(source, contains('payload.exp - payload.iat > TOKEN_TTL_SECONDS'));
    expect(source, contains('} catch {\n    return null;'));
  });
}
