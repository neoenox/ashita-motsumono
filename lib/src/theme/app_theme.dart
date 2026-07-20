// lib/src/theme/app_theme.dart
// Material 3 テーマ定義を集中管理する
// Stitch デザインシステム (Smart Aesthetic Enhancer) のトークンを反映
// 関連: main.dart, todo_tile.dart, todo_section.dart

import 'package:flutter/material.dart';

import '../models/enums.dart';

class AppMotion {
  AppMotion._();

  static const quick = Duration(milliseconds: 120);
  static const standard = Duration(milliseconds: 200);
  static const emphasized = Duration(milliseconds: 300);
  static const standardCurve = Curves.easeOutCubic;
  static const emphasizedCurve = Curves.fastOutSlowIn;
}

extension BuildContextMotion on BuildContext {
  /// OSの「アニメーションを減らす」設定を画面側で参照する。
  bool get isReducedMotion => MediaQuery.of(this).disableAnimations;
}

class AppTheme {
  AppTheme._();

  /// Stitch の Deep Forest Green (#006D5B) をシードカラーに
  static const _seedColor = Color(0xFF006D5B);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final cs = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      fontFamily: 'NotoSansJP',
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        titleTextStyle: TextStyle(
          fontFamily: 'NotoSansJP',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surface,
        surfaceTintColor: cs.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.05),
        bodyLarge: TextStyle(fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(fontWeight: FontWeight.w400),
        bodySmall: TextStyle(fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.05),
        labelMedium: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.05),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: cs.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        filled: true,
        fillColor: cs.surfaceContainerLow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'NotoSansJP',
            fontWeight: FontWeight.w600,
            letterSpacing: 0.05,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: BorderSide(color: cs.outline),
          textStyle: const TextStyle(
            fontFamily: 'NotoSansJP',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: const StadiumBorder(),
        elevation: 2,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        extendedPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cs.surface,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'NotoSansJP',
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'NotoSansJP',
          fontWeight: FontWeight.w400,
          fontSize: 12,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: StadiumBorder(
          side: BorderSide(color: cs.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        labelStyle: const TextStyle(
          fontFamily: 'NotoSansJP',
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withValues(alpha: 0.5),
        space: 1,
        thickness: 0.5,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        side: BorderSide(color: cs.outline),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return cs.primary;
          return null;
        }),
      ),
    );
  }
}

class CategoryColors {
  CategoryColors._();

  static const payment = Color(0xFFFFA726);
  static const submit = Color(0xFF42A5F5);
  static const event = Color(0xFFAB47BC);
  static const item = Color(0xFF006D5B);
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
