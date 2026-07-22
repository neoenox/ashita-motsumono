// lib/src/release_audit.dart
//
// Release Gate 逶｣譟ｻ繝ｭ繧ｸ繝・け
// 繝ｪ繝ｪ繝ｼ繧ｹ蜑阪・險ｭ螳壹Α繧ｹ繧帝撕逧・↓讀懷・縺吶ｋ邏皮ｲ九↑Dart繝ｭ繧ｸ繝・け縲・// CLI縺ｮ陦ｨ遉ｺ蜃ｦ逅・ｄ邨ゆｺ・さ繝ｼ繝牙宛蠕｡繧貞性繧√★縲∫屮譟ｻ邨先棡縺ｮ縺ｿ繧定ｿ斐☆縲・
import 'dart:io';

/// 繝ｪ繝ｪ繝ｼ繧ｹ逶｣譟ｻ邨先棡縺ｮ驥崎ｦ∝ｺｦ縲・enum ReleaseCheckSeverity {
  error,
  warning,
  info,
}

/// 1莉ｶ縺ｮ繝ｪ繝ｪ繝ｼ繧ｹ逶｣譟ｻ邨先棡縲・class ReleaseCheckResult {
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

/// Flutter/Android繝励Ο繧ｸ繧ｧ繧ｯ繝医・繝ｪ繝ｪ繝ｼ繧ｹ蜿ｯ蜷ｦ繧帝撕逧・↓逶｣譟ｻ縺吶ｋ縲・///
/// CLI縺ｮ陦ｨ遉ｺ蜃ｦ逅・ｄ邨ゆｺ・さ繝ｼ繝牙宛蠕｡繧貞性繧√★縲∫屮譟ｻ邨先棡縺ｮ縺ｿ繧定ｿ斐☆縲・class ReleaseAudit {
  ReleaseAudit({Set<String>? localhostAllowlist})
      : localhostAllowlist = Set<String>.unmodifiable(
          localhostAllowlist ?? defaultLocalhostAllowlist,
        );

  /// localhost蜿ら・繧呈э蝗ｳ逧・↑螳牙・繧ｬ繝ｼ繝峨→縺励※險ｱ蜿ｯ縺吶ｋ譛ｬ逡ｪ繝輔ぃ繧､繝ｫ縲・  static const Set<String> defaultLocalhostAllowlist = <String>{
    'lib/src/services/gemini_api_service.dart',
  };

  static const String _adMobSampleId = 'ca-app-pub-3940256099942544';

  final Set<String> localhostAllowlist;

  /// 繝励Ο繧ｸ繧ｧ繧ｯ繝亥・菴薙ｒ逶｣譟ｻ縺吶ｋ縲・  List<ReleaseCheckResult> auditProject(Directory projectRoot) {
    final root = projectRoot.absolute;
    final results = <ReleaseCheckResult>[];

    final pubspec = _readFirstExisting(root, const <String>['pubspec.yaml']);
    if (pubspec == null) {
      results.add(
        const ReleaseCheckResult(
          id: 'project.pubspec',
          severity: ReleaseCheckSeverity.error,
          message: 'pubspec.yaml 縺瑚ｦ九▽縺九ｊ縺ｾ縺帙ｓ縲・,
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
          message: 'Android繧｢繝励Μ縺ｮGradle險ｭ螳壹′隕九▽縺九ｊ縺ｾ縺帙ｓ縲・,
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
          message: '繝｡繧､繝ｳ縺ｮAndroidManifest.xml縺瑚ｦ九▽縺九ｊ縺ｾ縺帙ｓ縲・,
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

  /// applicationId縺御ｻｮ蛟､縺ｧ縺ｪ縺・°遒ｺ隱阪☆繧九・  List<ReleaseCheckResult> checkApplicationId(
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
              'applicationId繧定ｧ｣豎ｺ縺ｧ縺阪∪縺帙ｓ縲よ枚蟄怜・繝ｪ繝・Λ繝ｫ縺ｧ謖・ｮ壹＠縺ｦ縺上□縺輔＞縲・,
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
              'applicationId "$applicationId" 縺ｯ莉ｮ蛟､縺ｧ縺吶よｭ｣蠑上↑ID縺ｸ螟画峩縺励※縺上□縺輔＞縲・,
          file: file,
          line: _lineNumberAt(gradleContent, match.start),
        ),
      ];
    }

    return <ReleaseCheckResult>[
      ReleaseCheckResult(
        id: 'android.application_id',
        severity: ReleaseCheckSeverity.info,
        message: 'applicationId縺ｯ豁｣蠑丞､縺ｧ縺・ $applicationId',
        file: file,
        line: _lineNumberAt(gradleContent, match.start),
      ),
    ];
  }

  /// pubspec.yaml縺ｮversion蠖｢蠑上ｒ遒ｺ隱阪☆繧九・  List<ReleaseCheckResult> checkPubspecVersion(
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
          message: 'pubspec.yaml縺ｫversion縺後≠繧翫∪縺帙ｓ縲・,
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
              'version "$version" 縺ｯ major.minor.patch+build 蠖｢蠑上〒縺ｯ縺ゅｊ縺ｾ縺帙ｓ縲・,
          file: file,
          line: _lineNumberAt(pubspecContent, match.start),
        ),
      ];
    }

    return <ReleaseCheckResult>[
      ReleaseCheckResult(
        id: 'pubspec.version',
        severity: ReleaseCheckSeverity.info,
        message: 'version蠖｢蠑上・豁｣蟶ｸ縺ｧ縺・ $version',
        file: file,
        line: _lineNumberAt(pubspecContent, match.start),
      ),
    ];
  }

  /// Gradle險ｭ螳壹°繧液argetSdk繧定ｧ｣豎ｺ縺励※逶｣譟ｻ縺吶ｋ縲・  List<ReleaseCheckResult> checkTargetSdkConfiguration(
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
          source: 'Gradle縺ｮ譏守､ｺ謖・ｮ・,
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
                'flutter.targetSdkVersion縺ｮ螳溷､繧巽lutter SDK縺九ｉ隗｣豎ｺ縺ｧ縺阪∪縺帙ｓ縲・
                ' android/local.properties縺ｮflutter.sdk縲：LUTTER_ROOT縲√∪縺溘・PATH繧堤｢ｺ隱阪＠縺ｦ縺上□縺輔＞縲・,
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
        message: 'targetSdk繧竪radle險ｭ螳壹°繧芽ｧ｣豎ｺ縺ｧ縺阪∪縺帙ｓ縲・,
        file: file,
      ),
    ];
  }

  /// 隗｣豎ｺ貂医∩targetSdk蛟､繧貞愛螳壹☆繧九・  List<ReleaseCheckResult> checkTargetSdkValue(
    int targetSdk, {
    String? file,
    int? line,
    String? source,
  }) {
    final sourceSuffix = source == null ? '' : '・・source・・;
    if (targetSdk <= 34) {
      return <ReleaseCheckResult>[
        ReleaseCheckResult(
          id: 'android.target_sdk',
          severity: ReleaseCheckSeverity.error,
          message:
              'targetSdk=$targetSdk 縺ｯ34莉･荳九〒縺吶・5莉･荳翫∈譖ｴ譁ｰ縺励※縺上□縺輔＞$sourceSuffix縲・,
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
              'targetSdk=35縺ｧ縺吶りｦ∽ｻｶ縺ｯ貅縺溘＠縺ｾ縺吶′縲・6莉･荳翫∈縺ｮ譖ｴ譁ｰ繧呈耳螂ｨ縺励∪縺・sourceSuffix縲・,
          file: file,
          line: line,
        ),
      ];
    }

    return <ReleaseCheckResult>[
      ReleaseCheckResult(
        id: 'android.target_sdk',
        severity: ReleaseCheckSeverity.info,
        message: 'targetSdk=$targetSdk 縺ｯ蜷域ｼ縺ｧ縺・sourceSuffix縲・,
        file: file,
        line: line,
      ),
    ];
  }

  /// Flutter SDK蜀・・FlutterExtension縺九ｉtargetSdkVersion繧定ｧ｣豎ｺ縺吶ｋ縲・  ResolvedFlutterTargetSdk? resolveFlutterTargetSdk(Directory projectRoot) {
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

  /// release縺ｫ蠖ｱ髻ｿ縺吶ｋ險ｭ螳壹↓debuggable=true縺後↑縺・°遒ｺ隱阪☆繧九・  List<ReleaseCheckResult> checkDebuggable(Map<String, String> files) {
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
              message: '繝ｪ繝ｪ繝ｼ繧ｹ險ｭ螳壹↓debuggable=true縺後≠繧翫∪縺吶・,
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
            'release蟇ｾ雎｡縺ｫdebuggable=true縺ｯ縺ゅｊ縺ｾ縺帙ｓ縲よ悴謖・ｮ壽凾縺ｮ譌｢螳壼､縺ｯfalse縺ｧ縺吶・,
      ),
    ];
  }

  /// usesCleartextTraffic=true縺後↑縺・°遒ｺ隱阪☆繧九・  List<ReleaseCheckResult> checkUsesCleartextTraffic(
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
                  'usesCleartextTraffic=true縺後≠繧翫∪縺吶・TTPS騾壻ｿ｡縺ｸ髯仙ｮ壹＠縺ｦ縺上□縺輔＞縲・,
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
        message: 'release蟇ｾ雎｡縺ｫusesCleartextTraffic=true縺ｯ縺ゅｊ縺ｾ縺帙ｓ縲・,
      ),
    ];
  }

  /// lib/驟堺ｸ九・繝ｭ繝ｼ繧ｫ繝ｫ謗･邯壼・繧呈､懷・縺吶ｋ縲・  List<ReleaseCheckResult> checkLocalhostReferences(
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
                '譛ｬ逡ｪ繧ｳ繝ｼ繝峨↓繝ｭ繝ｼ繧ｫ繝ｫ謗･邯壼・ "${match.group(0)}" 縺後≠繧翫∪縺吶・,
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
            message: 'allowlist蟇ｾ雎｡縺ｮ繝ｭ繝ｼ繧ｫ繝ｫ謗･邯壼・繧・allowedCount莉ｶ險ｱ蜿ｯ縺励∪縺励◆縲・,
          ),
        );
      }
      return findings;
    }

    final allowlistMessage = allowedCount == 0
        ? ''
        : ' allowlist蟇ｾ雎｡縺ｮ$allowedCount莉ｶ縺ｯ諢丞峙逧・↑繧ｬ繝ｼ繝峨→縺励※險ｱ蜿ｯ縺励∪縺励◆縲・;
    return <ReleaseCheckResult>[
      ReleaseCheckResult(
        id: 'source.local_endpoint',
        severity: ReleaseCheckSeverity.info,
        message: '譛ｪ險ｱ蜿ｯ縺ｮlocalhost邉ｻ蜿ら・縺ｯ縺ゅｊ縺ｾ縺帙ｓ縲・allowlistMessage',
      ),
    ];
  }

  /// AdMob縺ｮ蜈ｬ蠑上し繝ｳ繝励ΝID繧呈､懷・縺吶ｋ縲・  List<ReleaseCheckResult> checkAdMobSampleIds(Map<String, String> files) {
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
                'AdMob繧ｵ繝ｳ繝励ΝID $_adMobSampleId 縺梧悽逡ｪ繝輔ぃ繧､繝ｫ縺ｫ縺ゅｊ縺ｾ縺吶・,
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
        message: '譛ｬ逡ｪ繝輔ぃ繧､繝ｫ縺ｫAdMob繧ｵ繝ｳ繝励ΝID縺ｯ縺ゅｊ縺ｾ縺帙ｓ縲・,
      ),
    ];
  }

  /// AndroidManifest.xml縺ｮlabel縺ｨicon繧堤｢ｺ隱阪☆繧九・  List<ReleaseCheckResult> checkManifestLabelAndIcon(
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
          message: 'AndroidManifest.xml縺ｫapplication隕∫ｴ縺後≠繧翫∪縺帙ｓ縲・,
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
              'application隕∫ｴ縺ｫ${missing.join(' 縺ｨ ')}縺後≠繧翫∪縺帙ｓ縲・,
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
            'Manifest縺ｮlabel=$labelValue縲（con=$iconValue縺ｧ縺吶・,
        file: file,
        line: _lineNumberAt(manifestContent, applicationMatch.start),
      ),
    ];
  }

  /// AndroidManifest.xml縺ｮ螳｣險讓ｩ髯舌ｒ諠・ｱ縺ｨ縺励※荳隕ｧ蛹悶☆繧九・  List<ReleaseCheckResult> listManifestPermissions(
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
        ? 'Manifest縺ｫuses-permission螳｣險縺ｯ縺ゅｊ縺ｾ縺帙ｓ縲・
        : 'Manifest螳｣險讓ｩ髯・(${permissions.length}莉ｶ): ${permissions.join(', ')}';
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
        // 隱ｭ縺ｿ蜿悶ｌ縺ｪ縺・函謌千黄繧・ヰ繧､繝翫Μ逶ｸ蠖薙ヵ繧｡繧､繝ｫ縺ｯ逶｣譟ｻ蟇ｾ雎｡螟悶→縺吶ｋ縲・      }
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

/// Flutter SDK縺九ｉ隗｣豎ｺ縺励◆targetSdkVersion縺ｮ隧ｳ邏ｰ縲・class ResolvedFlutterTargetSdk {
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
