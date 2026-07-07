// test/android_manifest_test.dart
// Android リリース Manifest のストア提出前提を検証する。
// 関連: android/app/src/main/AndroidManifest.xml, docs/STORE_LISTING_JA.md

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'release manifest declares permissions needed by production features',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android.permission.CAMERA'));
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      expect(manifest, contains('android.permission.INTERNET'));
      expect(manifest, contains('com.google.android.gms.ads.APPLICATION_ID'));
    },
  );

  test('release configuration script preserves production permissions', () {
    final script = File('tool/configure_android_release.sh').readAsStringSync();

    expect(script, contains('android.permission.CAMERA'));
    expect(script, contains('android.permission.POST_NOTIFICATIONS'));
    expect(script, contains('android.permission.INTERNET'));
  });
}
