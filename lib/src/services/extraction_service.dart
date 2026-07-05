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
    '水泳カード',
    '検温表',
    '健康観察カード',
    'ビニール袋',
    '給食袋',
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
    '雑巾',
    'エプロン',
    '三角巾',
    '白い靴下',
    '靴下',
    '名札',
    '鍵盤ハーモニカ',
  ];

  // 長い語順にソート済み。_extractItems での重複排除に使う。
  static final _itemDictionaryByLength = List<String>.of(itemDictionary)
    ..sort((a, b) => b.length.compareTo(a.length));

  static final _fullDatePattern = RegExp(r'(20\d{2})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日?');
  static final _monthDayPattern = RegExp(r'(\d{1,2})\s*月\s*(\d{1,2})\s*日?');
  static final _slashDatePattern = RegExp(r'(?<!\d)(\d{1,2})\s*[/\-]\s*(\d{1,2})(?!\d)');
  static final _relativeWeekdayPattern = RegExp(r'(今週|来週|次の)の?\s*([月火水木金土日])曜(?:日)?');
  static final _yenAmountPattern = RegExp(r'¥\s*([0-9,]+)');
  static final _yenSuffixPattern = RegExp(r'([0-9,]+)\s*円');
  static final _multiSpacePattern = RegExp(r'[ \t]+');
  static final _multiNewlinePattern = RegExp(r'\n{3,}');

  static const _weekdayMap = <String, int>{
    '月': DateTime.monday,
    '火': DateTime.tuesday,
    '水': DateTime.wednesday,
    '木': DateTime.thursday,
    '金': DateTime.friday,
    '土': DateTime.saturday,
    '日': DateTime.sunday,
  };

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
        .replaceAll('O', '0')  // OCR誤認識: O→0
        .replaceAll('l', '1')  // OCR誤認識: l→1
        .replaceAll('　', ' ')
        .replaceAll(_multiSpacePattern, ' ')
        .replaceAll(_multiNewlinePattern, '\n\n')
        .trim();
  }

  DateTime? _extractDate(String text, DateTime now) {
    DateTime? result = _extractRelativeDate(text, now);
    result ??= _extractRelativeWeekday(text, now);
    result ??= _extractConcreteDate(text);
    result ??= _extractMonthDayDate(text, now);
    result ??= _extractSlashDate(text, now);

    // 前日まで → すべての日付タイプ（相対日付・曜日・具体日）に適用。
    // Duration(days: 1) ではなく DateTime(year, month, day-1) を使い、
    // DST 遷移時の時刻ズレを回避する。
    if (result != null && text.contains('前日まで')) {
      result = DateTime(result.year, result.month, result.day - 1);
    }
    return result;
  }

  DateTime? _extractRelativeDate(String text, DateTime now) {
    if (text.contains('明後日')) {
      return DateTime(now.year, now.month, now.day + 2);
    }
    if (text.contains('翌日') || text.contains('明日')) {
      return DateTime(now.year, now.month, now.day + 1);
    }
    if (text.contains('今日') || text.contains('本日')) {
      return DateTime(now.year, now.month, now.day);
    }
    return null;
  }

  DateTime? _extractConcreteDate(String text) {
    final full = _fullDatePattern.firstMatch(text);
    if (full == null) return null;
    return _safeDate(
      int.parse(full.group(1)!),
      int.parse(full.group(2)!),
      int.parse(full.group(3)!),
    );
  }

  DateTime? _extractMonthDayDate(String text, DateTime now) {
    final match = _monthDayPattern.firstMatch(text);
    if (match == null) return null;
    return _futureMonthDay(now, int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  DateTime? _extractSlashDate(String text, DateTime now) {
    final match = _slashDatePattern.firstMatch(text);
    if (match == null) return null;
    return _futureMonthDay(now, int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  DateTime? _extractRelativeWeekday(String text, DateTime now) {
    final match = _relativeWeekdayPattern.firstMatch(text);
    if (match == null) return null;

    final prefix = match.group(1)!;
    final weekday = _weekdayMap[match.group(2)!];
    if (weekday == null) return null;

    final today = DateTime(now.year, now.month, now.day);
    var delta = weekday - today.weekday;
    if (prefix == '来週') {
      delta += 7;
    } else if (prefix == '次の') {
      if (delta <= 0) delta += 7;
    } else if (delta < 0) {
      delta += 7;
    }
    return today.add(Duration(days: delta));
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
    for (final pattern in [_yenAmountPattern, _yenSuffixPattern]) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return int.tryParse(match.group(1)!.replaceAll(',', ''));
      }
    }
    return null;
  }

  List<String> _extractItems(String text) {
    final selected = <String>{};
    for (final item in _itemDictionaryByLength) {
      // 長い語を優先し、バスタオル→タオル、お弁当→弁当のような重複を避ける。
      if (text.contains(item) && !selected.any((existing) => existing.contains(item))) {
        selected.add(item);
      }
    }
    return itemDictionary.where(selected.contains).toList();
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
        return amount == null ? '集金を確認' : '集金 $amount円';
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
