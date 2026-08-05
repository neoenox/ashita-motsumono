from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'workers/gemini-proxy/src/index.ts'
TEST = ROOT / 'test/worker_entitlement_token_contract_test.dart'

source = SOURCE.read_text(encoding='utf-8')
pattern = re.compile(
    r'async function verifyEntitlementToken\(.*?\n\}\n\nasync function signRs256Jwt',
    re.S,
)
replacement = '''async function verifyEntitlementToken(
  token: string,
  secret: string,
): Promise<EntitlementPayload | null> {
  try {
    if (!secret) return null;
    const parts = token.split('.');
    if (parts.length !== 3) return null;

    const header = decodeBase64UrlJson(parts[0]);
    if (
      !isRecord(header) ||
      header.alg !== 'HS256' ||
      header.typ !== 'JWT'
    ) {
      return null;
    }

    const key = await crypto.subtle.importKey(
      'raw',
      encoder.encode(secret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['verify'],
    );
    const valid = await crypto.subtle.verify(
      'HMAC',
      key,
      base64UrlDecode(parts[2]),
      encoder.encode(`${parts[0]}.${parts[1]}`),
    );
    if (!valid) return null;

    const payload = decodeBase64UrlJson(parts[1]);
    if (!isEntitlementPayload(payload)) return null;

    const now = Math.floor(Date.now() / 1000);
    if (
      payload.exp <= now ||
      payload.iat > now + 60 ||
      payload.exp <= payload.iat ||
      payload.exp - payload.iat > TOKEN_TTL_SECONDS
    ) {
      return null;
    }
    return payload;
  } catch {
    return null;
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isEntitlementPayload(value: unknown): value is EntitlementPayload {
  if (!isRecord(value)) return false;
  return (
    typeof value.productId === 'string' &&
    value.productId.length > 0 &&
    (value.platform === 'android' || value.platform === 'ios') &&
    typeof value.receiptHash === 'string' &&
    /^[a-f0-9]{64}$/.test(value.receiptHash) &&
    typeof value.iat === 'number' &&
    Number.isInteger(value.iat) &&
    typeof value.exp === 'number' &&
    Number.isInteger(value.exp)
  );
}

async function signRs256Jwt'''
updated, count = pattern.subn(replacement, source, count=1)
if count != 1:
    raise RuntimeError(f'expected one entitlement verifier, replaced {count}')
SOURCE.write_text(updated, encoding='utf-8')

TEST.write_text(
    """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('worker validates entitlement token structure and lifetime', () {
    final source = File(
      'workers/gemini-proxy/src/index.ts',
    ).readAsStringSync();

    expect(source, contains("header.alg !== 'HS256'"));
    expect(source, contains("header.typ !== 'JWT'"));
    expect(source, contains('function isEntitlementPayload'));
    expect(source, contains(r'/^[a-f0-9]{64}$/.test(value.receiptHash)'));
    expect(source, contains('payload.iat > now + 60'));
    expect(
      source,
      contains('payload.exp - payload.iat > TOKEN_TTL_SECONDS'),
    );
    expect(source, contains('} catch {\\n    return null;'));
  });
}
""",
    encoding='utf-8',
)
