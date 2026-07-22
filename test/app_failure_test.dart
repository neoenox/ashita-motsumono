// test/app_failure_test.dart
// AppFailure sealed class のテスト
// なぜ存在するか: エラー分類が正しく動作することを確認するため
// 関連ファイル: lib/src/services/app_failure.dart

import 'package:ashita_motsumono/src/services/app_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppFailure', () {
    test('OcrFailure has user message and suggested action', () {
      const failure = OcrFailure(message: 'test error');
      expect(failure.userMessage, contains('読み取り'));
      expect(failure.suggestedAction, isNotNull);
    });

    test('PermissionDeniedFailure has user message', () {
      const failure = PermissionDeniedFailure(permissionType: 'カメラ');
      expect(failure.userMessage, contains('カメラ'));
      expect(failure.suggestedAction, contains('設定'));
    });

    test('DatabaseFailure has user message', () {
      const failure = DatabaseFailure(message: 'DB error');
      expect(failure.userMessage, contains('保存'));
      expect(failure.suggestedAction, contains('再試行'));
    });

    test('NotificationScheduleFailure has user message', () {
      const failure = NotificationScheduleFailure(message: 'notification error');
      expect(failure.userMessage, contains('通知'));
      expect(failure.suggestedAction, contains('利用'));
    });

    test('BillingUnavailableFailure has user message', () {
      const failure = BillingUnavailableFailure();
      expect(failure.userMessage, contains('課金'));
      expect(failure.suggestedAction, contains('再試行'));
    });

    test('PurchasePendingFailure has user message', () {
      const failure = PurchasePendingFailure();
      expect(failure.userMessage, contains('確認中'));
      expect(failure.suggestedAction, contains('お待ち'));
    });

    test('NetworkFailure has user message', () {
      const failure = NetworkFailure();
      expect(failure.userMessage, contains('ネットワーク'));
      expect(failure.suggestedAction, contains('接続'));
    });

    test('ImageReadFailure has user message', () {
      const failure = ImageReadFailure(path: '/test/image.jpg');
      expect(failure.userMessage, contains('画像'));
      expect(failure.suggestedAction, contains('選択'));
    });

    test('GeminiApiFailure has user message', () {
      const failure = GeminiApiFailure(message: 'API error');
      expect(failure.userMessage, contains('AI解析'));
      expect(failure.suggestedAction, isNotNull);
    });

    test('UnexpectedFailure has user message', () {
      const failure = UnexpectedFailure(message: 'unexpected');
      expect(failure.userMessage, contains('予期しない'));
      expect(failure.suggestedAction, contains('再起動'));
    });

    test('All failures are AppFailure subclasses', () {
      const failures = [
        OcrFailure(message: 'test'),
        PermissionDeniedFailure(permissionType: 'test'),
        DatabaseFailure(message: 'test'),
        NotificationScheduleFailure(message: 'test'),
        BillingUnavailableFailure(),
        PurchasePendingFailure(),
        NetworkFailure(),
        ImageReadFailure(path: 'test'),
        GeminiApiFailure(message: 'test'),
        UnexpectedFailure(message: 'test'),
      ];

      for (final failure in failures) {
        expect(failure, isA<AppFailure>());
        expect(failure.userMessage, isNotEmpty);
      }
    });
  });
}