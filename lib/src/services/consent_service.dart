// lib/src/services/consent_service.dart
// Google User Messaging Platform (UMP) 同意取得フレームワーク。
// EEAユーザーのGDPR同意を管理し、広告初期化前に同意状態を確認する。
// 関連: ad_service.dart, bootstrap_app.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

typedef ConsentInfoUpdater = Future<FormError?> Function();
typedef ConsentFormPresenter = Future<FormError?> Function();
typedef ConsentAdsChecker = Future<bool> Function();

enum ConsentFailureReason { infoUpdate, form, timeout, unexpected }

class ConsentService {
  ConsentService._();

  static const _timeout = Duration(seconds: 30);

  static Future<FormError?> requestConsentInfoUpdate({
    List<String>? testDeviceIds,
    DebugGeography? debugGeography,
  }) async {
    final completer = Completer<FormError?>();
    final params = ConsentRequestParameters(
      consentDebugSettings: (testDeviceIds != null || debugGeography != null)
          ? ConsentDebugSettings(
              testIdentifiers: testDeviceIds,
              debugGeography: debugGeography,
            )
          : null,
    );

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () {
        if (!completer.isCompleted) completer.complete(null);
      },
      (error) {
        if (!completer.isCompleted) completer.complete(error);
      },
    );

    return completer.future.timeout(_timeout);
  }

  static Future<ConsentStatus> getConsentStatus() {
    return ConsentInformation.instance.getConsentStatus();
  }

  static Future<bool> canRequestAds() {
    return ConsentInformation.instance.canRequestAds();
  }

  static Future<FormError?> showConsentFormIfRequired() async {
    final completer = Completer<FormError?>();
    ConsentForm.loadAndShowConsentFormIfRequired((formError) {
      if (!completer.isCompleted) completer.complete(formError);
    });
    return completer.future.timeout(_timeout);
  }

  /// UMP callbackのtimeoutやplugin例外を結果へ変換し、detached Futureへ
  /// 例外を漏らさない。
  static Future<ConsentResult> runConsentFlow({
    @visibleForTesting ConsentInfoUpdater? requestInfo,
    @visibleForTesting ConsentFormPresenter? showForm,
    @visibleForTesting ConsentAdsChecker? checkCanRequestAds,
  }) async {
    final updateConsentInfo =
        requestInfo ?? () => requestConsentInfoUpdate();
    final presentConsentForm =
        showForm ?? () => showConsentFormIfRequired();
    final checkAds = checkCanRequestAds ?? () => canRequestAds();

    try {
      final updateError = await updateConsentInfo();
      if (updateError != null) {
        debugPrint(
          'ConsentService: info update failed (${updateError.errorCode}): '
          '${updateError.message}',
        );
        return ConsentResult(
          error: updateError,
          failureReason: ConsentFailureReason.infoUpdate,
        );
      }

      final formError = await presentConsentForm();
      if (formError != null) {
        debugPrint(
          'ConsentService: form error (${formError.errorCode}): '
          '${formError.message}',
        );
        return ConsentResult(
          error: formError,
          failureReason: ConsentFailureReason.form,
        );
      }

      final canRequest = await checkAds();
      return ConsentResult(canRequestAds: canRequest);
    } on TimeoutException catch (error, stackTrace) {
      debugPrint('ConsentService: consent flow timed out: $error\n$stackTrace');
      return ConsentResult(
        exception: error,
        failureReason: ConsentFailureReason.timeout,
      );
    } on Object catch (error, stackTrace) {
      debugPrint('ConsentService: consent flow failed: $error\n$stackTrace');
      return ConsentResult(
        exception: error,
        failureReason: ConsentFailureReason.unexpected,
      );
    }
  }

  static Future<void> showPrivacyOptions() {
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((formError) {
      if (formError != null) {
        debugPrint(
          'ConsentService: privacy options error '
          '(${formError.errorCode}): ${formError.message}',
        );
      }
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future.timeout(_timeout);
  }
}

class ConsentResult {
  const ConsentResult({
    this.error,
    this.exception,
    this.failureReason,
    this.canRequestAds = false,
  });

  final FormError? error;
  final Object? exception;
  final ConsentFailureReason? failureReason;
  final bool canRequestAds;

  bool get isSuccess =>
      error == null && exception == null && failureReason == null;
  bool get adsAllowed => isSuccess && canRequestAds;
}
