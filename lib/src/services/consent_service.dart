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

  /// UMPがプライバシー設定の再表示入口を要求しているかをUIへ通知する。
  static final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier(false);

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

  static Future<bool> refreshPrivacyOptionsRequirement() async {
    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus()
        .timeout(_timeout);
    final required = status == PrivacyOptionsRequirementStatus.required;
    privacyOptionsRequired.value = required;
    return required;
  }

  static Future<void> refreshPrivacyOptionsRequirementSafely() async {
    try {
      await refreshPrivacyOptionsRequirement();
    } on Object catch (error, stackTrace) {
      debugPrint(
        'ConsentService: privacy options status failed: $error\n$stackTrace',
      );
      privacyOptionsRequired.value = false;
    }
  }

  static Future<FormError?> showConsentFormIfRequired() async {
    final completer = Completer<FormError?>();
    ConsentForm.loadAndShowConsentFormIfRequired((formError) {
      if (!completer.isCompleted) completer.complete(formError);
    });
    return completer.future.timeout(_timeout);
  }

  /// UMP callbackのtimeoutやplugin例外を結果へ変換し、detached Futureへ
  /// 例外を漏らさない。今回の同意取得に失敗しても、前回セッションの
  /// 同意状態で広告を要求できるかは必ず再確認する。
  static Future<ConsentResult> runConsentFlow({
    @visibleForTesting ConsentInfoUpdater? requestInfo,
    @visibleForTesting ConsentFormPresenter? showForm,
    @visibleForTesting ConsentAdsChecker? checkCanRequestAds,
  }) async {
    final updateConsentInfo = requestInfo ?? () => requestConsentInfoUpdate();
    final presentConsentForm = showForm ?? () => showConsentFormIfRequired();
    final checkAds = checkCanRequestAds ?? () => canRequestAds();
    final usesPlatformApis =
        requestInfo == null && showForm == null && checkCanRequestAds == null;

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
          canRequestAds: await _safeCanRequestAds(checkAds),
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
          canRequestAds: await _safeCanRequestAds(checkAds),
        );
      }

      final canRequest = await checkAds();
      return ConsentResult(canRequestAds: canRequest);
    } on TimeoutException catch (error, stackTrace) {
      debugPrint('ConsentService: consent flow timed out: $error\n$stackTrace');
      return ConsentResult(
        exception: error,
        failureReason: ConsentFailureReason.timeout,
        canRequestAds: await _safeCanRequestAds(checkAds),
      );
    } on Object catch (error, stackTrace) {
      debugPrint('ConsentService: consent flow failed: $error\n$stackTrace');
      return ConsentResult(
        exception: error,
        failureReason: ConsentFailureReason.unexpected,
        canRequestAds: await _safeCanRequestAds(checkAds),
      );
    } finally {
      if (usesPlatformApis) {
        await refreshPrivacyOptionsRequirementSafely();
      }
    }
  }

  static Future<bool> _safeCanRequestAds(ConsentAdsChecker checkAds) async {
    try {
      return await checkAds();
    } on Object catch (error, stackTrace) {
      debugPrint(
        'ConsentService: fallback ad requestability check failed: '
        '$error\n$stackTrace',
      );
      return false;
    }
  }

  static Future<FormError?> showPrivacyOptions() async {
    final completer = Completer<FormError?>();
    ConsentForm.showPrivacyOptionsForm((formError) {
      if (formError != null) {
        debugPrint(
          'ConsentService: privacy options error '
          '(${formError.errorCode}): ${formError.message}',
        );
      }
      if (!completer.isCompleted) completer.complete(formError);
    });
    try {
      return await completer.future.timeout(_timeout);
    } finally {
      await refreshPrivacyOptionsRequirementSafely();
    }
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

  /// 同意取得処理の成否とは分けて判定する。UMPは今回の処理が失敗しても
  /// 前回セッションの有効な同意状態を返すことがある。
  bool get adsAllowed => canRequestAds;
}
