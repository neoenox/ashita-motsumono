// lib/src/release_audit.dart
//
// Release Gate 監査ロジック
// リリース前の設定ミスを静的に検出する純粋なDartロジック。
// CLIの表示処理や終了コード制御を含めず、監査結果のみを返す。

import 'dart:io';

/// リリース監査結果の重要度。
enum ReleaseCheckSeverity {
  error,
  warning,
  info,
}

/// 1件のリリース監査結果。
class ReleaseCheckResult {
  const ReleaseCheckResult({
    required this.id,
    required this.severity,
    required this.message,
    this.file,
    this.line,
  });

  final String id;
  final ReleaseCheckSeverity severity;
  final String message;
  final String? file;
  final int? line;

  bool get isError => severity == ReleaseCheckSeverity.error;
  bool get isWarning => severity == ReleaseCheckSeverity.warning;
}

/// Flutter/Androidプロジェクトのリリース可否を静的に監査する。
///
/// CLIの表示処理や終了コード制御を含めず、監査結果のみを返す。
class ReleaseAudit {
  ReleaseAudit({Set<String>? localhostAllowlist})
      : localhostAllowlist = Set<String>.unmodifiable(
          localhostAllowlist ?? defaultLocalhostAllowlist,
        );

  /// localhost参照を意図的な安全ガードとして許可する本番ファイル。
  static const Set<String> defaultLocalhostAllowlist = <String>{
    'lib/src/services/gemini_api_service.dart',
  };

  static const String _adMobSampleId = 'ca-app-pub-3940256099942544';

  final Set<String> localhostAllowlist;

  /// プロジェクト全体を監査する。
  List<ReleaseCheckResult> auditProject(Directory projectRoot) {
    final root = projectRoot.absolute;
    final results = <ReleaseCheckResult>[];

    final pubspec = _readFirstExisting(root, const <String>['pubspec.yaml']);
    if (pubspec == null) {
      results.add(
        const ReleaseCheckResult(
          id: 'project.pubspec',
          severity: ReleaseCheckSeverity.error,
          message: 'pubspec.yaml が見つかりません。',
          file: 'pubspec.yaml',
        ),
      );
    } else {
      results.addAll(
        checkPubspecVersion(pubspec.content, file: pubspec.relativePath),
      );
    }

    final appGradle = _readFirstExisting(
      root,
      const <String>[
        'android/app/build.gradle.kts',
        'android/app/build.gradle',
      ],
    );
    if (appGradle == null) {
      results.add(
        const ReleaseCheckResult(
          id: 'android.app_gradle',
          severity: ReleaseCheckSeverity.error,
          message: 'AndroidアプリのGradle設定が見つかりません。',
          file: 'android/app/build.gradle.kts',
        ),
      );
    } else {
      results.addAll(
        checkApplicationId(appGradle.content, file: appGradle.relativePath),
      );
      results.addAll(
        checkTargetSdkConfiguration(
          appGradle.content,
          projectRoot: root,
          file: appGradle.relativePath,
        ),
      );
    }

    final mainManifest = _readFirstExisting(
      root,
      const <String>['android/app/src/main/AndroidManifest.xml'],
    );
    if (mainManifest == null) {
      results.add(
        const ReleaseCheckResult(
          id: 'android.manifest',
          severity: ReleaseCheckSeverity.error,
          message: 'メインのAndroidManifest.xmlが見つかりません。',
          file: 'android/app/src/main/AndroidManifest.xml',
        ),
      );
    } else {
      results.addAll(
        checkManifestLabelAndIcon(
          mainManifest.content,
          file: mainManifest.relativePath,
        ),
      );
      results.addAll(
        listManifestPermissions(
          mainManifest.content,
          file: mainManifest.relativePath,
        ),
      );
    }

    final releaseXmlFiles = <String, String>{};
    if (mainManifest != null) {
      releaseXmlFiles[mainManifest.relativePath] = mainManifest.content;
    }
    final releaseManifest = _readFirstExisting(
      root,
      const <String>['android/app/src/release/AndroidManifest.xml'],
    );
    if (releaseManifest != null) {
      releaseXmlFiles[releaseManifest.relativePath] = releaseManifest.content;
    }

    if (appGradle != null) {
      releaseXmlFiles[appGradle.relativePath] = appGradle.content;
    }

    results.addAll(checkDebuggable(releaseXmlFiles));
    results.addAll(checkUsesCleartextTraffic(releaseXmlFiles));

    final dartFiles = _collectTextFiles(
      root,
      'lib',
      const <String>{'.dart'},
    );
    results.addAll(checkLocalhostReferences(dartFiles));

    final productionFiles = <String, String>{...dartFiles};
    productionFiles.addAll(
      _collectTextFiles(
        root,
        'android',
        const <String>{
          '.xml',
          '.kt',
          '.java',
          '.gradle',
          '.kts',
          '.properties',
        },
        excludedPathSegments: const <String>{'.gradle', 'build'},
      ),
    );
    results.addAll(checkAdMobSampleIds(productionFiles));

    return results;
  }

  /// applicationIdが仮値でないか確認する。
  List<ReleaseCheckResult> checkApplicationId(
    String gradleContent, {
    String file = 'android/app/build.gradle.kts',
  }) {
    final pattern = RegExp(
      r'''^\s*applicationId\s*(?:=|\s)\s*["']([^"']+)["']''',
      multiLine: true,
    );
    final match = pattern.firstMatch(gradleContent);
    if (match == null) {
      return <ReleaseCheckResult>[
        ReleaseCheckResult(
          id: 'android.application_id',
          severity: ReleaseCheckSeverity.error,
          message:
              'applicationIdを解決できません。文字列リテラルで指定してください。',
          file: file,
        ),
      ];
    }

    final applicationId = match.group(1)!;
    final normalized = applicationId.toLowerCase();
    final placeholderPatterns = <RegExp>[
      RegExp(r'^(com|org|net)\.example(?:\.|$)'),
      RegExp(r'^(com|org|net)\.your(?:company|_company)(?:\.|$)'),
      RegExp(r'^io\.flutter\.demo(?:\.|$)'),
      RegExp(r'^(replace|change)\.me(?:\.|$)'),
    ];
    final isPlaceholder = placeholderPatterns.any(
      (pattern) => pattern.hasMatch(normalized),
    );

    if (isPlaceholder) {
      return <ReleaseCheckResult>[
        ReleaseCheckResult(
          id: 'android.application_id',
          severity: ReleaseCheckSeverity.error,
          message:
              'applicationId "$applicationId" は仮値です。正式なIDへ変更してください。',
          file: file,
          line: _lineNumberAt(gradleContent, match.start),
        ),
      ];
    }

    return <ReleaseCheckResult>[
      ReleaseCheckResult(
        id: 'android.application_id',
        severity: ReleaseCheckSeverity.info,
        message: 'applicationIdは正式値です: $applicationId',
        file: file,
        line: _lineNumberAt(gradleContent, match.start),
      ),
    ];
  }

  /// pubspec.yamlのversion形式を確認する。
  List<ReleaseCheckResult> checkPubspecVersion(
    String pubspecContent, {
    String file = 'pubspec.yaml',
  }) {
    final declarationPattern = RegExp(
      r'''^\s*version\s*:\s*["']?([^\s#"']+)["']?\s*(?:#.*)?$''',
      multiLine: true,
    );
    final match = declarationPattern.firstMatch(pubspecContent);
    if (match == null) {
      return <ReleaseCheckResult>[
        ReleaseCheckResult(
          id: 'pubspec.version',
          severity: ReleaseCheckSeverity.error,
          message: 'pubspec.yamlにversionがありません。',
          file: file,
        ),
      ];
    }

    final version = match.group(1)!;
    final validPattern = RegExp(r'^\d+\.\d+\.\d+\+\d+$');
    if (!validPattern.hasMatch(version)) {
      return <ReleaseCheckResult>[
        ReleaseCheckResult(
          id: 'pubspec.version',
          severity: ReleaseCheckSeverity.error,
          message:
              'version "$version" は major.minor.patch+build 形式ではありません。',
          file: file,
          line: _lineNumberAt(pubspecContent, match.start),
        ),
      ];
    }

    return <ReleaseCheckResult>[
      ReleaseCheckResult(
        id: 'pubspec.version',
        severity: ReleaseCheckSeverity.info,
        message: 'version形式は正常です: $version',
        file: file,
        line: _lineNumberAt(pubspecContent, match.start),
      ),
    ];
  }

  /// Gradle設定からtargetSdkを解決して監査する。
  List<ReleaseCheckResult> checkTargetSdkConfiguration(
    String gradleContent, {
    required Directory projectRoot,
    String file = 'android/app/build.gradle.kts',
  }) {
    final explicitPatterns = <RegExp>[
      RegExp(r'^\s*targetSdk\s*=\s*(\d+)\b', multiLine: true),
      RegExp(
        r'^\s*targetSdkVersion\s*=\s*(\d+)\b',
        multiLine: true,
      ),
      RegExp(
        r'^\s*targetSdkVersion\s+(\d+)\b',
        multiLine: true,
      ),
      RegExp(
        r'^\s*targetSdkVersion\s*\(\s*(\d+)\s*\)',
        multiLine: true,
      ),
    ];

    for (final pattern in explicitPatterns) {
      final match = pattern.firstMatch(gradleContent);
      if (match != null) {
        return checkTargetSdkValue(
          int.parse(match.group(1)!),
          file: file,
          line: _lineNumberAt(gradleContent, match.start),
          source: 'Gradleの明示指定',
        );
      }
    }

    if (gradleContent.contains('flutter.targetSdkVersion')) {
      final resolved = resolveFlutterTargetSdk(projectRoot);
      if (resolved == null) {
        final match =
            RegExp(r'flutter\.targetSdkVersion').firstMatch(gradleContent);
        return <ReleaseCheckResult>[
          ReleaseCheckResult(
            id: 'android.target_sdk',
            severity: ReleaseCheckSeverity.error,
            message:
                'flutter.targetSdkVersionの実値をFlutter SDKから解決できません。'
                ' android/local.propertiesのflutter.sdk、FLUTTER_ROOT、またはPATHを確認してください。',
            file: file,
            line:
                match == null ? null : _lineNumberAt(gradleContent, match.start),
          ),
        ];
      }

      return checkTargetSdkValue(
        resolved.value,
        file: resolved.relativeSource,
        line: resolved.line,
        source: 'Flutter SDK (${resolved.flutterSdkPath})',
      );
    }

    return <ReleaseCheckResult>[
      ReleaseCheckResult(
        id: 'android.target_sdk',
        severity: ReleaseCheckSeverity.error,
        message: 'targetSdkをGradle設定から解決できません。',
        file: file,
      ),
    ];
  }

  /// 解決済みtargetSdk値を判定する。
  List<ReleaseCheckResult> checkTargetSdkValue(
    int targetSdk, {
    String? file,
    int? line,
    String? source,
  }) {
    final sourceSuffix = source == null ? '' : '（$source）';
    if (targetSdk <= 34) {
      return <ReleaseCheckResult>[
        ReleaseCheckResult(
          id: 'android.target_sdk',
          severity: ReleaseCheckSeverity.error,
          message:
              'targetSdk=$targetSdk は34以下です。35以上へ更新してください$sourceSuffix。',
          file: file,
          line: line,
        ),
      ];
    }

    if (targetSdk == 35) {
      return <ReleaseCheckResult>[
        ReleaseCheckResult(
          id: 'android.target_sdk',
          severity: ReleaseCheckSeverity.warning,
          message:
              'targetSdk=35です。要件は満たしますが、36以上への更新を推奨します$sourceSuffix。',
          file: file,
          line: line,
        ),
      ];
    }

    return <ReleaseCheckResult>[
      ReleaseCheckResult(
        id: 'android.target_sdk',
        severity: ReleaseCheckSeverity.info,
        message: 'targetSdk=$targetSdk は合格です$sourceSuffix。',
        file: file,
        line: line,
      ),
    ];
  }

  /// Flutter SDK内のFlutterExtensionからtargetSdkVersionを解決する。
  ResolvedFlutterTargetSdk? resolveFlutterTargetSdk(Directory projectRoot) {
    final flutterRoot = _resolveFlutterSdkRoot(projectRoot.absolute);
    if (flutterRoot == null) {
      return null;
    }

    final candidates = <String>[
      'packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt',
      'packages/flutter_tools/gradle/src/main/groovy/flutter.groovy',
      'packages/flutter_tools/gradle/flutter.gradle',
      'packages/flutter_tools/lib/src/android/gradle_utils.dart',
    ];
    final valuePatterns = <RegExp>[
      RegExp(r'\btargetSdkVersion\s*:\s*Int\s*=\s*(\d+)\b'),
      RegExp(r'\btargetSdkVersion\s*=\s*(\d+)\b'),
      RegExp(r'\btargetSdkVersion\s+(\d+)\b'),
    ];

    for (final relativePath in candidates) {
      final file = File(_join(flutterRoot.path, relativePath));
      if (!file.existsSync()) {
        continue;
      }

      final content = file.readAsStringSync();
      for (final pattern in valuePatterns) {
        final match = pattern.firstMatch(content);
        if (match == null) {
          continue;
        }

        return ResolvedFlutterTargetSdk(
          value: int.parse(match.group(1)!),
          flutterSdkPath: flutterRoot.path,
          relativeSource: _normalizePath(relativePath),
          line: _lineNumberAt(content, match.start),
        );
      }
    }

    return null;
  }

  /// releaseに影響する設定にdebuggable=trueがないか確認する。
  List<ReleaseCheckResult> checkDebuggable(Map<String, String> files) {
    final patterns = <RegExp>[
      RegExp(
        r'''android:debuggable\s*=\s*["']true["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(?:isDebuggable|debuggable)\s*=\s*true\b',
        caseSensitive: false,
      ),
      RegExp(
        r'\bdebuggable\s+true\b',
        caseSensitive: false,
      ),
    ];
    final findings = <ReleaseCheckResult>[];

    for (final entry in files.entries) {
      for (final pattern in patterns) {
        for (final match in pattern.allMatches(entry.value)) {
          findings.add(
            ReleaseCheckResult(
              id: 'android.debuggable',
              severity: ReleaseCheckSeverity.error,
              message: 'リリース設定にdebuggable=trueがあります。',
              file: entry.key,
              line: _lineNumberAt(entry.value, match.start),
            ),
          );
        }
      }
    }

    if (findings.isNotEmpty) {
      return findings;
    }

    return const <ReleaseCheckResult>[
      ReleaseCheckResult(
        id: 'android.debuggable',
        severity: ReleaseCheckSeverity.info,
        message:
            'release対象にdebuggable=trueはありません。未指定時の既定値はfalseです。',
      ),
    ];
  }

  /// usesCleartextTraffic=trueがないか確認する。
  List<ReleaseCheckResult> checkUsesCleartextTraffic(
    Map<String, String> files,
  ) {
    final patterns = <RegExp>[
      RegExp(
        r'''android:usesCleartextTraffic\s*=\s*["']true["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'\busesCleartextTraffic\s*=\s*true\b',
        caseSensitive: false,
      ),
    ];
    final findings = <ReleaseCheckResult>[];

    for (final entry in files.entries) {
      for (final pattern in patterns) {
        for (final match in pattern.allMatches(entry.value)) {
          findings.add(
            ReleaseCheckResult(
              id: 'android.cleartext_traffic',
              severity: ReleaseCheckSeverity.error,
              message:
                  'usesCleartextTraffic=trueがあります。HTTPS通信へ限定してください。',
              file: entry.key,
              line: _lineNumberAt(entry.value, match.start),
            ),
          );
        }
      }
    }

    if (findings.isNotEmpty) {
      return findings;
    }

    return const <ReleaseCheckResult>[
      ReleaseCheckResult(
        id: 'android.cleartext_traffic',
        severity: ReleaseCheckSeverity.info,
        message: 'release対象にusesCleartextTraffic=trueはありません。',
      ),
    ];
  }

  /// lib/配下のローカル接続先を検出する。
  List<ReleaseCheckResult> checkLocalhostReferences(
    Map<String, String> files,
  ) {
    final endpointPattern = RegExp(
      r'localhost|127\.0\.0\.1|10\.0\.2\.2',
      caseSensitive: false,
    );
    final findings = <ReleaseCheckResult>[];
    var allowedCount = 0;

    for (final entry in files.entries) {
      final normalizedPath = _normalizePath(entry.key);
      final isAllowed = localhostAllowlist.any(
        (allowedPath) =>
            _normalizePath(allowedPath).toLowerCase() ==
            normalizedPath.toLowerCase(),
      );
      final matches = endpointPattern.allMatches(entry.value).toList();
      if (matches.isEmpty) {
        continue;
      }

      if (isAllowed) {
        allowedCount += matches.length;
        continue;
      }

      for (final match in matches) {
        findings.add(
          ReleaseCheckResult(
            id: 'source.local_endpoint',
            severity: ReleaseCheckSeverity.error,
            message:
                '本番コードにローカル接続先 "${match.group(0)}" があります。',
            file: normalizedPath,
            line: _lineNumberAt(entry.value, match.start),
          ),
        );
      }
    }

    if (findings.isNotEmpty) {
      if (allowedCount > 0) {
        findings.add(
          ReleaseCheckResult(
            id: 'source.local_endpoint_allowlist',
            severity: ReleaseCheckSeverity.info,
            message: 'allowlist対象のローカル接続先を$allowedCount件許可しました。',
          ),
        );
      }
      return findings;
    }

    final allowlistMessage = allowedCount == 0
        ? ''
        : ' allowlist対象の$allowedCount件は意図的なガードとして許可しました。';
    return <ReleaseCheckResult>[
      ReleaseCheckResult(
        id: 'source.local_endpoint',
        severity: ReleaseCheckSeverity.info,
        message: '未許可のlocalhost系参照はありません。$allowlistMessage',
      ),
    ];
  }

  /// AdMobの公式サンプルIDを検出する。
  List<ReleaseCheckResult> checkAdMobSampleIds(Map<String, String> files) {
    final findings = <ReleaseCheckResult>[];

    for (final entry in files.entries) {
      var searchStart = 0;
      while (true) {
        final index = entry.value.indexOf(_adMobSampleId, searchStart);
        if (index < 0) {
          break;
        }
        findings.add(
          ReleaseCheckResult(
            id: 'admob.sample_id',
            severity: ReleaseCheckSeverity.error,
            message:
                'AdMobサンプルID $_adMobSampleId が本番ファイルにあります。',
            file: _normalizePath(entry.key),
            line: _lineNumberAt(entry.value, index),
          ),
        );
        searchStart = index + _adMobSampleId.length;
      }
    }

    if (findings.isNotEmpty) {
      return findings;
    }

    return const <ReleaseCheckResult>[
      ReleaseCheckResult(
        id: 'admob.sample_id',
        severity: ReleaseCheckSeverity.info,
        message: '本番ファイルにAdMobサンプルIDはありません。',
      ),
    ];
  }

  /// AndroidManifest.xmlのlabelとiconを確認する。
  List<ReleaseCheckResult> checkManifestLabelAndIcon(
    String manifestContent, {
    String file = 'android/app/src/main/AndroidManifest.xml',
  }) {
    final applicationPattern = RegExp(
      r'<application\b([^>]*)>',
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    final applicationMatch = applicationPattern.firstMatch(manifestContent);
    if (applicationMatch == null) {
      return <ReleaseCheckResult>[
        ReleaseCheckResult(
          id: 'android.manifest_identity',
          severity: ReleaseCheckSeverity.error,
          message: 'AndroidManifest.xmlにapplication要素がありません。',
          file: file,
        ),
      ];
    }

    final attributes = applicationMatch.group(1)!;
    final labelMatch = RegExp(
      r'''android:label\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(attributes);
    final iconMatch = RegExp(
      r'''android:icon\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(attributes);

    final labelValue = labelMatch?.group(1);
    final iconValue = iconMatch?.group(1);

    final missing = <String>[];
    if (labelValue == null) {
      missing.add('android:label');
    }
    if (iconValue == null) {
      missing.add('android:icon');
    }

    if (missing.isNotEmpty) {
      return <ReleaseCheckResult>[
        ReleaseCheckResult(
          id: 'android.manifest_identity',
          severity: ReleaseCheckSeverity.error,
          message:
              'application要素に${missing.join(' と ')}がありません。',
          file: file,
          line: _lineNumberAt(manifestContent, applicationMatch.start),
        ),
      ];
    }

    return <ReleaseCheckResult>[
      ReleaseCheckResult(
        id: 'android.manifest_identity',
        severity: ReleaseCheckSeverity.info,
        message:
            'Manifestのlabel=$labelValue、icon=$iconValueです。',
        file: file,
        line: _lineNumberAt(manifestContent, applicationMatch.start),
      ),
    ];
  }

  /// AndroidManifest.xmlの宣言権限を情報として一覧化する。
  List<ReleaseCheckResult> listManifestPermissions(
    String manifestContent, {
    String file = 'android/app/src/main/AndroidManifest.xml',
  }) {
    final permissionPattern = RegExp(
      r'''<uses-permission(?:-sdk-\d+)?\b[^>]*android:name\s*=\s*["']([^"']+)["'][^>]*/?>''',
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    final permissions = permissionPattern
        .allMatches(manifestContent)
        .map((match) => match.group(1)!)
        .toSet()
        .toList()
      ..sort();

    final message = permissions.isEmpty
        ? 'Manifestにuses-permission宣言はありません。'
        : 'Manifest宣言権限 (${permissions.length}件): ${permissions.join(', ')}';
    return <ReleaseCheckResult>[
      ReleaseCheckResult(
        id: 'android.permissions',
        severity: ReleaseCheckSeverity.info,
        message: message,
        file: file,
      ),
    ];
  }

  Directory? _resolveFlutterSdkRoot(Directory projectRoot) {
    final candidates = <String>[];

    final localProperties = File(
      _join(projectRoot.path, 'android/local.properties'),
    );
    if (localProperties.existsSync()) {
      for (final line in localProperties.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.startsWith('flutter.sdk=')) {
          final rawValue = trimmed.substring('flutter.sdk='.length).trim();
          if (rawValue.isNotEmpty) {
            candidates.add(_decodeJavaPropertiesValue(rawValue));
          }
        }
      }
    }

    final flutterRootEnvironment = Platform.environment['FLUTTER_ROOT'];
    if (flutterRootEnvironment != null &&
        flutterRootEnvironment.trim().isNotEmpty) {
      candidates.add(flutterRootEnvironment.trim());
    }

    final executablePath = _normalizePath(Platform.resolvedExecutable);
    final marker = '/bin/cache/dart-sdk/';
    final markerIndex = executablePath.toLowerCase().indexOf(marker);
    if (markerIndex > 0) {
      candidates.add(executablePath.substring(0, markerIndex));
    }

    final pathEnvironment =
        Platform.environment['PATH'] ?? Platform.environment['Path'];
    if (pathEnvironment != null) {
      final executableNames = Platform.isWindows
          ? const <String>['flutter.bat', 'flutter.exe', 'flutter']
          : const <String>['flutter'];
      for (final directoryPath in pathEnvironment.split(
        Platform.isWindows ? ';' : ':',
      )) {
        if (directoryPath.trim().isEmpty) {
          continue;
        }
        for (final executableName in executableNames) {
          final executable =
              File(_join(directoryPath.trim(), executableName));
          if (executable.existsSync()) {
            try {
              final resolvedExecutable =
                  File(executable.resolveSymbolicLinksSync());
              candidates.add(resolvedExecutable.parent.parent.path);
            } on FileSystemException {
              candidates.add(executable.parent.parent.path);
            }
          }
        }
      }
    }

    final seen = <String>{};
    for (final candidate in candidates) {
      final directory = Directory(candidate).absolute;
      final normalized = _normalizePath(directory.path).toLowerCase();
      if (!seen.add(normalized)) {
        continue;
      }
      final flutterTools =
          Directory(_join(directory.path, 'packages/flutter_tools'));
      if (flutterTools.existsSync()) {
        return directory;
      }
    }

    return null;
  }

  _LoadedTextFile? _readFirstExisting(
    Directory root,
    List<String> relativePaths,
  ) {
    for (final relativePath in relativePaths) {
      final file = File(_join(root.path, relativePath));
      if (!file.existsSync()) {
        continue;
      }
      return _LoadedTextFile(
        relativePath: _normalizePath(relativePath),
        content: file.readAsStringSync(),
      );
    }
    return null;
  }

  Map<String, String> _collectTextFiles(
    Directory root,
    String relativeDirectory,
    Set<String> allowedExtensions, {
    Set<String> excludedPathSegments = const <String>{},
  }) {
    final directory = Directory(_join(root.path, relativeDirectory));
    if (!directory.existsSync()) {
      return <String, String>{};
    }

    final result = <String, String>{};
    for (final entity in directory.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final normalized = _normalizePath(entity.path);
      final lowerPath = normalized.toLowerCase();
      final pathSegments = lowerPath.split('/').toSet();
      if (excludedPathSegments.any(
        (segment) => pathSegments.contains(segment.toLowerCase()),
      )) {
        continue;
      }
      if (!allowedExtensions.any(lowerPath.endsWith)) {
        continue;
      }

      final relativePath = _relativePath(root, entity);
      try {
        result[relativePath] = entity.readAsStringSync();
      } on FileSystemException {
        // 読み取れない生成物やバイナリ相当ファイルは監査対象外とする。
      }
    }
    return result;
  }

  static int _lineNumberAt(String content, int index) {
    if (index <= 0) {
      return 1;
    }
    return '\n'.allMatches(content.substring(0, index)).length + 1;
  }

  static String _relativePath(Directory root, File file) {
    final rootPath = _normalizePath(root.absolute.path);
    final filePath = _normalizePath(file.absolute.path);
    final rootPrefix = rootPath.endsWith('/') ? rootPath : '$rootPath/';
    if (filePath.toLowerCase().startsWith(rootPrefix.toLowerCase())) {
      return filePath.substring(rootPrefix.length);
    }
    return filePath;
  }

  static String _decodeJavaPropertiesValue(String value) {
    return value
        .replaceAll(r'\:', ':')
        .replaceAll(r'\=', '=')
        .replaceAll('\\\\', '\\');
  }

  static String _join(String base, String relativePath) {
    final platformRelativePath = relativePath
        .replaceAll('/', Platform.pathSeparator)
        .replaceAll('\\', Platform.pathSeparator);
    if (base.endsWith(Platform.pathSeparator)) {
      return '$base$platformRelativePath';
    }
    return '$base${Platform.pathSeparator}$platformRelativePath';
  }

  static String _normalizePath(String path) => path.replaceAll('\\', '/');
}

/// Flutter SDKから解決したtargetSdkVersionの詳細。
class ResolvedFlutterTargetSdk {
  const ResolvedFlutterTargetSdk({
    required this.value,
    required this.flutterSdkPath,
    required this.relativeSource,
    required this.line,
  });

  final int value;
  final String flutterSdkPath;
  final String relativeSource;
  final int line;
}

class _LoadedTextFile {
  const _LoadedTextFile({
    required this.relativePath,
    required this.content,
  });

  final String relativePath;
  final String content;
}
