import 'dart:io';

import 'src/release_audit.dart';

Future<void> main(List<String> arguments) async {
  final root = _resolveProjectRoot(arguments);
  if (root == null) {
    stderr.writeln(
      'Release Gate: pubspec.yaml と android/app があるプロジェクトルートを特定できません。',
    );
    exitCode = 2;
    return;
  }

  final pubspec = File(_join(root.path, 'pubspec.yaml'));
  final gradle = _firstExistingFile(<String>[
    _join(root.path, 'android/app/build.gradle.kts'),
    _join(root.path, 'android/app/build.gradle'),
  ]);
  final manifest = File(
    _join(root.path, 'android/app/src/main/AndroidManifest.xml'),
  );

  final missing = <String>[
    if (!pubspec.existsSync()) pubspec.path,
    if (gradle == null) 'android/app/build.gradle(.kts)',
    if (!manifest.existsSync()) manifest.path,
  ];
  if (missing.isNotEmpty) {
    for (final path in missing) {
      stderr.writeln('Release Gate: 必須ファイルがありません: $path');
    }
    exitCode = 2;
    return;
  }

  final gradleFile = gradle!;
  final productionFiles = await _readProductionFiles(root);
  final flutterTargetSdk = await _resolveFlutterTargetSdk(root);
  final environment = <String, String>{
    for (final name in const <String>[
      'ADMOB_APP_ID',
      'ADMOB_BANNER_AD_UNIT_ID',
    ])
      if ((Platform.environment[name] ?? '').isNotEmpty)
        name: Platform.environment[name]!,
  };

  final report = ReleaseAudit.run(
    ReleaseAuditInput(
      pubspecContent: await pubspec.readAsString(),
      gradleContent: await gradleFile.readAsString(),
      manifestContent: await manifest.readAsString(),
      productionFiles: productionFiles,
      gradlePath: _relativePath(root, gradleFile),
      manifestPath: _relativePath(root, manifest),
      resolvedFlutterTargetSdk: flutterTargetSdk,
      releaseEnvironment: environment,
    ),
  );

  _writeReport(root, report);
  exitCode = report.passed ? 0 : 1;
}

Directory? _resolveProjectRoot(List<String> arguments) {
  String? explicit;
  for (final argument in arguments) {
    if (argument.startsWith('--root=')) {
      explicit = argument.substring('--root='.length);
    } else if (argument == '--help' || argument == '-h') {
      stdout.writeln('Usage: dart run tool/release_gate.dart [--root=<path>]');
      exit(0);
    } else {
      stderr.writeln('Release Gate: 不明な引数です: $argument');
      return null;
    }
  }

  if (explicit != null) {
    final directory = Directory(explicit).absolute;
    return _isProjectRoot(directory) ? directory : null;
  }

  var current = Directory.current.absolute;
  while (true) {
    if (_isProjectRoot(current)) return current;
    final parent = current.parent;
    if (parent.path == current.path) return null;
    current = parent;
  }
}

bool _isProjectRoot(Directory directory) {
  return File(_join(directory.path, 'pubspec.yaml')).existsSync() &&
      Directory(_join(directory.path, 'android/app')).existsSync();
}

File? _firstExistingFile(List<String> paths) {
  for (final path in paths) {
    final file = File(path);
    if (file.existsSync()) return file;
  }
  return null;
}

Future<Map<String, String>> _readProductionFiles(Directory root) async {
  final result = <String, String>{};
  final roots = <Directory>[
    Directory(_join(root.path, 'lib')),
    Directory(_join(root.path, 'android/app/src/main')),
    Directory(_join(root.path, 'android/app/src/release')),
    Directory(_join(root.path, 'ios/Runner')),
  ];
  const extensions = <String>{
    '.dart',
    '.xml',
    '.plist',
    '.json',
    '.yaml',
    '.yml',
    '.properties',
    '.gradle',
    '.kts',
    '.kt',
    '.java',
    '.swift',
    '.m',
    '.mm',
  };

  for (final directory in roots) {
    if (!directory.existsSync()) continue;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is! File || !_hasExtension(entity.path, extensions)) continue;
      try {
        result[_relativePath(root, entity)] = await entity.readAsString();
      } on FileSystemException catch (error) {
        stderr.writeln('Release Gate: 読み取りをスキップしました: ${error.path}');
      }
    }
  }
  return result;
}

bool _hasExtension(String path, Set<String> extensions) {
  final lower = path.toLowerCase();
  return extensions.any(lower.endsWith);
}

Future<int?> _resolveFlutterTargetSdk(Directory root) async {
  final sdkRoots = <String>{};
  final fromEnvironment = Platform.environment['FLUTTER_ROOT'];
  if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
    sdkRoots.add(fromEnvironment);
  }

  final localProperties = File(_join(root.path, 'android/local.properties'));
  if (localProperties.existsSync()) {
    final content = await localProperties.readAsString();
    final match = RegExp(
      r'^flutter\.sdk\s*=\s*(.+)$',
      multiLine: true,
    ).firstMatch(content);
    if (match != null) {
      sdkRoots.add(_decodePropertiesPath(match.group(1)!.trim()));
    }
  }

  var executableDirectory = File(Platform.resolvedExecutable).absolute.parent;
  while (true) {
    if (Directory(
      _join(executableDirectory.path, 'packages/flutter_tools'),
    ).existsSync()) {
      sdkRoots.add(executableDirectory.path);
      break;
    }
    final parent = executableDirectory.parent;
    if (parent.path == executableDirectory.path) break;
    executableDirectory = parent;
  }

  for (final sdkRoot in sdkRoots) {
    for (final relativePath in const <String>[
      'packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt',
      'packages/flutter_tools/gradle/flutter.gradle',
      'packages/flutter_tools/lib/src/android/gradle_utils.dart',
    ]) {
      final file = File(_join(sdkRoot, relativePath));
      if (!file.existsSync()) continue;
      final content = await file.readAsString();
      final match = RegExp(
        r'targetSdkVersion(?:\s*:\s*Int)?\s*=\s*(\d+)',
      ).firstMatch(content);
      if (match != null) return int.parse(match.group(1)!);
    }
  }
  return null;
}

String _decodePropertiesPath(String value) {
  return value.replaceAll(r'\:', ':').replaceAll(r'\\', '\\');
}

void _writeReport(Directory root, ReleaseAuditReport report) {
  final facts = report.facts;
  stdout.writeln('Release Gate');
  stdout.writeln('Project: ${root.path}');
  stdout.writeln('');
  stdout.writeln('Detected settings');
  stdout.writeln('  pubspec.name: ${facts.pubspecName ?? '(not found)'}');
  stdout.writeln('  pubspec.version: ${facts.pubspecVersion ?? '(not found)'}');
  stdout.writeln('  versionName: ${facts.versionName ?? '(invalid)'}');
  stdout.writeln('  versionCode: ${facts.versionCode ?? '(invalid)'}');
  stdout.writeln('  applicationId: ${facts.applicationId ?? '(not found)'}');
  stdout.writeln(
    '  targetSdk: ${facts.targetSdk ?? '(unresolved)'} '
    '[${facts.targetSdkExpression ?? 'expression not found'}]',
  );
  stdout.writeln(
    '  Gradle versionName: '
    '${facts.gradleVersionNameExpression ?? '(not found)'}',
  );
  stdout.writeln(
    '  Gradle versionCode: '
    '${facts.gradleVersionCodeExpression ?? '(not found)'}',
  );
  stdout.writeln('  manifest label: ${facts.manifestLabel ?? '(not found)'}');
  stdout.writeln('  manifest icon: ${facts.manifestIcon ?? '(not found)'}');
  stdout.writeln('  permissions:');
  for (final permission in facts.permissions.toList()..sort()) {
    stdout.writeln('    - $permission');
  }
  stdout.writeln('');

  if (report.issues.isEmpty) {
    stdout.writeln('Issues: none');
  } else {
    stdout.writeln('Issues');
    for (final issue in report.issues) {
      final level = issue.severity == AuditSeverity.error ? 'ERROR' : 'WARN';
      stdout.writeln('  [$level] ${issue.code} (${issue.path})');
      stdout.writeln('    ${issue.message}');
    }
  }
  stdout.writeln('');
  stdout.writeln(
    report.passed
        ? 'RESULT: PASS (${report.warnings.length} warning(s))'
        : 'RESULT: FAIL (${report.errors.length} error(s), '
              '${report.warnings.length} warning(s))',
  );
}

String _relativePath(Directory root, File file) {
  final rootPath = root.absolute.path;
  final filePath = file.absolute.path;
  if (!filePath.startsWith(rootPath)) return filePath;
  var relative = filePath.substring(rootPath.length);
  if (relative.startsWith(Platform.pathSeparator)) {
    relative = relative.substring(1);
  }
  return relative.replaceAll(Platform.pathSeparator, '/');
}

String _join(String left, String right) {
  if (left.endsWith(Platform.pathSeparator)) return '$left$right';
  return '$left${Platform.pathSeparator}$right';
}
