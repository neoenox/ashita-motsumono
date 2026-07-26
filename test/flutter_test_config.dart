import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Installs platform fakes shared by the Flutter test suite.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // receive_sharing_intent 1.8.1 includes the official test hook introduced
  // in 1.7.0. Using it avoids leaving the plugin's initial-media Future or
  // event stream pending between widget tests, which previously stalled the
  // full CI suite. HomeScreen tests must separately seed
  // notification_info_shown_v1 unless they intentionally exercise the
  // notification disclosure dialog.
  ReceiveSharingIntent.setMockValues(
    initialMedia: const <SharedMediaFile>[],
    mediaStream: const Stream<List<SharedMediaFile>>.empty(),
  );

  await testMain();
}
