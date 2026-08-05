import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bootstrap disposes purchase providers on every dependency teardown', () {
    final source = File('lib/src/bootstrap_app.dart').readAsStringSync();

    expect(source, contains('final purchaseProvider = _purchaseProvider;'));
    expect(source, contains('purchaseProvider?.dispose();'));
    expect(
      source,
      contains('final previousPurchaseProvider = _purchaseProvider;'),
    );
    expect(source, contains('previousPurchaseProvider?.dispose();'));
    expect(source, contains('_purchaseProvider?.dispose();'));
  });
}
