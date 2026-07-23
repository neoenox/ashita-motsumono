import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/release_audit.dart';

void main() {
  group('ReleaseAudit', () {
    test('accepts the current release shape with targetSdk 36', () {
      final report = ReleaseAudit.run(_validInput());

      expect(report.passed, isTrue);
      expect(report.issues, isEmpty);
      expect(report.facts.applicationId, 'com.ashita_motsumono');
      expect(report.facts.versionName, '0.6.3');
      expect(report.facts.versionCode, 2);
      expect(report.facts.targetSdk, 36);
    });

    test('rejects placeholder applicationId', () {
      final report = ReleaseAudit.run(
        _validInput(
          gradleContent: _gradle.replaceFirst(
            'com.ashita_motsumono',
            'com.example.app',
          ),
        ),
      );

      expect(_codes(report), contains('application_id_placeholder'));
    });

    test('rejects malformed pubspec version', () {
      final report = ReleaseAudit.run(
        _validInput(
          pubspecContent: _pubspec.replaceFirst('0.6.3+2', '0.6+zero'),
        ),
      );

      expect(_codes(report), contains('pubspec_version_invalid'));
    });

    test('rejects targetSdk below 35', () {
      final report = ReleaseAudit.run(
        _validInput(gradleContent: _gradle.replaceFirst('36', '34')),
      );

      expect(_codes(report), contains('target_sdk_too_low'));
    });

    test('warns for targetSdk 35 and passes', () {
      final report = ReleaseAudit.run(
        _validInput(gradleContent: _gradle.replaceFirst('36', '35')),
      );

      expect(report.passed, isTrue);
      expect(_codes(report), contains('target_sdk_35'));
      expect(report.warnings, hasLength(1));
    });

    test('resolves flutter.targetSdkVersion from the supplied SDK value', () {
      final report = ReleaseAudit.run(
        _validInput(
          gradleContent: _gradle.replaceFirst('36', 'flutter.targetSdkVersion'),
          resolvedFlutterTargetSdk: 36,
        ),
      );

      expect(report.passed, isTrue);
      expect(report.facts.targetSdk, 36);
    });

    test('rejects release debuggable and cleartext traffic', () {
      final report = ReleaseAudit.run(
        _validInput(
          gradleContent: _gradle.replaceFirst(
            'release {',
            'release {\n      isDebuggable = true',
          ),
          manifestContent: _manifest.replaceFirst(
            'android:icon="@mipmap/ic_launcher"',
            'android:icon="@mipmap/ic_launcher" '
                'android:usesCleartextTraffic="true"',
          ),
        ),
      );

      expect(_codes(report), contains('release_debuggable_true'));
      expect(_codes(report), contains('cleartext_traffic_enabled'));
    });

    test('rejects local endpoints in production files', () {
      final report = ReleaseAudit.run(
        _validInput(
          productionFiles: const <String, String>{
            'lib/src/config.dart':
                "const endpoints = ['localhost', '127.0.0.1', '10.0.2.2'];",
          },
        ),
      );

      expect(
        report.issues.where(
          (issue) => issue.code == 'local_endpoint_in_production',
        ),
        hasLength(3),
      );
    });

    test('rejects Google sample AdMob IDs in code or environment', () {
      final report = ReleaseAudit.run(
        _validInput(
          productionFiles: const <String, String>{
            'lib/src/services/ad_service.dart':
                "const id = 'ca-app-pub-3940256099942544/6300978111';",
          },
          releaseEnvironment: const <String, String>{
            'ADMOB_APP_ID': 'ca-app-pub-3940256099942544~3347511713',
          },
        ),
      );

      expect(_codes(report), contains('google_sample_admob_id'));
      expect(
        _codes(report),
        contains('sample_admob_id_in_release_environment'),
      );
    });

    test(
      'checks label, icon, required permissions, and high-risk permissions',
      () {
        final report = ReleaseAudit.run(
          _validInput(
            manifestContent: '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
  <application android:label="\${applicationName}" android:icon="launcher.png" />
</manifest>
''',
          ),
        );

        expect(_codes(report), contains('manifest_label_placeholder'));
        expect(_codes(report), contains('manifest_icon_invalid'));
        expect(_codes(report), contains('required_permission_missing'));
        expect(_codes(report), contains('high_risk_permission'));
      },
    );
  });
}

Set<String> _codes(ReleaseAuditReport report) {
  return report.issues.map((issue) => issue.code).toSet();
}

ReleaseAuditInput _validInput({
  String pubspecContent = _pubspec,
  String gradleContent = _gradle,
  String manifestContent = _manifest,
  Map<String, String> productionFiles = const <String, String>{},
  int? resolvedFlutterTargetSdk,
  Map<String, String> releaseEnvironment = const <String, String>{},
}) {
  return ReleaseAuditInput(
    pubspecContent: pubspecContent,
    gradleContent: gradleContent,
    manifestContent: manifestContent,
    productionFiles: productionFiles,
    resolvedFlutterTargetSdk: resolvedFlutterTargetSdk,
    releaseEnvironment: releaseEnvironment,
  );
}

const _pubspec = '''
name: ashita_motsumono
version: 0.6.3+2
''';

const _gradle = '''
android {
  defaultConfig {
    applicationId = "com.ashita_motsumono"
    targetSdk = 36
    versionCode = flutter.versionCode
    versionName = flutter.versionName
  }
  buildTypes {
    release {
      proguardFiles("rules.pro")
    }
  }
}
''';

const _manifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.CAMERA" />
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
  <application
      android:label="あしたもつもの"
      android:icon="@mipmap/ic_launcher">
  </application>
</manifest>
''';
