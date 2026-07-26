import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _marker = 'ashita-motsumono: align receive_sharing_intent JVM targets';

Future<String> _findPython() async {
  for (final candidate in const ['python3', 'python']) {
    try {
      final result = await Process.run(candidate, const ['--version'])
          .timeout(const Duration(seconds: 10));
      if (result.exitCode == 0) return candidate;
    } on Object {
      // Try the next command used by the repository's release scripts.
    }
  }
  throw StateError('Python 3 is required by the Android release tooling.');
}

Future<ProcessResult> _configure({
  required String python,
  required Directory root,
}) {
  final script = File('tool/configure_android_plugin_jvm.py').absolute.path;
  return Process.run(
    python,
    [script, '--root', root.path],
    workingDirectory: Directory.current.path,
  ).timeout(const Duration(seconds: 30));
}

void main() {
  test('adds an idempotent Kotlin DSL compatibility block', () async {
    final python = await _findPython();
    final root = Directory.systemTemp.createTempSync('android_jvm_kts_test_');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    final android = Directory('${root.path}${Platform.pathSeparator}android')
      ..createSync(recursive: true);
    final gradle = File(
      '${android.path}${Platform.pathSeparator}build.gradle.kts',
    )..writeAsStringSync('allprojects {\n    repositories { google() }\n}\n');

    final firstRun = await _configure(python: python, root: root);
    expect(firstRun.exitCode, 0, reason: '${firstRun.stderr}');
    final first = gradle.readAsStringSync();

    expect(first, contains('name == "receive_sharing_intent"'));
    expect(first, contains('tasks.withType<org.gradle.api.tasks.compile.JavaCompile>()'));
    expect(first, contains('org.gradle.api.JavaVersion.VERSION_17.toString()'));
    expect(first, isNot(contains('kotlin.jvm.target.validation.mode')));

    final secondRun = await _configure(python: python, root: root);
    expect(secondRun.exitCode, 0, reason: '${secondRun.stderr}');
    final second = gradle.readAsStringSync();

    expect(second, first);
    expect(RegExp(RegExp.escape(_marker)).allMatches(second), hasLength(1));
  });

  test('supports a Groovy Android root build file', () async {
    final python = await _findPython();
    final root = Directory.systemTemp.createTempSync('android_jvm_groovy_test_');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    final android = Directory('${root.path}${Platform.pathSeparator}android')
      ..createSync(recursive: true);
    final gradle = File('${android.path}${Platform.pathSeparator}build.gradle')
      ..writeAsStringSync('allprojects {\n    repositories { google() }\n}\n');

    final result = await _configure(python: python, root: root);
    expect(result.exitCode, 0, reason: '${result.stderr}');

    final configured = gradle.readAsStringSync();
    expect(configured, contains("name == 'receive_sharing_intent'"));
    expect(configured, contains('org.gradle.api.tasks.compile.JavaCompile'));
    expect(configured, contains('org.gradle.api.JavaVersion.VERSION_17'));
  });
}
