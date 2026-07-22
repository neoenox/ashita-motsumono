// test/tool/release_audit_test.dart
//
// Release Gate 逶｣譟ｻ繝ｭ繧ｸ繝・け縺ｮ繝ｦ繝九ャ繝医ユ繧ｹ繝・// 蜷・メ繧ｧ繝・け髢｢謨ｰ縺ｮ豁｣蟶ｸ邉ｻ繝ｻ逡ｰ蟶ｸ邉ｻ繧呈､懆ｨｼ縺吶ｋ縲・
import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/release_audit.dart';

void main() {
  late ReleaseAudit audit;

  setUp(() {
    audit = ReleaseAudit();
  });

  test('莉ｮapplicationId縺ｯ繧ｨ繝ｩ繝ｼ縺ｫ縺ｪ繧・, () {
    final results = audit.checkApplicationId(
      'applicationId = "com.example.ashita_motsumono"',
    );

    expect(results.any((result) => result.isError), isTrue);
  });

  test('豁｣蠑渋pplicationId縺ｯ蜷域ｼ縺吶ｋ', () {
    final results = audit.checkApplicationId(
      'applicationId = "com.ashita_motsumono"',
    );

    expect(results.any((result) => result.isError), isFalse);
    expect(results.single.severity, ReleaseCheckSeverity.info);
  });

  test('version蠖｢蠑上・豁｣蟶ｸ邉ｻ縺ｨ逡ｰ蟶ｸ邉ｻ繧貞愛螳壹☆繧・, () {
    final validResults = audit.checkPubspecVersion('version: 0.6.3+2');
    final invalidResults = audit.checkPubspecVersion('version: 0.6.3');

    expect(validResults.any((result) => result.isError), isFalse);
    expect(invalidResults.any((result) => result.isError), isTrue);
  });

  test('targetSdk 34縺ｯ繧ｨ繝ｩ繝ｼ縺ｫ縺ｪ繧・, () {
    final results = audit.checkTargetSdkValue(34);

    expect(results.single.severity, ReleaseCheckSeverity.error);
  });

  test('targetSdk 35縺ｯ隴ｦ蜻翫↓縺ｪ繧・, () {
    final results = audit.checkTargetSdkValue(35);

    expect(results.single.severity, ReleaseCheckSeverity.warning);
  });

  test('targetSdk 36縺ｯ蜷域ｼ縺吶ｋ', () {
    final results = audit.checkTargetSdkValue(36);

    expect(results.single.severity, ReleaseCheckSeverity.info);
  });

  test('debuggable true縺ｯ繧ｨ繝ｩ繝ｼ縲’alse縺ｯ蜷域ｼ縺吶ｋ', () {
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

  test('譛ｪ險ｱ蜿ｯ縺ｮlocalhost蜿ら・繧呈､懷・縺吶ｋ', () {
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

  test('allowlist蟇ｾ雎｡縺ｮlocalhost蜿ら・縺ｯ險ｱ蜿ｯ縺吶ｋ', () {
    final results = audit.checkLocalhostReferences(
      <String, String>{
        'lib/src/services/gemini_api_service.dart':
            "return uri.host == 'localhost';",
      },
    );

    expect(results.any((result) => result.isError), isFalse);
  });

  test('AdMob繧ｵ繝ｳ繝励ΝID繧呈､懷・縺吶ｋ', () {
    final results = audit.checkAdMobSampleIds(
      <String, String>{
        'lib/src/ads/ad_config.dart':
            "const appId = 'ca-app-pub-3940256099942544~3347511713';",
      },
    );

    expect(results.any((result) => result.isError), isTrue);
  });
}
