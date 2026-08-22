import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_navigation.dart';
import '../app_state.dart';
import '../models/entities.dart';
import '../services/ad_service.dart';
import '../services/app_settings.dart';
import '../services/export_service.dart';
import '../services/notification_service.dart';
import '../services/purchase_provider.dart';
import '../services/receive_share_handler.dart';
import '../theme/app_theme.dart';
import 'add_child_screen.dart';
import 'add_todo_screen.dart';
import 'learned_dictionary_screen.dart';
import 'no_candidates_screen.dart';
import 'review_extraction_screen.dart';
import 'review_extractions_screen.dart';
import 'settings_screen.dart';
import 'widgets/home_status_cards.dart';
import 'widgets/todo_section.dart';

part 'home_screen_actions.dart';
part 'home_screen_layout.dart';
part 'home_screen_components.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _notificationInfoShownKey = 'notification_info_shown_v1';

  bool _notificationDialogShown = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _filterPersonId;
  ReceiveShareHandler? _receiveShareHandler;
  bool _shareListenerInitialized = false;
  bool _fabPressed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (Platform.isAndroid || Platform.isIOS)) {
        _initShareIntentListener();
      }
    });
  }

  @override
  void dispose() {
    final handler = _receiveShareHandler;
    if (handler != null) {
      unawaited(handler.dispose());
    }
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loaded = context.read<AppState>().loaded;
    if (loaded && !_notificationDialogShown) {
      _notificationDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_showNotificationInfoIfNeeded());
      });
    }
  }

  void _update(VoidCallback callback) => setState(callback);

  @override
  Widget build(BuildContext context) => _buildHome(context);
}
