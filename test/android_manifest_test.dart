// test/android_manifest_test.dart
// Android リリース Manifest のストア提出前提を検証する。
// 関連: android/app/src/main/AndroidManifest.xml, docs/STORE_LISTING_JA.md

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _pythonExecutable() {
  for (final command in ['python', 'python3']) {
    try {
      final result = Process.runSync(command, ['--version']);
      if (result.exitCode == 0) return command;
    } on ProcessException {
      // Try the next conventional executable name.
    }
  }
  throw StateError('Python 3 is required for Android manifest verification.');
}

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
      expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
      expect(manifest, contains('ScheduledNotificationReceiver'));
      expect(manifest, contains('ScheduledNotificationBootReceiver'));
      expect(manifest, contains('com.google.android.gms.ads.APPLICATION_ID'));
    },
  );

  test('structural Android manifest verifier passes', () {
    final result = Process.runSync(_pythonExecutable(), [
      'tool/verify_android_manifest.py',
    ]);

    expect(
      result.exitCode,
      0,
      reason: 'stdout:\n${result.stdout}\n\nstderr:\n${result.stderr}',
    );
  });

  test('release configuration script preserves production permissions', () {
    final py = File('tool/configure_android_release.py').readAsStringSync();
    expect(py, contains('android.permission.CAMERA'));
    expect(py, contains('android.permission.POST_NOTIFICATIONS'));
    expect(py, contains('android.permission.INTERNET'));
    expect(py, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
    expect(
      py,
      contains('DEFAULT_ROOT = Path(__file__).resolve().parent.parent'),
    );
    expect(py, contains('OCR_DEP_GROOVY'));
    expect(py, contains('DESUGAR_DEP_GROOVY'));
  });

  test(
    'release Gradle config fails closed instead of using the test AdMob app id',
    () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();

      expect(gradle, contains('System.getenv("ADMOB_APP_ID") ?: ""'));
      expect(gradle, contains('requestedReleaseBuild'));
      expect(gradle, contains('GradleException'));
      expect(gradle, isNot(contains('ca-app-pub-3940256099942544~3347511713')));
    },
  );

  test('production sources do not include Google sample AdMob ids', () {
    const samplePublisherId = 'ca-app-pub-3940256099942544';
    final productionFiles = [
      File('android/app/build.gradle.kts'),
      File('lib/src/services/ad_service.dart'),
      File('tool/configure_android_release.sh'),
      File('tool/configure_android_release.py'),
      File('.github/workflows/release-apk.yml'),
    ];

    for (final file in productionFiles) {
      expect(
        file.readAsStringSync(),
        isNot(contains(samplePublisherId)),
        reason: '${file.path} should require production AdMob IDs.',
      );
    }
  });

  test('release workflow validates AdMob secrets before building', () {
    final workflow = File(
      '.github/workflows/release-apk.yml',
    ).readAsStringSync();

    expect(workflow, contains('Missing ADMOB_APP_ID secret'));
    expect(workflow, contains('Missing ADMOB_BANNER_AD_UNIT_ID secret'));
  });

  test('release workflow validates signing secrets before building', () {
    final workflow = File(
      '.github/workflows/release-apk.yml',
    ).readAsStringSync();

    expect(workflow, contains('Missing KEYSTORE_BASE64 secret'));
    expect(workflow, contains('Missing KEYSTORE_STORE_PASSWORD secret'));
    expect(workflow, contains('Missing KEYSTORE_KEY_PASSWORD secret'));
    expect(workflow, contains('Missing KEYSTORE_KEY_ALIAS secret'));
  });

  test('gitignore keeps Android signing material out of the repository', () {
    final gitignore = File('.gitignore').readAsStringSync();

    expect(gitignore, contains('android/key.properties'));
    expect(gitignore, contains('android/app/key.properties'));
    expect(gitignore, contains('android/app/*.jks'));
    expect(gitignore, contains('android/app/*.keystore'));
  });
}
