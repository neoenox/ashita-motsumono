from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'lib/src/repositories/app_database.dart'
TEST = ROOT / 'test/database_backup_sidecar_test.dart'

source = SOURCE.read_text(encoding='utf-8')
old = """      final destination = File('$backupBasePath$suffix');
      await source.copy(destination.path);
      copiedPaths.add(destination.path);
"""
new = """      final destination = File('$backupBasePath$suffix');
      try {
        await source.copy(destination.path);
        copiedPaths.add(destination.path);
      } on Object {
        // 破損・権限・容量不足などで一部をコピーできなくても、
        // 既に退避できたファイルは復旧証跡として残す。
      }
"""
if old not in source:
    raise RuntimeError('database backup copy block not found')
SOURCE.write_text(source.replace(old, new, 1), encoding='utf-8')

test = TEST.read_text(encoding='utf-8')
anchor = """  });
}
"""
addition = """  });

  test('a failed sidecar copy preserves other backup files', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ashita_database_partial_backup_',
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
    await Directory('$backup-wal').create();

    final copied = await AppDatabase.backupDatabaseFilesAtPath(source, backup);

    expect(copied, contains(backup));
    expect(copied, contains('$backup-shm'));
    expect(copied, isNot(contains('$backup-wal')));
    expect(await File(backup).readAsString(), 'db');
    expect(await File('$backup-shm').readAsString(), 'shm');
  });
}
"""
if not test.endswith(anchor):
    raise RuntimeError('database backup test anchor not found')
TEST.write_text(test[:-len(anchor)] + addition, encoding='utf-8')
