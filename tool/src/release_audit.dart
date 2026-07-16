enum AuditSeverity { error, warning }

final class AuditIssue {
  const AuditIssue({
    required this.severity,
    required this.code,
    required this.message,
    required this.path,
  });

  final AuditSeverity severity;
  final String code;
  final String message;
  final String path;
}

final class ReleaseAuditInput {
  const ReleaseAuditInput({
    required this.pubspecContent,
    required this.gradleContent,
    required this.manifestContent,
    required this.productionFiles,
    this.gradlePath = 'android/app/build.gradle.kts',
    this.manifestPath = 'android/app/src/main/AndroidManifest.xml',
    this.resolvedFlutterTargetSdk,
    this.releaseEnvironment = const <String, String>{},
  });

  final String pubspecContent;
  final String gradleContent;
  final String manifestContent;
  final Map<String, String> productionFiles;
  final String gradlePath;
  final String manifestPath;
  final int? resolvedFlutterTargetSdk;
  final Map<String, String> releaseEnvironment;
}

final class ReleaseAuditFacts {
  const ReleaseAuditFacts({
    required this.pubspecName,
    required this.pubspecVersion,
    required this.versionName,
    required this.versionCode,
    required this.applicationId,
    required this.targetSdkExpression,
    required this.targetSdk,
    required this.gradleVersionNameExpression,
    required this.gradleVersionCodeExpression,
    required this.manifestLabel,
    required this.manifestIcon,
    required this.permissions,
  });

  final String? pubspecName;
  final String? pubspecVersion;
  final String? versionName;
  final int? versionCode;
  final String? applicationId;
  final String? targetSdkExpression;
  final int? targetSdk;
  final String? gradleVersionNameExpression;
  final String? gradleVersionCodeExpression;
  final String? manifestLabel;
  final String? manifestIcon;
  final Set<String> permissions;
}

final class ReleaseAuditReport {
  const ReleaseAuditReport({required this.facts, required this.issues});

  final ReleaseAuditFacts facts;
  final List<AuditIssue> issues;

  Iterable<AuditIssue> get errors =>
      issues.where((issue) => issue.severity == AuditSeverity.error);

  Iterable<AuditIssue> get warnings =>
      issues.where((issue) => issue.severity == AuditSeverity.warning);

  bool get passed => errors.isEmpty;
}

final class ReleaseAudit {
  ReleaseAudit._();

  static const _googleSampleAdMobPublisherId = 'ca-app-pub-3940256099942544';

  static const _requiredPermissions = <String>{
    'android.permission.CAMERA',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.INTERNET',
    'android.permission.RECEIVE_BOOT_COMPLETED',
  };

  static const _highRiskPermissions = <String>{
    'android.permission.MANAGE_EXTERNAL_STORAGE',
    'android.permission.QUERY_ALL_PACKAGES',
    'android.permission.REQUEST_INSTALL_PACKAGES',
    'android.permission.READ_SMS',
    'android.permission.RECEIVE_SMS',
    'android.permission.SEND_SMS',
    'android.permission.READ_CONTACTS',
    'android.permission.WRITE_CONTACTS',
    'android.permission.READ_CALL_LOG',
    'android.permission.WRITE_CALL_LOG',
    'android.permission.RECORD_AUDIO',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_BACKGROUND_LOCATION',
  };

  static ReleaseAuditReport run(ReleaseAuditInput input) {
    final issues = <AuditIssue>[];

    final pubspecName = _yamlScalar(input.pubspecContent, 'name');
    final pubspecVersion = _yamlScalar(input.pubspecContent, 'version');
    final parsedVersion = _parseFlutterVersion(pubspecVersion);

    final applicationId = _quotedGradleValue(
      input.gradleContent,
      'applicationId',
    );
    final targetSdkExpression = _gradleExpression(
      input.gradleContent,
      const <String>['targetSdk', 'targetSdkVersion'],
    );
    final targetSdk = _resolveTargetSdk(
      targetSdkExpression,
      input.resolvedFlutterTargetSdk,
    );
    final gradleVersionNameExpression = _gradleExpression(
      input.gradleContent,
      const <String>['versionName'],
    );
    final gradleVersionCodeExpression = _gradleExpression(
      input.gradleContent,
      const <String>['versionCode'],
    );

    final applicationTag = _applicationOpeningTag(input.manifestContent);
    final manifestLabel = _xmlAttribute(applicationTag, 'android:label');
    final manifestIcon = _xmlAttribute(applicationTag, 'android:icon');
    final permissions = _manifestPermissions(input.manifestContent);

    if (pubspecName == null || pubspecName.isEmpty) {
      issues.add(
        const AuditIssue(
          severity: AuditSeverity.error,
          code: 'pubspec_name_missing',
          message: 'pubspec.yaml の name が見つかりません。',
          path: 'pubspec.yaml',
        ),
      );
    } else if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(pubspecName)) {
      issues.add(
        const AuditIssue(
          severity: AuditSeverity.error,
          code: 'pubspec_name_invalid',
          message: 'pubspec.yaml の name は小文字の Dart package 名である必要があります。',
          path: 'pubspec.yaml',
        ),
      );
    }

    if (parsedVersion == null) {
      issues.add(
        const AuditIssue(
          severity: AuditSeverity.error,
          code: 'pubspec_version_invalid',
          message:
              'pubspec.yaml の version は major.minor.patch+positiveBuildNumber 形式で指定してください。',
          path: 'pubspec.yaml',
        ),
      );
    }

    if (applicationId == null || applicationId.isEmpty) {
      issues.add(
        AuditIssue(
          severity: AuditSeverity.error,
          code: 'application_id_missing',
          message: 'Android applicationId が見つかりません。',
          path: input.gradlePath,
        ),
      );
    } else if (_isPlaceholderApplicationId(applicationId)) {
      issues.add(
        AuditIssue(
          severity: AuditSeverity.error,
          code: 'application_id_placeholder',
          message: 'applicationId がサンプルまたは仮の値です: $applicationId',
          path: input.gradlePath,
        ),
      );
    }

    if (targetSdk == null) {
      issues.add(
        AuditIssue(
          severity: AuditSeverity.error,
          code: 'target_sdk_unresolved',
          message:
              'targetSdk を数値として解決できません。Flutter SDK の targetSdkVersion も確認できませんでした。',
          path: input.gradlePath,
        ),
      );
    } else if (targetSdk < 35) {
      issues.add(
        AuditIssue(
          severity: AuditSeverity.error,
          code: 'target_sdk_too_low',
          message: 'targetSdk は35以上が必要です。現在値: $targetSdk',
          path: input.gradlePath,
        ),
      );
    } else if (targetSdk == 35) {
      issues.add(
        AuditIssue(
          severity: AuditSeverity.warning,
          code: 'target_sdk_35',
          message: 'targetSdk 35は要件を満たしますが、36以上を推奨します。',
          path: input.gradlePath,
        ),
      );
    }

    final releaseBlock = _namedBraceBlock(input.gradleContent, 'release');
    if (releaseBlock != null &&
        RegExp(
          r'\b(?:isDebuggable|debuggable)\s*(?:=\s*|\s+)true\b',
          caseSensitive: false,
        ).hasMatch(releaseBlock)) {
      issues.add(
        AuditIssue(
          severity: AuditSeverity.error,
          code: 'release_debuggable_true',
          message: 'Release buildType で debuggable=true が指定されています。',
          path: input.gradlePath,
        ),
      );
    }

    if (manifestLabel == null || manifestLabel.trim().isEmpty) {
      issues.add(
        AuditIssue(
          severity: AuditSeverity.error,
          code: 'manifest_label_missing',
          message: 'AndroidManifest.xml の application label がありません。',
          path: input.manifestPath,
        ),
      );
    } else if (manifestLabel.contains(r'${')) {
      issues.add(
        AuditIssue(
          severity: AuditSeverity.error,
          code: 'manifest_label_placeholder',
          message: 'AndroidManifest.xml の application label が未解決のプレースホルダーです。',
          path: input.manifestPath,
        ),
      );
    }

    if (manifestIcon == null ||
        !RegExp(r'^@(mipmap|drawable)/[A-Za-z0-9_]+$').hasMatch(manifestIcon)) {
      issues.add(
        AuditIssue(
          severity: AuditSeverity.error,
          code: 'manifest_icon_invalid',
          message:
              'AndroidManifest.xml の application icon は @mipmap/... または @drawable/... で指定してください。',
          path: input.manifestPath,
        ),
      );
    }

    for (final permission in _requiredPermissions.difference(permissions)) {
      issues.add(
        AuditIssue(
          severity: AuditSeverity.error,
          code: 'required_permission_missing',
          message: '必要な権限がありません: $permission',
          path: input.manifestPath,
        ),
      );
    }

    for (final permission in permissions.intersection(_highRiskPermissions)) {
      issues.add(
        AuditIssue(
          severity: AuditSeverity.error,
          code: 'high_risk_permission',
          message: 'このアプリの現行機能に不要な高リスク権限があります: $permission',
          path: input.manifestPath,
        ),
      );
    }

    for (final permission in permissions.difference(_requiredPermissions)) {
      if (_highRiskPermissions.contains(permission)) continue;
      issues.add(
        AuditIssue(
          severity: AuditSeverity.warning,
          code: 'unexpected_permission',
          message: '想定外の権限を確認してください: $permission',
          path: input.manifestPath,
        ),
      );
    }

    final scannedFiles = <String, String>{
      input.gradlePath: input.gradleContent,
      input.manifestPath: input.manifestContent,
      ...input.productionFiles,
    };
    for (final entry in scannedFiles.entries) {
      _scanProductionFile(entry.key, entry.value, issues);
    }

    for (final entry in input.releaseEnvironment.entries) {
      if (entry.value.contains(_googleSampleAdMobPublisherId)) {
        issues.add(
          AuditIssue(
            severity: AuditSeverity.error,
            code: 'sample_admob_id_in_release_environment',
            message: 'Release環境変数 ${entry.key} にGoogle提供のサンプルAdMob IDがあります。',
            path: 'environment:${entry.key}',
          ),
        );
      }
    }

    issues.sort((left, right) {
      final severity = left.severity.index.compareTo(right.severity.index);
      if (severity != 0) return severity;
      final path = left.path.compareTo(right.path);
      if (path != 0) return path;
      return left.code.compareTo(right.code);
    });

    return ReleaseAuditReport(
      facts: ReleaseAuditFacts(
        pubspecName: pubspecName,
        pubspecVersion: pubspecVersion,
        versionName: parsedVersion?.versionName,
        versionCode: parsedVersion?.versionCode,
        applicationId: applicationId,
        targetSdkExpression: targetSdkExpression,
        targetSdk: targetSdk,
        gradleVersionNameExpression: gradleVersionNameExpression,
        gradleVersionCodeExpression: gradleVersionCodeExpression,
        manifestLabel: manifestLabel,
        manifestIcon: manifestIcon,
        permissions: permissions,
      ),
      issues: List<AuditIssue>.unmodifiable(issues),
    );
  }

  static void _scanProductionFile(
    String path,
    String content,
    List<AuditIssue> issues,
  ) {
    final lower = content.toLowerCase();
    for (final endpoint in const <String>[
      'localhost',
      '127.0.0.1',
      '10.0.2.2',
    ]) {
      if (lower.contains(endpoint)) {
        issues.add(
          AuditIssue(
            severity: AuditSeverity.error,
            code: 'local_endpoint_in_production',
            message: '本番コードにローカル接続先が含まれています: $endpoint',
            path: path,
          ),
        );
      }
    }

    if (content.contains(_googleSampleAdMobPublisherId)) {
      issues.add(
        AuditIssue(
          severity: AuditSeverity.error,
          code: 'google_sample_admob_id',
          message: '本番コードにGoogle提供のサンプルAdMob IDがあります。',
          path: path,
        ),
      );
    }

    if (RegExp(
      r'''android:debuggable\s*=\s*["']true["']''',
      caseSensitive: false,
    ).hasMatch(content)) {
      issues.add(
        AuditIssue(
          severity: AuditSeverity.error,
          code: 'manifest_debuggable_true',
          message: 'Releaseへ統合されるManifestで android:debuggable=true が指定されています。',
          path: path,
        ),
      );
    }

    if (RegExp(
      r'''android:usesCleartextTraffic\s*=\s*["']true["']''',
      caseSensitive: false,
    ).hasMatch(content)) {
      issues.add(
        AuditIssue(
          severity: AuditSeverity.error,
          code: 'cleartext_traffic_enabled',
          message: 'Releaseへ統合される設定に usesCleartextTraffic=true があります。',
          path: path,
        ),
      );
    }
  }

  static bool _isPlaceholderApplicationId(String value) {
    final lower = value.toLowerCase();
    return lower == 'com.example' ||
        lower.startsWith('com.example.') ||
        lower == 'org.example' ||
        lower.startsWith('org.example.') ||
        lower.startsWith('io.flutter.') ||
        lower.startsWith('com.yourcompany.') ||
        lower.startsWith('com.your_company.') ||
        lower.startsWith('com.company.');
  }

  static String? _yamlScalar(String yaml, String key) {
    final match = RegExp(
      '^${RegExp.escape(key)}\\s*:\\s*([^#\\r\\n]+)',
      multiLine: true,
    ).firstMatch(yaml);
    if (match == null) return null;
    final raw = match.group(1)!.trim();
    if (raw.length >= 2 &&
        ((raw.startsWith("'") && raw.endsWith("'")) ||
            (raw.startsWith('"') && raw.endsWith('"')))) {
      return raw.substring(1, raw.length - 1).trim();
    }
    return raw;
  }

  static _FlutterVersion? _parseFlutterVersion(String? value) {
    if (value == null) return null;
    final match = RegExp(
      r'^(\d+)\.(\d+)\.(\d+)(?:-[0-9A-Za-z.-]+)?\+([1-9]\d*)$',
    ).firstMatch(value);
    if (match == null) return null;
    return _FlutterVersion(
      versionName: value.substring(0, value.lastIndexOf('+')),
      versionCode: int.parse(match.group(4)!),
    );
  }

  static String? _quotedGradleValue(String content, String key) {
    final match = RegExp(
      '''\\b${RegExp.escape(key)}\\s*(?:=\\s*|\\s+)["']([^"']+)["']''',
    ).firstMatch(content);
    return match?.group(1)?.trim();
  }

  static String? _gradleExpression(String content, List<String> keys) {
    for (final key in keys) {
      final match = RegExp(
        '^\\s*${RegExp.escape(key)}\\s*(?:=\\s*|\\s+)([^\\r\\n]+)',
        multiLine: true,
      ).firstMatch(content);
      if (match != null) {
        return match.group(1)!.split('//').first.trim().replaceAll(',', '');
      }
    }
    return null;
  }

  static int? _resolveTargetSdk(String? expression, int? flutterTargetSdk) {
    if (expression == null) return null;
    final numeric = RegExp(r'\b(\d+)\b').firstMatch(expression);
    if (numeric != null) return int.parse(numeric.group(1)!);
    if (expression.contains('flutter.targetSdkVersion'))
      return flutterTargetSdk;
    return null;
  }

  static String? _applicationOpeningTag(String manifest) {
    return RegExp(
      r'<application\b[^>]*>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(manifest)?.group(0);
  }

  static String? _xmlAttribute(String? tag, String attribute) {
    if (tag == null) return null;
    final match = RegExp(
      '''${RegExp.escape(attribute)}\\s*=\\s*["']([^"']*)["']''',
      caseSensitive: false,
    ).firstMatch(tag);
    return match?.group(1)?.trim();
  }

  static Set<String> _manifestPermissions(String manifest) {
    return RegExp(
      r'''<uses-permission\b[^>]*android:name\s*=\s*["']([^"']+)["'][^>]*/?>''',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(manifest).map((match) => match.group(1)!.trim()).toSet();
  }

  static String? _namedBraceBlock(String content, String name) {
    final nameMatch = RegExp(
      '\\b${RegExp.escape(name)}\\s*\\{',
    ).firstMatch(content);
    if (nameMatch == null) return null;
    final open = content.indexOf('{', nameMatch.start);
    if (open < 0) return null;

    var depth = 0;
    var quote = '';
    var escaped = false;
    for (var index = open; index < content.length; index++) {
      final char = content[index];
      if (quote.isNotEmpty) {
        if (escaped) {
          escaped = false;
        } else if (char == '\\') {
          escaped = true;
        } else if (char == quote) {
          quote = '';
        }
        continue;
      }
      if (char == '"' || char == "'") {
        quote = char;
      } else if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) return content.substring(open + 1, index);
      }
    }
    return null;
  }
}

final class _FlutterVersion {
  const _FlutterVersion({required this.versionName, required this.versionCode});

  final String versionName;
  final int versionCode;
}
