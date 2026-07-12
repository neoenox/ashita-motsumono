// test/settings_external_link_test.dart
// 設定画面の外部リンク起動が失敗を呼び出し元へ返すことを検証する。

import 'package:ashita_motsumono/src/screens/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final uri = Uri.parse('https://example.com/contact');

  test('returns false without launching when canOpen is false', () async {
    var launchCalled = false;

    final result = await tryOpenExternalPage(
      uri: uri,
      canOpen: (_) async => false,
      launch: (_) async {
        launchCalled = true;
        return true;
      },
    );

    expect(result, isFalse);
    expect(launchCalled, isFalse);
  });

  test('returns false when launcher returns false', () async {
    final result = await tryOpenExternalPage(
      uri: uri,
      canOpen: (_) async => true,
      launch: (_) async => false,
    );

    expect(result, isFalse);
  });

  test('returns false when availability check throws', () async {
    final result = await tryOpenExternalPage(
      uri: uri,
      canOpen: (_) => Future<bool>.error(StateError('probe failed')),
      launch: (_) async => true,
    );

    expect(result, isFalse);
  });

  test('returns false when launcher throws', () async {
    final result = await tryOpenExternalPage(
      uri: uri,
      canOpen: (_) async => true,
      launch: (_) => Future<bool>.error(StateError('launch failed')),
    );

    expect(result, isFalse);
  });

  test('returns true only when the page is launched', () async {
    final result = await tryOpenExternalPage(
      uri: uri,
      canOpen: (_) async => true,
      launch: (_) async => true,
    );

    expect(result, isTrue);
  });
}
