// lib/src/theme/app_theme.dart
// Material 3 テーマ定義を集中管理する
// すべての画面で一貫した見た目を保証する
// 関連: main.dart, todo_tile.dart, todo_section.dart

import 'package:flutter/material.dart';

import '../models/enums.dart';
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    const seedColor = Color(0xFF2F7D6E);
    final cs = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      fontFamily: 'NotoSansJP',
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontWeight: FontWeight.w500),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(fontWeight: FontWeight.w400),
        bodySmall: TextStyle(fontWeight: FontWeight.w400),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }
}

class CategoryColors {
  CategoryColors._();

  static const payment = Color(0xFFFFA726);
  static const submit = Color(0xFF42A5F5);
  static const event = Color(0xFFAB47BC);
  static const item = Color(0xFF2F7D6E);
  static const other = Color(0xFF9E9E9E);
  static const completed = Color(0xFFBDBDBD);
}

extension TodoCategoryColor on TodoCategory {
  Color get color => switch (this) {
        TodoCategory.payment => CategoryColors.payment,
        TodoCategory.submit => CategoryColors.submit,
        TodoCategory.event => CategoryColors.event,
        TodoCategory.item => CategoryColors.item,
        TodoCategory.other => CategoryColors.other,
      };
}

class Spacing {
  Spacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}
