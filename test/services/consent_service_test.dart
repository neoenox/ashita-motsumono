import 'dart:async';

import 'package:ashita_motsumono/src/services/consent_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConsentService.runConsentFlow', () {
    test('allows ads after a successful consent flow', () async {
      var formShown = false;

      final result = await ConsentService.runConsentFlow(
        requestInfo: () async => null,
        showForm: () async {
          formShown = true;
          return null;
        },
        checkCanRequestAds: () async => true,
      );

      expect(formShown, isTrue);
      expect(result.isSuccess, isTrue);
      expect(result.adsAllowed, isTrue);
      expect(result.failureReason, isNull);
    });

    test('contains timeout and stops the remaining flow', () async {
      var formShown = false;
      var adsChecked = false;

      final result = await ConsentService.runConsentFlow(
        requestInfo: () async => throw TimeoutException('UMP timeout'),
        showForm: () async {
          formShown = true;
          return null;
        },
        checkCanRequestAds: () async {
          adsChecked = true;
          return true;
        },
      );

      expect(formShown, isFalse);
      expect(adsChecked, isFalse);
      expect(result.isSuccess, isFalse);
      expect(result.adsAllowed, isFalse);
      expect(result.failureReason, ConsentFailureReason.timeout);
      expect(result.exception, isA<TimeoutException>());
    });

    test('contains unexpected plugin exceptions', () async {
      final result = await ConsentService.runConsentFlow(
        requestInfo: () async => null,
        showForm: () async => throw StateError('plugin failure'),
        checkCanRequestAds: () async => true,
      );

      expect(result.isSuccess, isFalse);
      expect(result.adsAllowed, isFalse);
      expect(result.failureReason, ConsentFailureReason.unexpected);
      expect(result.exception, isA<StateError>());
    });

    test('does not allow ads when UMP reports not requestable', () async {
      final result = await ConsentService.runConsentFlow(
        requestInfo: () async => null,
        showForm: () async => null,
        checkCanRequestAds: () async => false,
      );

      expect(result.isSuccess, isTrue);
      expect(result.canRequestAds, isFalse);
      expect(result.adsAllowed, isFalse);
    });
  });
}
