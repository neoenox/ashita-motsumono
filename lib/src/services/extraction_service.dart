// lib/src/services/extraction_service.dart
// OCR テキストから日付・金額・持ち物・カテゴリを抽出し、ExtractionDraft を生成する。
// パターンマッチベース（ML/LLM不使用）。MVP では辞書引き＋正規表現で十分。
// 関連: models/entities.dart, screens/review_extraction_screen.dart, screens/add_todo_screen.dart

import '../models/entities.dart';

class ExtractionService {
  static const itemDictionary = <String>[
    '水筒',
    '上履き',
    '体操着',
    '帽子',
    'タオル',
    'バスタオル',
    'ハンカチ',
    'ティッシュ',
    '着替え',
    'おむつ',
    'オムツ',
    'コップ',
    '歯ブラシ',
    '連絡帳',
    'プールバッグ',
    '水着',
    'ビニール袋',
    '集金袋',
    '申込書',
    '同意書',
    '返信用封筒',
    '筆記用具',
    '弁当',
    'お弁当',
    'レジャーシート',
    '雨具',
    '傘',
    '長靴',
    'マスク',
  ];

  ExtractionDraft extract(String rawText, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final text = normalize(rawText);
    final dueDate = _extractDate(text, current);
    final amount = _extractAmount(text);
    final items = _extractItems(text);
    final category = _inferCategory(text, amount, items);
    final title = _makeTitle(text, category, items, amount);

    return ExtractionDraft(
      title: title,
      category: category,
      dueDate: dueDate,
      amount: amount,
      items: items,
      note: text.length > 500 ? '${text.substring(0, 500)}...' : text,
      rawText: text,
    );
  }

  String normalize(String input) {
    final sb = StringBuffer();
    for (final codeUnit in input.codeUnits) {
      // 全角数字 (FF10-FF19) を半角 (30-39) に変換
      if (codeUnit >= 0xFF10 && codeUnit <= 0xFF19) {
        sb.writeCharCode(codeUnit - 0xFF10 + 0x30);
      } else {
        sb.writeCharCode(codeUnit);
      }
    }
    return sb
        .toString()
        .replaceAll('／', '/')
        .replaceAll('，', ',')
        .replaceAll('￥', '¥')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  DateTime? _extractDate(String text, DateTime now) {
    if (text.contains('明日')) {
      final d = now.add(const Duration(days: 1));
      return DateTime(d.year, d.month, d.day);
    }
    if (text.contains('今日') || text.contains('本日')) {
      return DateTime(now.year, now.month, now.day);
    }

    final full = RegExp(r'(20\d{2})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日?')
        .firstMatch(text);
    if (full != null) {
      return _safeDate(
        int.parse(full.group(1)!),
        int.parse(full.group(2)!),
        int.parse(full.group(3)!),
      );
    }

    final monthDay = RegExp(r'(\d{1,2})\s*月\s*(\d{1,2})\s*日?').firstMatch(text);
    if (monthDay != null) {
      return _futureMonthDay(
        now,
        int.parse(monthDay.group(1)!),
        int.parse(monthDay.group(2)!),
      );
    }

    final slash = RegExp(r'(?<!\d)(\d{1,2})\s*[/\-]\s*(\d{1,2})(?!\d)').firstMatch(text);
    if (slash != null) {
      return _futureMonthDay(
        now,
        int.parse(slash.group(1)!),
        int.parse(slash.group(2)!),
      );
    }

    return null;
  }

  DateTime? _safeDate(int year, int month, int day) {
    try {
      final value = DateTime(year, month, day);
      if (value.month != month || value.day != day) return null;
      return value;
    } on Object {
      return null;
    }
  }

  DateTime? _futureMonthDay(DateTime now, int month, int day) {
    final thisYear = _safeDate(now.year, month, day);
    if (thisYear == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    if (!thisYear.isBefore(today)) return thisYear;
    return _safeDate(now.year + 1, month, day);
  }

  int? _extractAmount(String text) {
    final patterns = [
      RegExp(r'¥\s*([0-9,]+)'),
      RegExp(r'([0-9,]+)\s*円'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return int.tryParse(match.group(1)!.replaceAll(',', ''));
      }
    }
    return null;
  }

  List<String> _extractItems(String text) {
    final found = <String>[];
    for (final item in itemDictionary) {
      // 辞書の各語をテキスト内で検索。text が短い前提で単純ループ。
      if (text.contains(item)) {
        found.add(item);
      }
    }
    return found;
  }

  TodoCategory _inferCategory(String text, int? amount, List<String> items) {
    if (amount != null || text.contains('集金') || text.contains('代金')) {
      return TodoCategory.payment;
    }
    if (text.contains('提出') || text.contains('返信') || text.contains('記入')) {
      return TodoCategory.submit;
    }
    if (text.contains('遠足') || text.contains('面談') || text.contains('行事')) {
      return TodoCategory.event;
    }
    if (items.isNotEmpty || text.contains('持参') || text.contains('持って')) {
      return TodoCategory.item;
    }
    return TodoCategory.other;
  }

  String _makeTitle(String text, TodoCategory category, List<String> items, int? amount) {
    switch (category) {
      case TodoCategory.payment:
        return amount == null ? '集金を確認' : '集金 ${amount}円';
      case TodoCategory.submit:
        final submitItem = items.firstWhere(
          (e) => e.contains('申込書') || e.contains('同意書') || e.contains('封筒'),
          orElse: () => '',
        );
        return submitItem.isEmpty ? '提出物を確認' : '$submitItemを提出';
      case TodoCategory.item:
        return items.isEmpty ? '持ち物を確認' : '持ち物：${items.take(3).join('・')}';
      case TodoCategory.event:
        return '行事予定を確認';
      case TodoCategory.other:
        final firstLine = text.split('\n').where((e) => e.trim().isNotEmpty).firstOrNull;
        if (firstLine == null) return 'プリントを確認';
        return firstLine.length > 24 ? '${firstLine.substring(0, 24)}…' : firstLine;
    }
  }
}
