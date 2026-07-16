part of 'app_state.dart';

const _personColors = <Color>[
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFF8E24AA),
  Color(0xFF00ACC1),
  Color(0xFFD81B60),
  Color(0xFF3949AB),
  Color(0xFF6D4C41),
  Color(0xFF546E7A),
];

extension ChildAppStateOperations on AppState {
  int _assignPersonColor() {
    final usedColors = children.map((child) => child.colorValue).toSet();
    for (final color in _personColors) {
      if (!usedColors.contains(color.toARGB32())) return color.toARGB32();
    }
    return _personColors[children.length % _personColors.length].toARGB32();
  }

  Future<PersonProfile> addChild(String name) => _runMutation(() async {
        final trimmedName = name.trim();
        if (trimmedName.isEmpty) {
          throw ArgumentError.value(name, 'name', 'must not be empty');
        }
        final now = DateTime.now();
        final child = PersonProfile(
          id: _uuid.v4(),
          name: trimmedName,
          colorValue: _assignPersonColor(),
          createdAt: now,
          updatedAt: now,
        );
        final nextChildren = [...children, child];
        await _persistSnapshot(nextChildren: nextChildren);
        _replaceChildren(nextChildren);
        return child;
      });

  Future<void> deleteChild(String id) => _runMutation(() async {
        final nextChildren = children.where((child) => child.id != id).toList();
        final now = DateTime.now();
        final nextTodos = todos
            .map(
              (todo) => todo.personId == id
                  ? todo.copyWith(clearPersonId: true, updatedAt: now)
                  : todo,
            )
            .toList();
        await _persistSnapshot(nextChildren: nextChildren, nextTodos: nextTodos);
        _replaceChildren(nextChildren);
        _replaceTodos(nextTodos);
      });

  Future<void> updateChild(PersonProfile child) => _runMutation(() async {
        final updated = child.copyWith(updatedAt: DateTime.now());
        final nextChildren = children
            .map((existing) => existing.id == updated.id ? updated : existing)
            .toList();
        await _persistSnapshot(nextChildren: nextChildren);
        _replaceChildren(nextChildren);
      });
}
