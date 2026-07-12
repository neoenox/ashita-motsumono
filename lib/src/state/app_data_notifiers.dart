// lib/src/state/app_data_notifiers.dart
// 人物・Todo・ドキュメントの変更通知を責務別に分離する。

import 'package:flutter/foundation.dart';

import '../models/entities.dart';

abstract class AppListState<T> extends ChangeNotifier {
  List<T> _values = const [];

  List<T> get values => _values;

  @protected
  void replaceValues(Iterable<T> values) {
    _values = List<T>.unmodifiable(values);
    notifyListeners();
  }
}

class ChildState extends AppListState<PersonProfile> {
  List<PersonProfile> get children => values;

  void replace(Iterable<PersonProfile> children) {
    replaceValues(children);
  }
}

class TodoState extends AppListState<AppTodo> {
  List<AppTodo> get todos => values;

  void replace(Iterable<AppTodo> todos) {
    replaceValues(todos);
  }
}

class DocumentState extends AppListState<DocumentRecord> {
  List<DocumentRecord> get documents => values;

  void replace(Iterable<DocumentRecord> documents) {
    replaceValues(documents);
  }
}
