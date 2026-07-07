# UI Visual Refresh Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refresh the app's visual design with proper theming, category color accents, unified spacing, and improved empty states — no new dependencies.

**Architecture:** Centralize all theme definitions in `app_theme.dart` (single source of truth). Add category-specific accent colors. Replace ad-hoc spacing with 8-based constants. Update card styling (16dp radius, category color band). Improve empty states with emoji.

**Tech Stack:** Flutter Material 3 (no new packages), existing `ColorScheme.fromSeed`.

---

### Task 1: Create `app_theme.dart`

**Files:**
- Create: `lib/src/theme/app_theme.dart`

**Step 1: Create `app_theme.dart`**

Write the file with:

```dart
// lib/src/theme/app_theme.dart
// Material 3 テーマ定義を集中管理する
// すべての画面で一貫した見た目を保証する
// 関連: main.dart, todo_tile.dart, todo_section.dart

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    const seedColor = Color(0xFF2F7D6E);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardTheme(
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

// カテゴリ別アクセントカラー
class CategoryColors {
  CategoryColors._();

  static const payment = Color(0xFFFFA726); // Amber
  static const submit = Color(0xFF42A5F5); // Blue
  static const event = Color(0xFFAB47BC); // Purple
  static const item = Color(0xFF2F7D6E); // Teal
  static const other = Color(0xFF9E9E9E); // Grey
  static const completed = Color(0xFFBDBDBD); // Light grey for done

  static Color fromCategory(String category) {
    switch (category) {
      case 'payment':
        return payment;
      case 'submit':
        return submit;
      case 'event':
        return event;
      case 'item':
        return item;
      default:
        return other;
    }
  }
}

// スペーシング統一定数
class Spacing {
  Spacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}
```

**Step 2: Run analyze to verify no issues**

Run: `flutter analyze --no-fatal-infos`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/src/theme/app_theme.dart
git commit -m "feat(theme): add AppTheme, CategoryColors, Spacing constants"
```

---

### Task 2: Wire theme into `main.dart`

**Files:**
- Modify: `lib/main.dart`

**Step 1: Update `main.dart`**

Replace:
```dart
theme: ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F7D6E)),
  useMaterial3: true,
),
```

With:
```dart
import 'src/theme/app_theme.dart';

// ...

theme: AppTheme.light(),
```

**Step 2: Run analyze**

Run: `flutter analyze --no-fatal-infos`
Expected: No issues found

**Step 3: Run tests**

Run: `flutter test`
Expected: All 94 tests pass

**Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat(theme): wire AppTheme.light() into MaterialApp"
```

---

### Task 3: Update `TodoTile` with category color band and completion style

**Files:**
- Modify: `lib/src/screens/widgets/todo_tile.dart`

**Step 1: Read current file**

Run: Read `lib/src/screens/widgets/todo_tile.dart`

**Step 2: Update `TodoTile`**

- Add `CategoryColorBand` — a 4dp-wide container on the left side using `IntrinsicHeight`
- Color comes from `CategoryColors.fromCategory(todo.category)`
- When `todo.done`: band color → `CategoryColors.completed`, card opacity → 0.6 via `AnimatedOpacity`
- Wrap existing `Card` content in a `Row` with the band

**Step 3: Run analyze**

Run: `flutter analyze --no-fatal-infos`
Expected: No issues found

**Step 4: Run tests**

Run: `flutter test`
Expected: All 94 tests pass

**Step 5: Commit**

```bash
git add lib/src/screens/widgets/todo_tile.dart
git commit -m "feat(ui): add category color band and completion styling to TodoTile"
```

---

### Task 4: Update `EmptyState` and `NoSearchResults` with emoji

**Files:**
- Modify: `lib/src/screens/home_status_cards.dart`

**Step 1: Read current file**

Run: Read `lib/src/screens/home_status_cards.dart`

**Step 2: Update empty states**

- `EmptyState`: Replace `Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300])` with `Text('🎒', style: TextStyle(fontSize: 48))`
- `NoSearchResults`: Replace `Icon(Icons.search_off, size: 64, color: Colors.grey[300])` with `Text('🔍', style: TextStyle(fontSize: 48))`
- Replace hardcoded subtitle colors (`Colors.grey[400]`, `Colors.grey[500]`) with `Theme.of(context).colorScheme.onSurfaceVariant`
- Use `Spacing` constants for padding/vertical spacing

**Step 3: Run analyze + test**

Run: `flutter analyze --no-fatal-infos && flutter test`
Expected: Pass

**Step 4: Commit**

```bash
git add lib/src/screens/home_status_cards.dart
git commit -m "feat(ui): improve empty states with emoji and theme colors"
```

---

### Task 5: Update `TodoSection` with spacing constants

**Files:**
- Modify: `lib/src/screens/widgets/todo_section.dart`

**Step 1: Read current file**

**Step 2: Replace spacing literals**

- Replace `SizedBox(height: 8)` → `SizedBox(height: Spacing.sm)` etc.
- Ensure section headers use `titleMedium` with `colorScheme.primary` + `FontWeight.w600`
- Use `Spacing` constants for card padding

**Step 3: Run analyze + test**

Run: `flutter analyze --no-fatal-infos && flutter test`
Expected: Pass

**Step 4: Commit**

```bash
git add lib/src/screens/widgets/todo_section.dart
git commit -m "style(ui): use spacing constants in TodoSection"
```

---

### Task 6: Replace spacing literals in remaining screens

**Files:**
- Modify: `lib/src/screens/home_screen.dart`
- Modify: `lib/src/screens/add_todo_screen.dart`
- Modify: `lib/src/screens/add_child_screen.dart`
- Modify: `lib/src/screens/todo_detail_screen.dart`
- Modify: `lib/src/screens/settings_screen.dart`
- Modify: `lib/src/screens/review_extraction_screen.dart`
- Modify: `lib/src/screens/widgets/filter_bar.dart`

**Step 1: Process each file**

For each file:
- Read the file
- Replace `EdgeInsets.all(16)` → `EdgeInsets.all(Spacing.md)` etc.
- Replace `EdgeInsets.fromLTRB(16, 8, 16, ...)` → `EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, ...)`
- Replace `SizedBox(height: 8)` → `SizedBox(height: Spacing.sm)`
- Replace `SizedBox(height: 16)` → `SizedBox(height: Spacing.md)`
- Replace `SizedBox(height: 24)` → `SizedBox(height: Spacing.lg)`
- Replace hardcoded grey colors → `colorScheme.onSurfaceVariant` / `outlineVariant`
- DO NOT change any layout logic or widget structure

**Step 2: Run analyze + test after each file**

Run: `flutter analyze --no-fatal-infos && flutter test`

**Step 3: Commit each file separately**

```bash
git add lib/src/screens/<file>
git commit -m "style(<screen>): use spacing constants"
```

---

### Task 7: Final verification

**Step 1: Full analyze**

Run: `flutter analyze --no-fatal-infos`
Expected: No issues found

**Step 2: Full test suite**

Run: `flutter test`
Expected: All 94 tests pass

**Step 3: Final commit if needed**

**Step 4: Summary**

Report:
- Files created: 1 (`app_theme.dart`)
- Files modified: ~9 screen/widget files
- Test count: 94 (unchanged, all passing)
- Analyze: no issues
