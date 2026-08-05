part of 'home_screen.dart';

extension _HomeScreenLayout on _HomeScreenState {
  Widget _buildHome(BuildContext context) {
    final state = context.watch<AppState>();
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final todayTodos = _filter(state.todosForDate(today), state.children);
    final tomorrowTodos = _filter(state.todosForDate(tomorrow), state.children);
    final undated = _filter(state.undatedTodos(), state.children);
    final upcoming = _filter(state.futureTodos(), state.children);
    final allFiltered =
        todayTodos.isEmpty &&
        tomorrowTodos.isEmpty &&
        undated.isEmpty &&
        upcoming.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('あしたもつもの'),
        actions: [
          IconButton(
            tooltip: '人物を追加',
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () =>
                pushAdaptive<void>(context, (_) => const AddChildScreen()),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'export') unawaited(_exportData(state));
              if (value == 'dictionary') {
                unawaited(
                  pushAdaptive<void>(
                    context,
                    (_) => LearnedDictionaryScreen(settings: widget.settings),
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'dictionary',
                child: ListTile(
                  leading: Icon(Icons.spellcheck),
                  title: Text('読み取り辞書'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download_outlined),
                  title: Text('データをエクスポート'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              Spacing.sm,
              Spacing.md,
              0,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '検索…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _update(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => _update(() => _searchQuery = value.trim()),
            ),
          ),
          if (state.children.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.sm,
                Spacing.md,
                0,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: state.children
                      .map(
                        (child) => Padding(
                          padding: const EdgeInsets.only(right: Spacing.sm),
                          child: FilterChip(
                            label: Text(child.name),
                            selected: _filterPersonId == child.id,
                            onSelected: (selected) {
                              _update(
                                () => _filterPersonId = selected
                                    ? child.id
                                    : null,
                              );
                            },
                            selectedColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            labelStyle: TextStyle(
                              color: _filterPersonId == child.id
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : null,
                            ),
                            checkmarkColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                            avatar: CircleAvatar(
                              radius: 10,
                              backgroundColor: Color(child.colorValue),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.sm,
                Spacing.md,
                96,
              ),
              children: [
                if (state.lastLoadHadCorruptData) ...[
                  CorruptDataCard(
                    onCopy: () => unawaited(_copyCorruptBackup(state)),
                  ),
                  const SizedBox(height: Spacing.sm),
                ],
                if (state.children.isEmpty)
                  FirstRunCard(
                    onAddPerson: () => pushAdaptive<void>(
                      context,
                      (_) => const AddChildScreen(),
                    ),
                  ),
                if (state.children.isNotEmpty &&
                    allFiltered &&
                    _searchQuery.isEmpty &&
                    state.todos.isEmpty)
                  const EmptyState(),
                if (state.children.isNotEmpty &&
                    allFiltered &&
                    _searchQuery.isNotEmpty)
                  NoSearchResults(query: _searchQuery),
                if (todayTodos.isNotEmpty || _searchQuery.isEmpty) ...[
                  TodoSection(title: '今日やること', todos: todayTodos),
                  const SizedBox(height: Spacing.md),
                ],
                TodoSection(title: '明日の持ち物・提出', todos: tomorrowTodos),
                const SizedBox(height: Spacing.md),
                TodoSection(title: '期限未設定・要確認', todos: undated),
                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: Spacing.md),
                  UpcomingSection(todos: upcoming),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _MainBottomNav(selectedIndex: 0),
      bottomSheet: context.watch<PurchaseProvider>().adRemoved
          ? null
          : const SafeArea(bottom: true, child: _AdBanner()),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildFab(BuildContext context) {
    final button = FloatingActionButton.extended(
      onPressed: () =>
          pushAdaptive<void>(context, (_) => const AddTodoScreen()),
      icon: const Icon(Icons.add),
      label: const Text('追加'),
    );
    if (context.isReducedMotion) return button;

    return Listener(
      onPointerDown: (_) => _setFabPressed(true),
      onPointerUp: (_) => _setFabPressed(false),
      onPointerCancel: (_) => _setFabPressed(false),
      child: AnimatedScale(
        duration: AppMotion.quick,
        curve: AppMotion.standardCurve,
        scale: _fabPressed ? 0.96 : 1,
        child: button,
      ),
    );
  }

  void _setFabPressed(bool pressed) {
    if (!mounted || _fabPressed == pressed) return;
    _update(() => _fabPressed = pressed);
  }
}
