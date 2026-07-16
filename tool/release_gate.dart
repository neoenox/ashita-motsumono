// tool/release_gate.dart
//
// Release Gate CLIエントリポイント
// Play Console提出前の設定ミスを自動検出する。

import 'dart:io';

import 'src/release_audit.dart';

/// Release Gate CLIのエントリポイント。
void main(List<String> arguments) {
  try {
    final options = _parseArguments(arguments);
    if (options.showHelp) {
      _printUsage();
      return;
    }

    final root = Directory(options.rootPath).absolute;
    if (!root.existsSync()) {
      stderr.writeln('ERROR: プロジェクトルートが見つかりません: ${root.path}');
      exitCode = 2;
      return;
    }

    final audit = ReleaseAudit();
    final results = audit.auditProject(root);

    stdout.writeln('Release Gate: ${root.path}');
    stdout.writeln('');
    for (final result in results) {
      stdout.writeln(_formatResult(result));
    }

    final errorCount =
        results.where((result) => result.isError).length;
    final warningCount =
        results.where((result) => result.isWarning).length;
    final infoCount = results.length - errorCount - warningCount;

    stdout.writeln('');
    stdout.writeln(
      'Summary: errors=$errorCount, warnings=$warningCount, info=$infoCount',
    );

    if (errorCount > 0) {
      stdout.writeln('RELEASE GATE: FAILED');
      exitCode = 1;
      return;
    }

    stdout.writeln(
      warningCount > 0
          ? 'RELEASE GATE: PASSED WITH WARNINGS'
          : 'RELEASE GATE: PASSED',
    );
    exitCode = 0;
  } on FormatException catch (error) {
    stderr.writeln('ERROR: ${error.message}');
    _printUsage();
    exitCode = 64;
  } on FileSystemException catch (error) {
    stderr.writeln('ERROR: ファイルを読み取れません: ${error.message}');
    exitCode = 2;
  } catch (error) {
    stderr.writeln('ERROR: Release Gateの実行に失敗しました: $error');
    exitCode = 2;
  }
}

_CliOptions _parseArguments(List<String> arguments) {
  var rootPath = Directory.current.path;
  var showHelp = false;

  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (argument == '--help' || argument == '-h') {
      showHelp = true;
      continue;
    }
    if (argument.startsWith('--root=')) {
      final value = argument.substring('--root='.length).trim();
      if (value.isEmpty) {
        throw const FormatException('--rootにはパスを指定してください。');
      }
      rootPath = value;
      continue;
    }
    if (argument == '--root') {
      if (index + 1 >= arguments.length) {
        throw const FormatException('--rootの後にパスを指定してください。');
      }
      index++;
      final value = arguments[index].trim();
      if (value.isEmpty) {
        throw const FormatException('--rootにはパスを指定してください。');
      }
      rootPath = value;
      continue;
    }
    throw FormatException('不明なオプションです: $argument');
  }

  return _CliOptions(rootPath: rootPath, showHelp: showHelp);
}

String _formatResult(ReleaseCheckResult result) {
  final severity = switch (result.severity) {
    ReleaseCheckSeverity.error => 'ERROR',
    ReleaseCheckSeverity.warning => 'WARN ',
    ReleaseCheckSeverity.info => 'INFO ',
  };
  final location = _formatLocation(result.file, result.line);
  return '[$severity] ${result.id}: ${result.message}$location';
}

String _formatLocation(String? file, int? line) {
  if (file == null) {
    return '';
  }
  if (line == null) {
    return ' ($file)';
  }
  return ' ($file:$line)';
}

void _printUsage() {
  stdout.writeln(
    'Usage: dart run tool/release_gate.dart [--root=<path>]',
  );
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln(
    '  --root=<path>  Flutterプロジェクトのルート。既定値は現在のディレクトリ。',
  );
  stdout.writeln('  --help, -h     このヘルプを表示。');
}

class _CliOptions {
  const _CliOptions({
    required this.rootPath,
    required this.showHelp,
  });

  final String rootPath;
  final bool showHelp;
}
