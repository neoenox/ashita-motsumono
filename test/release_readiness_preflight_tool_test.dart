// Release readiness preflight Python tests are part of the normal Flutter CI.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release readiness preflight tests pass', () async {
    final executable = Platform.isWindows ? 'python' : 'python3';
    final result = await Process.run(executable, const [
      '-m',
      'unittest',
      'tool/test_release_readiness_preflight.py',
    ], workingDirectory: Directory.current.path);

    expect(
      result.exitCode,
      0,
      reason:
          'Release readiness preflight Python tests failed.\n'
          'stdout:\n${result.stdout}\n'
          'stderr:\n${result.stderr}',
    );
  });
}
