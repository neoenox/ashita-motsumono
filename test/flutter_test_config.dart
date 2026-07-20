import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Installs platform-channel fakes shared by the Flutter test suite.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  const messagesChannel = MethodChannel('receive_sharing_intent/messages');
  const mediaEventsChannel =
      MethodChannel('receive_sharing_intent/events-media');

  messenger.setMockMethodCallHandler(messagesChannel, (call) async {
    return switch (call.method) {
      'getInitialMedia' => <dynamic>[],
      'reset' => null,
      _ => null,
    };
  });
  messenger.setMockMethodCallHandler(mediaEventsChannel, (call) async {
    return switch (call.method) {
      'listen' || 'cancel' => null,
      _ => null,
    };
  });

  try {
    await testMain();
  } finally {
    messenger.setMockMethodCallHandler(messagesChannel, null);
    messenger.setMockMethodCallHandler(mediaEventsChannel, null);
  }
}
