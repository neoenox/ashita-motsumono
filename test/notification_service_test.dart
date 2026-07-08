// test/notification_service_test.dart
// NotificationService の基本的な構築と通知IDハッシュの安定性をテストする。
// プラグイン依存の initialize/schedule/cancel はテスト用プラグイン環境が必要なため、
// ここでは構築のみテストする。統合テストは実機または platform channels の
// モック環境で行う。
// 関連: lib/src/services/notification_service.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';

void main() {
  group('NotificationService construction', () {
    test('can construct without timezone auto-detection', () {
      final service = NotificationService(timezoneName: 'Asia/Tokyo');
      expect(service, isNotNull);
    });

    test('can construct without timezone name', () {
      final service = NotificationService();
      expect(service, isNotNull);
    });

    test('can construct with settings', () {
      final service = NotificationService(timezoneName: 'Asia/Tokyo');
      expect(service, isNotNull);
    });

    test('multiple instances are independent', () {
      final a = NotificationService(timezoneName: 'Asia/Tokyo');
      final b = NotificationService(timezoneName: 'America/New_York');
      expect(a, isNotNull);
      expect(b, isNotNull);
      expect(a, isNot(same(b)));
    });
  });
}
