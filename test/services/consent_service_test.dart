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

    test('uses prior consent when the current flow times out', () async {
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
      expect(adsChecked, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.adsAllowed, isTrue);
      expect(result.failureReason, ConsentFailureReason.timeout);
      expect(result.exception, isA<TimeoutException>());
    });

    test(
      'uses prior consent after an unexpected form plugin exception',
      () async {
        final result = await ConsentService.runConsentFlow(
          requestInfo: () async => null,
          showForm: () async => throw StateError('plugin failure'),
          checkCanRequestAds: () async => true,
        );

        expect(result.isSuccess, isFalse);
        expect(result.adsAllowed, isTrue);
        expect(result.failureReason, ConsentFailureReason.unexpected);
        expect(result.exception, isA<StateError>());
      },
    );

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

    test('fails closed when the fallback ad check also fails', () async {
      final result = await ConsentService.runConsentFlow(
        requestInfo: () async => throw TimeoutException('UMP timeout'),
        showForm: () async => null,
        checkCanRequestAds: () async => throw StateError('check failed'),
      );

      expect(result.isSuccess, isFalse);
      expect(result.adsAllowed, isFalse);
      expect(result.failureReason, ConsentFailureReason.timeout);
    });

    test('times out when the final ad requestability check stalls', () async {
      final stalled = Completer<bool>();

      final result = await ConsentService.runConsentFlow(
        requestInfo: () async => null,
        showForm: () async => null,
        checkCanRequestAds: () => stalled.future,
        timeout: const Duration(milliseconds: 1),
      );

      expect(result.isSuccess, isFalse);
      expect(result.adsAllowed, isFalse);
      expect(result.failureReason, ConsentFailureReason.timeout);
      expect(result.exception, isA<TimeoutException>());
    });

    test(
      'times out and fails closed when the fallback ad check stalls',
      () async {
        final result = await ConsentService.runConsentFlow(
          requestInfo: () async => throw TimeoutException('UMP timeout'),
          showForm: () async => null,
          checkCanRequestAds: () => Completer<bool>().future,
          timeout: const Duration(milliseconds: 1),
        );

        expect(result.isSuccess, isFalse);
        expect(result.adsAllowed, isFalse);
        expect(result.failureReason, ConsentFailureReason.timeout);
        expect(result.exception, isA<TimeoutException>());
      },
    );
  });
}
