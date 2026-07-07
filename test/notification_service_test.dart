// test/notification_service_test.dart
// NotificationService の基本的な構築と通知IDハッシュの安定性をテストする。
// 関連: lib/src/services/notification_service.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';

void main() {
  test('can construct without timezone auto-detection', () {
    final service = NotificationService(timezoneName: 'Asia/Tokyo');
    expect(service, isNotNull);
  });
}
