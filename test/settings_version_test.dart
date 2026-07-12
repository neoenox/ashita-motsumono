import 'package:ashita_motsumono/src/screens/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  test('formats package version and build number', () {
    final info = PackageInfo(
      appName: 'Ashita Motsumono',
      packageName: 'com.ashita_motsumono',
      version: '0.6.3',
      buildNumber: '2',
    );

    expect(formatAppVersion(info), 'Version 0.6.3+2');
  });

  test('omits separator when build number is empty', () {
    final info = PackageInfo(
      appName: 'Ashita Motsumono',
      packageName: 'com.ashita_motsumono',
      version: '0.6.3',
      buildNumber: '',
    );

    expect(formatAppVersion(info), 'Version 0.6.3');
  });
}
