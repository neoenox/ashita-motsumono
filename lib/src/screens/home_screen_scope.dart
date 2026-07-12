// lib/src/screens/home_screen_scope.dart
// HomeScreenが依存する人物・Todo状態の購読を画面境界にカプセル化する。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_settings.dart';
import '../state/app_data_notifiers.dart';
import 'home_screen.dart';

class HomeScreenScope extends StatelessWidget {
  const HomeScreenScope({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    context.watch<ChildState>();
    context.watch<TodoState>();
    return HomeScreen(settings: settings);
  }
}
