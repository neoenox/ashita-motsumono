// lib/src/services/notification_id_repository.dart
// ローカル通知IDを永続化し、Todo間のID衝突を防ぐための抽象化。

import 'package:flutter/foundation.dart';

@immutable
class NotificationIdPair {
  const NotificationIdPair({
    required this.previousNight,
    required this.sameMorning,
  });

  final int previousNight;
  final int sameMorning;

  Iterable<int> get values sync* {
    yield previousNight;
    yield sameMorning;
  }
}

abstract interface class NotificationIdRepository {
  Future<NotificationIdPair> getOrCreateNotificationIds(String todoId);

  Future<NotificationIdPair?> findNotificationIds(String todoId);

  Future<void> releaseNotificationIds(String todoId);
}
