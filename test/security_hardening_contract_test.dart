import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI worker requires entitlement verification and rate limiting', () {
    final worker = File(
      'workers/gemini-proxy/src/index.ts',
    ).readAsStringSync();
    final wrangler = File(
      'workers/gemini-proxy/wrangler.toml',
    ).readAsStringSync();

    expect(worker, contains('/entitlements/verify'));
    expect(worker, contains("authorization.startsWith('Bearer ')"));
    expect(worker, contains('verifyGooglePlay'));
    expect(worker, contains('verifyAppStore'));
    expect(worker, contains('Image too large'));
    expect(worker, contains('ENTITLEMENT_SIGNING_SECRET'));
    expect(wrangler, contains('AI_RATE_LIMITER'));
    expect(wrangler, contains('ENTITLEMENT_RATE_LIMITER'));
  });

  test('Android backup excludes app data', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final rules = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(rules, contains('<exclude domain="database" path="." />'));
    expect(rules, contains('<exclude domain="sharedpref" path="." />'));
  });

  test('release pins Flutter and records both product IDs', () {
    final workflow = File('.github/workflows/ci.yml').readAsStringSync();
    final generator = File(
      'tool/generate_release_manifest.py',
    ).readAsStringSync();

    expect(workflow, contains("flutter-version: '3.44.0'"));
    expect(workflow, contains('IAP_AI_ACCESS_PRODUCT_ID'));
    expect(workflow, contains('--iap-ai-product-id'));
    expect(generator, contains('aiAccessProductId'));
  });

  test('AI client requires HTTPS and bounded images', () {
    final client = File(
      'lib/src/services/gemini_api_service.dart',
    ).readAsStringSync();
    final imageService = File(
      'lib/src/services/image_file_service.dart',
    ).readAsStringSync();

    expect(client, contains("base.scheme != 'https'"));
    expect(client, contains("'Authorization': 'Bearer"));
    expect(client, contains('ImageFileService.maxImageBytes'));
    expect(imageService, contains('5 * 1024 * 1024'));
  });
}
