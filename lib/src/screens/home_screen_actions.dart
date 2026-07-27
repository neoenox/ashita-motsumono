part of 'home_screen.dart';

extension _HomeScreenActions on _HomeScreenState {
  void _initShareIntentListener() {
    if (_shareListenerInitialized) return;
    _shareListenerInitialized = true;

    final handler = ReceiveShareHandler(
      appState: context.read<AppState>(),
      appSettings: widget.settings,
    );

    _receiveShareHandler = handler;

    unawaited(
      handler.start(
        onResult: _handleShareResult,
        onError: (error, stackTrace) {
          if (kDebugMode) {
            debugPrint(
              'Share intent error: '
              '$error\n$stackTrace',
            );
          }

          if (!mounted) return;

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('共有データを受信できませんでした。')));
        },
      ),
    );
  }

  Future<void> _handleShareResult(ReceiveShareResult result) async {
    if (!mounted) return;

    switch (result) {
      case ReceiveShareFailure():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            duration: const Duration(seconds: 8),
          ),
        );

      case ReceiveShareSuccess():
        final navigator = Navigator.of(context);
        navigator.popUntil((route) => route.isFirst);

        if (result.drafts.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDFを保存しました。読み取り結果を確認して手入力してください。'),
              duration: Duration(seconds: 8),
            ),
          );
          await pushAdaptive<void>(
            context,
            (_) => NoCandidatesScreen(
              documentId: result.documentId,
              ocrText: result.ocrText ?? '',
            ),
          );
          return;
        }

        final Widget reviewScreen;
        if (result.drafts.length == 1) {
          reviewScreen = ReviewExtractionScreen(
            draft: result.drafts.single,
            documentId: result.documentId,
          );
        } else {
          reviewScreen = ReviewExtractionsScreen(
            drafts: result.drafts,
            documentId: result.documentId,
          );
        }

        await pushAdaptive<void>(context, (_) => reviewScreen);
    }
  }

  Future<void> _showNotificationInfoIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted ||
        (prefs.getBool(_HomeScreenState._notificationInfoShownKey) ?? false)) {
      return;
    }

    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final previousNight = _fmtNotificationTime(
      widget.settings.previousNightHour,
      widget.settings.previousNightMinute,
    );
    final sameMorning = _fmtNotificationTime(
      widget.settings.sameMorningHour,
      widget.settings.sameMorningMinute,
    );

    final enableNotifications = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('通知について'),
        content: Text(
          '前日$previousNightと当日$sameMorningにTodoのリマインド通知をお送りします。'
          '通知を有効にする場合は、次に表示される端末の通知許可で「許可」を選んでください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('あとで'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('通知を有効にする'),
          ),
        ],
      ),
    );

    // "あとで" is a true deferral: do not persist the shown flag.
    if (!mounted || enableNotifications != true) return;
    await prefs.setBool(_HomeScreenState._notificationInfoShownKey, true);
    if (!mounted) return;

    try {
      await appState.requestNotificationPermissions();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('通知設定を確認しました')));
    } on Object {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('通知設定を確認できませんでした')));
    }
  }

  String _fmtNotificationTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Future<void> _exportData(AppState state) async {
    final shouldExport = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('データをエクスポート'),
        content: const Text(
          '人物名、Todo、OCR全文を含むJSONをクリップボードにコピーします。'
          '保存画像のファイル本体と端末内画像パスは含めません。'
          '他のアプリに貼り付けると個人情報が含まれる可能性があります。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('コピーする'),
          ),
        ],
      ),
    );
    if (!mounted || shouldExport != true) return;

    final sanitized = createExportSnapshot(state);
    final json = const JsonEncoder.withIndent('  ').convert(sanitized.toJson());
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('データをクリップボードにコピーしました')));
  }

  Future<void> _copyCorruptBackup(AppState state) async {
    final backup = state.loadCorruptBackup();
    if (backup == null || backup.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('退避データが見つかりませんでした')));
      return;
    }
    await Clipboard.setData(ClipboardData(text: backup));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('退避データをクリップボードにコピーしました')));
  }

  List<AppTodo> _filter(List<AppTodo> todos, List<PersonProfile> children) {
    final childMap = {for (final child in children) child.id: child};
    return todos.where((todo) {
      if (_filterPersonId != null && todo.personId != _filterPersonId) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      if (todo.title.toLowerCase().contains(query)) return true;
      if (todo.category.label.contains(query)) return true;
      if (todo.note?.toLowerCase().contains(query) == true) return true;
      if (todo.amount?.toString().contains(query) == true) return true;
      final child = childMap[todo.personId];
      return child?.name.toLowerCase().contains(query) == true;
    }).toList();
  }
}
