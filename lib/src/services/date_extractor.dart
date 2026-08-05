// lib/src/services/date_extractor.dart
// OCR テキストから日付を抽出する。相対日付、曜日指定、具体日に対応。
// 関連: extraction_service.dart

class DateExtractor {
  DateExtractor._();

  static final _fullDatePattern = RegExp(
    r'(20\d{2})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日?',
  );
  static final _monthDayPattern = RegExp(r'(\d{1,2})\s*月\s*(\d{1,2})\s*日?');
  static final _slashDatePattern = RegExp(
    r'(?<![\d第])(\d{1,2})\s*[/\-]\s*(\d{1,2})(?!\s*(?:組|教室|回|番|\d))',
  );
  static final _relativeDatePattern = RegExp(r'(明後日|翌日|明日|今日|本日)');
  static final _relativeWeekdayPattern = RegExp(
    r'(今週|来週|次の)の?\s*([月火水木金土日])曜(?:日)?',
  );
  static final _ambiguousDeadlinePattern = RegExp(
    r'(今月末|月末|始業式の日|終業式の日|入学式の日|卒園式の日|卒業式の日|運動会の日|遠足の日)',
  );
  static final _strongDeadlineKeywordPattern = RegExp(
    r'(提出期限|提出日|持参日|締切|期限|まで)',
  );
  static final _actionDateKeywordPattern = RegExp(r'(提出|持参)');

  static const _deadlineSearchRadius = 32;

  static const _weekdayMap = <String, int>{
    '月': DateTime.monday,
    '火': DateTime.tuesday,
    '水': DateTime.wednesday,
    '木': DateTime.thursday,
    '金': DateTime.friday,
    '土': DateTime.saturday,
    '日': DateTime.sunday,
  };

  static DateTime? extract(String text, DateTime now) {
    DateTime? result = _extractDeadlineDate(text, now);
    result ??= _extractRelativeDate(text, now);
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

  static DateTime? _extractDeadlineDate(String text, DateTime now) {
    final candidates = _dateCandidates(text, now);
    if (candidates.isEmpty) return null;

    return _nearestDateForKeywords(
          text,
          candidates,
          _strongDeadlineKeywordPattern,
        ) ??
        _nearestDateForKeywords(text, candidates, _actionDateKeywordPattern);
  }

  static DateTime? _nearestDateForKeywords(
    String text,
    List<_DateCandidate> candidates,
    RegExp keywordPattern,
  ) {
    _DateCandidate? best;
    var bestDistance = _deadlineSearchRadius + 1;
    var bestIsAfterKeyword = false;

    for (final keyword in keywordPattern.allMatches(text)) {
      for (final candidate in candidates) {
        final distance = _distanceBetween(candidate, keyword);
        if (distance > _deadlineSearchRadius) continue;
        final isAfterKeyword = candidate.start >= keyword.end;
        if (distance < bestDistance ||
            (distance == bestDistance &&
                isAfterKeyword &&
                !bestIsAfterKeyword)) {
          best = candidate;
          bestDistance = distance;
          bestIsAfterKeyword = isAfterKeyword;
        }
      }
    }

    return best?.value;
  }

  static int _distanceBetween(_DateCandidate candidate, RegExpMatch keyword) {
    if (candidate.end <= keyword.start) {
      return keyword.start - candidate.end;
    }
    if (candidate.start >= keyword.end) {
      return candidate.start - keyword.end;
    }
    return 0;
  }

  static List<_DateCandidate> _dateCandidates(String text, DateTime now) {
    final candidates = <_DateCandidate>[];

    for (final match in _fullDatePattern.allMatches(text)) {
      final value = _safeDate(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
      if (value != null) {
        candidates.add(_DateCandidate(value, match.start, match.end));
      }
    }

    for (final match in _monthDayPattern.allMatches(text)) {
      final value = _futureMonthDay(
        now,
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
      );
      if (value != null) {
        candidates.add(_DateCandidate(value, match.start, match.end));
      }
    }

    for (final match in _slashDatePattern.allMatches(text)) {
      final value = _futureMonthDay(
        now,
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
      );
      if (value != null) {
        candidates.add(_DateCandidate(value, match.start, match.end));
      }
    }

    for (final match in _relativeDatePattern.allMatches(text)) {
      final value = _extractRelativeDate(match.group(0)!, now);
      if (value != null) {
        candidates.add(_DateCandidate(value, match.start, match.end));
      }
    }

    for (final match in _relativeWeekdayPattern.allMatches(text)) {
      final value = _extractRelativeWeekday(match.group(0)!, now);
      if (value != null) {
        candidates.add(_DateCandidate(value, match.start, match.end));
      }
    }

    return candidates;
  }

  static bool hasAmbiguousDeadline(String text) {
    if (!_ambiguousDeadlinePattern.hasMatch(text)) return false;
    return text.contains('まで') ||
        text.contains('締切') ||
        text.contains('期限') ||
        text.contains('持参') ||
        text.contains('提出');
  }

  static DateTime? _extractRelativeDate(String text, DateTime now) {
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

  static DateTime? _extractConcreteDate(String text) {
    final full = _fullDatePattern.firstMatch(text);
    if (full == null) return null;
    return _safeDate(
      int.parse(full.group(1)!),
      int.parse(full.group(2)!),
      int.parse(full.group(3)!),
    );
  }

  static DateTime? _extractMonthDayDate(String text, DateTime now) {
    final match = _monthDayPattern.firstMatch(text);
    if (match == null) return null;
    return _futureMonthDay(
      now,
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
    );
  }

  static DateTime? _extractSlashDate(String text, DateTime now) {
    final match = _slashDatePattern.firstMatch(text);
    if (match == null) return null;
    return _futureMonthDay(
      now,
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
    );
  }

  static DateTime? _extractRelativeWeekday(String text, DateTime now) {
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

  static DateTime? _safeDate(int year, int month, int day) {
    try {
      final value = DateTime(year, month, day);
      if (value.month != month || value.day != day) return null;
      return value;
    } on Object {
      return null;
    }
  }

  static bool hasPastMonthDayDate(String text, DateTime now) {
    final match =
        _monthDayPattern.firstMatch(text) ?? _slashDatePattern.firstMatch(text);
    if (match == null) return false;
    final month = int.parse(match.group(1)!);
    final day = int.parse(match.group(2)!);
    final dateThisYear = _safeDate(now.year, month, day);
    if (dateThisYear == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    return dateThisYear.isBefore(today);
  }

  static DateTime? _futureMonthDay(DateTime now, int month, int day) {
    final thisYear = _safeDate(now.year, month, day);
    if (thisYear == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    if (!thisYear.isBefore(today)) return thisYear;
    // 過去の月日は黙って翌年にロールせず、呼び出し元で確認を促す
    return null;
  }
}

class _DateCandidate {
  const _DateCandidate(this.value, this.start, this.end);

  final DateTime value;
  final int start;
  final int end;
}
