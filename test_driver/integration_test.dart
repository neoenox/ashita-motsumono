// test_driver/integration_test.dart
// integration_test パッケージのエントリポイント。flutter drive で実行される。
// Issue #60 通知実測テストの起動に使用する。
// 関連: integration_test/issue60_notification_test.dart

import 'dart:io';

import 'package:integration_test/integration_test.dart';

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ADB で通知を取得するヘルパー。テスト間で共有する。
  final result = await Process.run('adb', [
    'shell',
    'dumpsys',
    'notification',
    '--noredact',
  ]);
  final output = result.stdout as String;

  // 直近の通知件数をファイルに書き出す（集約スクリプトが参照）。
  final logDir = Directory('build/issue60_evidence');
  if (!logDir.existsSync()) {
    logDir.createSync(recursive: true);
  }

  // 前回起動時のダンプを退避してからクリアする。
  final prevDump = File('${logDir.path}/notification_dump.txt');
  if (prevDump.existsSync()) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    prevDump.renameSync('${logDir.path}/notification_dump_${ts}.txt');
  }
  prevDump.writeAsStringSync(output);

  print('Issue #60 integration_test initialized. Notification dump saved.');
}
