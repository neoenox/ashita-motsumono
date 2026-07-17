import 'package:ashita_motsumono/src/models/entities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> validTodoJson() => {
        'id': 'todo-1',
        'title': '水筒を持参',
        'category': 'item',
        'status': 'active',
        'items': [
          {'id': 'item-1', 'label': '水筒', 'isChecked': false},
        ],
        'notifyPreviousNight': true,
        'notifySameMorning': true,
        'createdAt': '2026-07-16T00:00:00.000Z',
        'updatedAt': '2026-07-16T00:00:00.000Z',
      };

  test('known missing legacy fields use documented defaults', () {
    final json = validTodoJson()
      ..remove('category')
      ..remove('status')
      ..remove('notifyPreviousNight')
      ..remove('notifySameMorning');
    final item = (json['items'] as List).single as Map<String, dynamic>;
    item.remove('isChecked');

    final todo = AppTodo.fromJson(json);

    expect(todo.category, TodoCategory.other);
    expect(todo.status, TodoStatus.active);
    expect(todo.notifyPreviousNight, isTrue);
    expect(todo.notifySameMorning, isTrue);
    expect(todo.items.single.isChecked, isFalse);
  });

  test('unknown enum values are rejected instead of activated', () {
    final json = validTodoJson()..['status'] = 'unexpected';

    expect(
      () => AppTodo.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });

  test('invalid timestamps are rejected instead of replaced with now', () {
    final json = validTodoJson()..['createdAt'] = 'not-a-date';

    expect(
      () => AppTodo.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });

  test('person and document records require stable identifiers and dates', () {
    expect(
      () => PersonProfile.fromJson({
        'id': '',
        'name': '子ども',
        'colorValue': 1,
        'createdAt': '2026-07-16T00:00:00.000Z',
        'updatedAt': '2026-07-16T00:00:00.000Z',
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => DocumentRecord.fromJson({
        'id': 'doc-1',
        'sourceType': 'camera',
        'createdAt': '',
        'updatedAt': '2026-07-16T00:00:00.000Z',
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
