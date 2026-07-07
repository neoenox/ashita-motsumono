# UI ビジュアルリフレッシュ設計

- **日付**: 2026-07-07
- **ステータス**: 設計完了（実装待ち）

## ゴール

「あした持つもの」のUIを、Material 3 をベースに温かみのある見た目に改善する。余計な依存を増やさず、テーマ定義の集中化と微調整でプロっぽく、かつ親しみやすい印象にする。

## スコープ

### 含む
- テーマ定義の集中管理（`lib/src/theme/app_theme.dart` 新規）
- カード角丸 12→16dp、カテゴリ色帯の追加
- タイポグラフィのメリハリ（ウェイト設定）
- スペーシングの 8 の倍数統一
- 空状態の見た目改善（絵文字・メッセージ）
- 完了Todoの視覚表現（opacity + 帯グレー化）
- テーマ未使用のハードコード色を `colorScheme` 参照に置き換え

### 含まない（将来）
- 画面遷移アニメーション
- フォント追加（google_fonts 等の依存追加）
- ダークモード
- 大規模なレイアウト変更

## 設計

### 1. テーマ基盤

`lib/src/theme/app_theme.dart` を作成し、以下を定義：

- `AppTheme.light()` → `ThemeData` を返す
- 今の seed color `#2F7D6E` を維持
- `AppBarTheme`: backgroundColor を surface、elevation 0
- `CardTheme`: elevation 1、shape RoundedRectangleBorder(borderRadius: 16)
- `TextTheme`: 各スタイルに fontWeight を設定（headlineSmall=w600, titleLarge=w500, titleMedium=w600(with primary color), bodyLarge=w500 for todo titles）
- `InputDecorationTheme`: border radius 統一
- `FilledButtonTheme`: shape を少し丸く（12dp）

### 2. カテゴリ色

Todoのカテゴリに応じたアクセントカラーを `ColorScheme` の extended color として定義：

| カテゴリ | 色 |
|---|---|
| payment（支払い） | Amber |
| submit（提出） | Blue |
| event（イベント） | Purple |
| item（持ち物） | Teal（今の primary と同系） |
| other（その他） | Grey/Neutral |

### 3. カード左端の色帯

各 `Card` の先頭に 4dp 幅のカラムを `IntrinsicHeight` で配置。色はカテゴリに応じて変わる。TodoSection と TodoTile に適用。

### 4. スペーシング定数

`lib/src/theme/app_theme.dart` または別ファイルに定数定義：

```
spacingXs = 4
spacingSm = 8
spacingMd = 16
spacingLg = 24
spacingXl = 32
```

既存の全画面で使われている `<int>` リテラルを上記定数に置き換え。

### 5. 空状態

- `EmptyState`: `Icon` → `Text("🎒")` or `Text("📋")` を fontSize 48 で表示。サブテキストの色は `ColorScheme.onSurfaceVariant`
- `NoSearchResults`: 同様に `Text("🔍")` + メッセージ改善
- `CorruptDataCard`: 今のまま（エラー状態はシリアスに）

### 6. 完了Todo

- `TodoTile` に `AnimatedOpacity` を追加（0.6）
- カテゴリ色帯を `Colors.grey` に変更
- 取り消し線は維持

## 変更ファイル一覧

| ファイル | 変更内容 |
|---|---|
| `lib/src/theme/app_theme.dart` | **新規** - 全テーマ定義 |
| `lib/main.dart` | theme: → `AppTheme.light()` に置き換え |
| `lib/src/screens/widgets/todo_tile.dart` | 左端色帯追加、完了時 opacity |
| `lib/src/screens/widgets/todo_section.dart` | カード角丸・色帯・spacing 適用 |
| `lib/src/screens/widgets/filter_bar.dart` | spacing 定数化 |
| `lib/src/screens/home_status_cards.dart` | 空状態の見た目改善、spacing |
| `lib/src/screens/home_screen.dart` | spacing 定数化 |
| `lib/src/screens/add_todo_screen.dart` | spacing 定数化 |
| `lib/src/screens/add_child_screen.dart` | spacing 定数化 |
| `lib/src/screens/todo_detail_screen.dart` | spacing 定数化 |
| `lib/src/screens/settings_screen.dart` | spacing 定数化 |
| `lib/src/screens/review_extraction_screen.dart` | spacing 定数化 |

## レビューポイント

- 新規ファイルが1つだけ（`app_theme.dart`）
- 既存の挙動は変えない（見た目のみ）
- テストへの影響は最小（widget_test のマッチャが色・サイズを見ていない限り不要）
