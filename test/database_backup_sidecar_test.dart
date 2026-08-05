import 'dart:io';

import 'package:ashita_motsumono/src/repositories/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A failed WAL checkpoint must not reduce the recoverable backup set.
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
