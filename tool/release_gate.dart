// tool/release_gate.dart
//
// Release Gate CLI繧ｨ繝ｳ繝医Μ繝昴う繝ｳ繝・// Play Console謠仙・蜑阪・險ｭ螳壹Α繧ｹ繧定・蜍墓､懷・縺吶ｋ縲・
import 'dart:io';

import 'src/release_audit.dart';

/// Release Gate CLI縺ｮ繧ｨ繝ｳ繝医Μ繝昴う繝ｳ繝医・void main(List<String> arguments) {
  try {
    final options = _parseArguments(arguments);
    if (options.showHelp) {
      _printUsage();
      return;
    }

    final root = Directory(options.rootPath).absolute;
    if (!root.existsSync()) {
      stderr.writeln('ERROR: 繝励Ο繧ｸ繧ｧ繧ｯ繝医Ν繝ｼ繝医′隕九▽縺九ｊ縺ｾ縺帙ｓ: ${root.path}');
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
    stderr.writeln('ERROR: 繝輔ぃ繧､繝ｫ繧定ｪｭ縺ｿ蜿悶ｌ縺ｾ縺帙ｓ: ${error.message}');
    exitCode = 2;
  } catch (error) {
    stderr.writeln('ERROR: Release Gate縺ｮ螳溯｡後↓螟ｱ謨励＠縺ｾ縺励◆: $error');
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
        throw const FormatException('--root縺ｫ縺ｯ繝代せ繧呈欠螳壹＠縺ｦ縺上□縺輔＞縲・);
      }
      rootPath = value;
      continue;
    }
    if (argument == '--root') {
      if (index + 1 >= arguments.length) {
        throw const FormatException('--root縺ｮ蠕後↓繝代せ繧呈欠螳壹＠縺ｦ縺上□縺輔＞縲・);
      }
      index++;
      final value = arguments[index].trim();
      if (value.isEmpty) {
        throw const FormatException('--root縺ｫ縺ｯ繝代せ繧呈欠螳壹＠縺ｦ縺上□縺輔＞縲・);
      }
      rootPath = value;
      continue;
    }
    throw FormatException('荳肴・縺ｪ繧ｪ繝励す繝ｧ繝ｳ縺ｧ縺・ $argument');
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
    '  --root=<path>  Flutter繝励Ο繧ｸ繧ｧ繧ｯ繝医・繝ｫ繝ｼ繝医よ里螳壼､縺ｯ迴ｾ蝨ｨ縺ｮ繝・ぅ繝ｬ繧ｯ繝医Μ縲・,
  );
  stdout.writeln('  --help, -h     縺薙・繝倥Ν繝励ｒ陦ｨ遉ｺ縲・);
}

class _CliOptions {
  const _CliOptions({
    required this.rootPath,
    required this.showHelp,
  });

  final String rootPath;
  final bool showHelp;
}
