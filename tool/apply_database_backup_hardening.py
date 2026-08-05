from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'lib/src/repositories/app_database.dart'
TEST = ROOT / 'test/database_backup_sidecar_test.dart'

source = SOURCE.read_text(encoding='utf-8')
pattern = re.compile(
    r"  Future<String\?> backupDatabaseFile\(\) async \{.*?\n  \}\n\n  Future<AppSnapshot> loadSnapshot\(\) async \{",
    re.S,
)
replacement = '''  Future<String?> backupDatabaseFile() async {
    final source = databaseFile;
    if (source == null || !await source.exists()) return null;

    try {
      await customStatement('PRAGMA wal_checkpoint(FULL)');
    } on Object {
      // 破損時はcheckpointできない場合があるため、現存ファイルの退避を続行する。
    }

    final stamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final backupBasePath = p.join(
      source.parent.path,
      'ashita_motsumono_corrupt_$stamp.db',
    );
    final copiedPaths = await backupDatabaseFilesAtPath(
      source.path,
      backupBasePath,
    );
    if (copiedPaths.isEmpty) return null;
    return copiedPaths.join('\\n');
  }

  @visibleForTesting
  static Future<List<String>> backupDatabaseFilesAtPath(
    String sourcePath,
    String backupBasePath,
  ) async {
    final copiedPaths = <String>[];
    for (final suffix in _databaseSuffixes) {
      final source = File('$sourcePath$suffix');
      if (!await source.exists()) continue;
      final destination = File('$backupBasePath$suffix');
      await source.copy(destination.path);
      copiedPaths.add(destination.path);
    }
    return copiedPaths;
  }

  Future<AppSnapshot> loadSnapshot() async {'''
updated, count = pattern.subn(lambda _: replacement, source, count=1)
if count != 1:
    raise RuntimeError(f'expected one backupDatabaseFile function, replaced {count}')
SOURCE.write_text(updated, encoding='utf-8')

TEST.write_text(
    """import 'dart:io';

import 'package:ashita_motsumono/src/repositories/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('corrupt database backup includes SQLite sidecars', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ashita_database_backup_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final source = '${directory.path}/ashita_motsumono.db';
    final backup = '${directory.path}/ashita_motsumono_corrupt.db';
    await File(source).writeAsString('db');
    await File('$source-wal').writeAsString('wal');
    await File('$source-shm').writeAsString('shm');
    await File('$source-journal').writeAsString('journal');

    final copied = await AppDatabase.backupDatabaseFilesAtPath(source, backup);

    expect(
      copied,
      containsAll([backup, '$backup-wal', '$backup-shm', '$backup-journal']),
    );
    expect(await File(backup).readAsString(), 'db');
    expect(await File('$backup-wal').readAsString(), 'wal');
    expect(await File('$backup-shm').readAsString(), 'shm');
    expect(await File('$backup-journal').readAsString(), 'journal');
  });
}
""",
    encoding='utf-8',
)
