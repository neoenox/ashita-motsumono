// test/tool/release_audit_test.dart
//
// Release Gate 監査ロジックのユニットテスト
// 各チェック関数の正常系・異常系を検証する。

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/release_audit.dart';

void main() {
  late ReleaseAudit audit;

  setUp(() {
    audit = ReleaseAudit();
  });

  test('仮applicationIdはエラーになる', () {
    final results = audit.checkApplicationId(
      'applicationId = "com.example.ashita_motsumono"',
    );

    expect(results.any((result) => result.isError), isTrue);
  });

  test('正式applicationIdは合格する', () {
    final results = audit.checkApplicationId(
      'applicationId = "com.ashita_motsumono"',
    );

    expect(results.any((result) => result.isError), isFalse);
    expect(results.single.severity, ReleaseCheckSeverity.info);
  });

  test('version形式の正常系と異常系を判定する', () {
    final validResults = audit.checkPubspecVersion('version: 0.6.3+2');
    final invalidResults = audit.checkPubspecVersion('version: 0.6.3');

    expect(validResults.any((result) => result.isError), isFalse);
    expect(invalidResults.any((result) => result.isError), isTrue);
  });

  test('targetSdk 34はエラーになる', () {
    final results = audit.checkTargetSdkValue(34);

    expect(results.single.severity, ReleaseCheckSeverity.error);
  });

  test('targetSdk 35は警告になる', () {
    final results = audit.checkTargetSdkValue(35);

    expect(results.single.severity, ReleaseCheckSeverity.warning);
  });

  test('targetSdk 36は合格する', () {
    final results = audit.checkTargetSdkValue(36);

    expect(results.single.severity, ReleaseCheckSeverity.info);
  });

  test('debuggable trueはエラー、falseは合格する', () {
    final trueResults = audit.checkDebuggable(
      <String, String>{
        'AndroidManifest.xml':
            '<application android:debuggable="true" />',
      },
    );
    final falseResults = audit.checkDebuggable(
      <String, String>{
        'AndroidManifest.xml':
            '<application android:debuggable="false" />',
      },
    );

    expect(trueResults.any((result) => result.isError), isTrue);
    expect(falseResults.any((result) => result.isError), isFalse);
  });

  test('未許可のlocalhost参照を検出する', () {
    final results = audit.checkLocalhostReferences(
      <String, String>{
        'lib/src/screens/add_todo_screen.dart': '''
const apiName = 'production';
const endpoint = 'http://localhost:8787';
''',
      },
    );

    expect(results.any((result) => result.isError), isTrue);
    expect(
      results.where((result) => result.isError).single.line,
      2,
    );
  });

  test('allowlist対象のlocalhost参照は許可する', () {
    final results = audit.checkLocalhostReferences(
      <String, String>{
        'lib/src/services/gemini_api_service.dart':
            "return uri.host == 'localhost';",
      },
    );

    expect(results.any((result) => result.isError), isFalse);
  });

  test('AdMobサンプルIDを検出する', () {
    final results = audit.checkAdMobSampleIds(
      <String, String>{
        'lib/src/ads/ad_config.dart':
            "const appId = 'ca-app-pub-3940256099942544~3347511713';",
      },
    );

    expect(results.any((result) => result.isError), isTrue);
  });
}
