// test/app_state_child_validation_test.dart
// AppState.addChild が空の名前を拒否し、状態・永続化を変更しないことを検証する。

import 'package:ashita_motsumono/src/app_state.dart';
import 'package:ashita_motsumono/src/repositories/drift_store.dart';
import 'package:ashita_motsumono/src/services/notification_service.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'rejects empty and whitespace-only child names without persistence',
    () async {
      final store = await DriftStore.createInMemory();
      final appState = AppState(
        store: store,
        notifications: NotificationService(timezoneName: 'Asia/Tokyo'),
      );
      await appState.load();

      for (final invalidName in ['', '   ', '\t\n', '　']) {
        await expectLater(
          appState.addChild(invalidName),
          throwsA(
            isA<ArgumentError>()
                .having((error) => error.name, 'name', 'name')
                .having(
                  (error) => error.invalidValue,
                  'invalidValue',
                  invalidName,
                ),
          ),
        );

        expect(appState.children, isEmpty);
        expect((await store.load()).children, isEmpty);
      }
    },
  );

  test('trims a valid child name before storing it', () async {
    final store = await DriftStore.createInMemory();
    final appState = AppState(
      store: store,
      notifications: NotificationService(timezoneName: 'Asia/Tokyo'),
    );
    await appState.load();

    final child = await appState.addChild(' 　長女　 ');

    expect(child.name, '長女');
    expect(appState.children.single.name, '長女');
    expect((await store.load()).children.single.name, '長女');
  });
}
