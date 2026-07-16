// test/model_serialization_test.dart
// ドメインモデルの toJson/fromJson/copyWith をテストする。
// JSON永続化の完全性を保証するために存在する。
// 関連: lib/src/models/app_todo.dart, lib/src/models/person_profile.dart,
//       lib/src/models/document_record.dart, lib/src/models/checklist_item.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:ashita_motsumono/src/models/app_todo.dart';
import 'package:ashita_motsumono/src/models/person_profile.dart';
import 'package:ashita_motsumono/src/models/document_record.dart';
import 'package:ashita_motsumono/src/models/checklist_item.dart';
import 'package:ashita_motsumono/src/models/enums.dart';

void main() {
  group('AppTodo', () {
    final todo = AppTodo(
      id: 'todo-1',
      title: '集金 500円',
      category: TodoCategory.payment,
      status: TodoStatus.active,
      items: [ChecklistItem(id: 'item-1', label: '集金袋')],
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 2),
      personId: 'person-1',
      documentId: 'doc-1',
      dueDate: DateTime(2026, 7, 10),
      amount: 500,
      note: '忘れずに',
      notifyPreviousNight: true,
      notifySameMorning: false,
    );

    test('toJson produces correct map', () {
      final json = todo.toJson();
      expect(json['id'], 'todo-1');
      expect(json['title'], '集金 500円');
      expect(json['category'], 'payment');
      expect(json['status'], 'active');
      expect(json['amount'], 500);
      expect(json['note'], '忘れずに');
      expect(json['personId'], 'person-1');
      expect(json['documentId'], 'doc-1');
      expect(json['dueDate'], '2026-07-10T00:00:00.000');
      expect(json['notifyPreviousNight'], true);
      expect(json['notifySameMorning'], false);
      expect(json['items'], isA<List>());
    });

    test('fromJson restores original', () {
      final json = todo.toJson();
      final restored = AppTodo.fromJson(json);
      expect(restored.id, todo.id);
      expect(restored.title, todo.title);
      expect(restored.category, todo.category);
      expect(restored.status, todo.status);
      expect(restored.amount, todo.amount);
      expect(restored.note, todo.note);
      expect(restored.personId, todo.personId);
      expect(restored.documentId, todo.documentId);
      expect(restored.dueDate, todo.dueDate);
      expect(restored.notifyPreviousNight, todo.notifyPreviousNight);
      expect(restored.notifySameMorning, todo.notifySameMorning);
      expect(restored.items.length, todo.items.length);
      expect(restored.items[0].label, todo.items[0].label);
    });

    test('fromJson handles absent optional fields', () {
      final json = {
        'id': 't1',
        'title': 'test',
        'category': 'item',
        'status': 'active',
        'items': <Map<String, dynamic>>[],
        'createdAt': '2026-07-01T00:00:00.000',
        'updatedAt': '2026-07-01T00:00:00.000',
      };
      final restored = AppTodo.fromJson(json);
      expect(restored.id, 't1');
      expect(restored.personId, isNull);
      expect(restored.dueDate, isNull);
      expect(restored.amount, isNull);
      expect(restored.note, isNull);
      expect(restored.items, isEmpty);
    });

    test('fromJson falls back to legacy childId', () {
      final json = {
        'id': 't1',
        'title': 'test',
        'category': 'other',
        'status': 'active',
        'childId': 'legacy-person-1',
        'items': <Map<String, dynamic>>[],
        'createdAt': '2026-07-01T00:00:00.000',
        'updatedAt': '2026-07-01T00:00:00.000',
      };
      final restored = AppTodo.fromJson(json);
      expect(restored.personId, 'legacy-person-1');
    });

    test('fromJson prefers personId over childId', () {
      final json = {
        'id': 't1',
        'title': 'test',
        'category': 'other',
        'status': 'active',
        'personId': 'person-2',
        'childId': 'legacy-person-1',
        'items': <Map<String, dynamic>>[],
        'createdAt': '2026-07-01T00:00:00.000',
        'updatedAt': '2026-07-01T00:00:00.000',
      };
      final restored = AppTodo.fromJson(json);
      expect(restored.personId, 'person-2');
    });

    test('fromJson rejects missing stable fields', () {
      expect(
        () => AppTodo.fromJson({}),
        throwsA(isA<FormatException>()),
      );
    });

    test('copyWith preserves original when no args', () {
      final copy = todo.copyWith();
      expect(copy.id, todo.id);
      expect(copy.title, todo.title);
    });

    test('copyWith overrides specified fields', () {
      final copy = todo.copyWith(title: 'new title', amount: 1000);
      expect(copy.title, 'new title');
      expect(copy.amount, 1000);
      expect(copy.id, todo.id);
    });

    test('copyWith clears fields when clear flags are set', () {
      final copy = todo.copyWith(clearAmount: true, clearNote: true);
      expect(copy.amount, isNull);
      expect(copy.note, isNull);
      expect(copy.title, todo.title);
    });

    test('isDone returns true when status is done', () {
      final done = todo.copyWith(status: TodoStatus.done);
      expect(done.isDone, true);
      expect(todo.isDone, false);
    });

    test('fromJson rejects invalid dueDate', () {
      final json = {
        'id': 'todo-1',
        'title': 'Test',
        'category': 'other',
        'status': 'active',
        'dueDate': 'not-a-date',
        'items': <Map<String, dynamic>>[],
        'notifyPreviousNight': true,
        'notifySameMorning': true,
        'createdAt': '2026-01-01T00:00:00.000',
        'updatedAt': '2026-01-01T00:00:00.000',
      };
      expect(
        () => AppTodo.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('PersonProfile', () {
    final profile = PersonProfile(
      id: 'person-1',
      name: '長女',
      colorValue: 0xFF2F7D6E,
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 2),
    );

    test('toJson produces correct map', () {
      final json = profile.toJson();
      expect(json['id'], 'person-1');
      expect(json['name'], '長女');
      expect(json['colorValue'], 0xFF2F7D6E);
    });

    test('fromJson restores original', () {
      final json = profile.toJson();
      final restored = PersonProfile.fromJson(json);
      expect(restored.id, profile.id);
      expect(restored.name, profile.name);
      expect(restored.colorValue, profile.colorValue);
    });

    test('fromJson rejects empty input', () {
      expect(
        () => PersonProfile.fromJson({}),
        throwsA(isA<FormatException>()),
      );
    });

    test('copyWith preserves original when no args', () {
      final copy = profile.copyWith();
      expect(copy.name, profile.name);
    });

    test('copyWith overrides specified fields', () {
      final copy = profile.copyWith(name: '太郎');
      expect(copy.name, '太郎');
      expect(copy.id, profile.id);
    });
  });

  group('DocumentRecord', () {
    final doc = DocumentRecord(
      id: 'doc-1',
      sourceType: 'camera',
      localImagePath: '/path/to/image.jpg',
      ocrText: '7月10日までに水筒を持参',
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );

    test('toJson produces correct map', () {
      final json = doc.toJson();
      expect(json['id'], 'doc-1');
      expect(json['sourceType'], 'camera');
      expect(json['localImagePath'], '/path/to/image.jpg');
      expect(json['ocrText'], '7月10日までに水筒を持参');
    });

    test('fromJson restores original', () {
      final json = doc.toJson();
      final restored = DocumentRecord.fromJson(json);
      expect(restored.id, doc.id);
      expect(restored.sourceType, doc.sourceType);
      expect(restored.localImagePath, doc.localImagePath);
      expect(restored.ocrText, doc.ocrText);
    });

    test('fromJson handles null optional fields', () {
      final doc2 = DocumentRecord(
        id: 'doc-2',
        sourceType: 'gallery',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final json = doc2.toJson();
      final restored = DocumentRecord.fromJson(json);
      expect(restored.localImagePath, isNull);
      expect(restored.ocrText, isNull);
    });

    test('copyWith clears localImagePath when flag is set', () {
      final copy = doc.copyWith(clearLocalImagePath: true);
      expect(copy.localImagePath, isNull);
      expect(copy.id, doc.id);
    });
  });

  group('ChecklistItem', () {
    test('toJson/fromJson round trip', () {
      final item = ChecklistItem(id: 'ci-1', label: '水筒', isChecked: true);
      final json = item.toJson();
      final restored = ChecklistItem.fromJson(json);
      expect(restored.id, 'ci-1');
      expect(restored.label, '水筒');
      expect(restored.isChecked, true);
    });

    test('default isChecked is false', () {
      final item = ChecklistItem(id: 'ci-1', label: 'タオル');
      expect(item.isChecked, false);
    });

    test('copyWith overrides isChecked', () {
      final item = ChecklistItem(id: 'ci-1', label: 'タオル');
      final checked = item.copyWith(isChecked: true);
      expect(checked.isChecked, true);
    });
  });

  group('Enums', () {
    test('TodoCategory.fromName returns correct enum', () {
      expect(TodoCategory.fromName('payment'), TodoCategory.payment);
      expect(TodoCategory.fromName('submit'), TodoCategory.submit);
      expect(TodoCategory.fromName('item'), TodoCategory.item);
      expect(TodoCategory.fromName('event'), TodoCategory.event);
      expect(TodoCategory.fromName('other'), TodoCategory.other);
    });

    test('TodoCategory.fromName falls back to other', () {
      expect(TodoCategory.fromName('invalid'), TodoCategory.other);
      expect(TodoCategory.fromName(null), TodoCategory.other);
    });

    test('TodoCategory.label returns Japanese label', () {
      expect(TodoCategory.item.label, '持ち物');
      expect(TodoCategory.payment.label, '集金');
    });

    test('TodoStatus.fromName returns correct enum', () {
      expect(TodoStatus.fromName('done'), TodoStatus.done);
      expect(TodoStatus.fromName('archived'), TodoStatus.archived);
    });

    test('TodoStatus.fromName falls back to active', () {
      expect(TodoStatus.fromName('invalid'), TodoStatus.active);
      expect(TodoStatus.fromName(null), TodoStatus.active);
    });
  });
}
