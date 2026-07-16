import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/app_settings.dart';
import '../services/ocr_pick_service.dart';
import '../services/ocr_service.dart';
import '../state/app_data_notifiers.dart';
import 'home_screen.dart';
import 'review_extraction_screen.dart';
import 'review_extractions_screen.dart';

class HomeScreenScope extends StatefulWidget {
  const HomeScreenScope({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<HomeScreenScope> createState() => _HomeScreenScopeState();
}

class _HomeScreenScopeState extends State<HomeScreenScope> {
  bool _recoveryStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recoveryStarted) return;
    _recoveryStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_recoverLostImage());
    });
  }

  Future<void> _recoverLostImage() async {
    final appState = context.read<AppState>();
    final service = OcrPickService(
      appState: appState,
      appSettings: widget.settings,
    );
    try {
      final result = await service.recoverLostImage();
      if (result == null || !mounted) return;
      switch (result) {
        case OcrPickEmpty():
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('中断された画像から文字を読み取れませんでした。')),
          );
        case OcrPickSuccess():
          if (result.drafts.isEmpty) {
            await appState.deleteDocument(result.document.id);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('復旧した画像からTodo情報を抽出できませんでした。')),
            );
            return;
          }
          final Widget screen = result.drafts.length == 1
              ? ReviewExtractionScreen(
                  draft: result.drafts.single,
                  documentId: result.document.id,
                )
              : ReviewExtractionsScreen(
                  drafts: result.drafts,
                  documentId: result.document.id,
                );
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => screen),
          );
      }
    } on OcrException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('中断された画像選択を復旧できませんでした。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ChildState>();
    context.watch<TodoState>();
    return HomeScreen(settings: widget.settings);
  }
}
