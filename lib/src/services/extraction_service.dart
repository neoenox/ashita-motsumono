// lib/src/services/extraction_service.dart
// OCR テキストから日付・金額・持ち物・カテゴリを抽出し、ExtractionDraft を生成する。
// パターンマッチベース（ML/LLM不使用）。MVP では辞書引き＋正規表現で十分。
// 関連: models/entities.dart, screens/review_extraction_screen.dart, screens/add_todo_screen.dart,
//       ../utils/text_normalizer.dart, date_extractor.dart, item_extractor.dart

import '../models/entities.dart';
import '../utils/text_normalizer.dart';
import 'date_extractor.dart';
import 'item_extractor.dart';

class ExtractionService {
  static ExtractionDraft extract(
    String rawText, {
    DateTime? now,
    Iterable<String> learnedItemLabels = const [],
  }) {
    final current = now ?? DateTime.now();
    final text = TextNormalizer.normalize(rawText);
    final dueDate = DateExtractor.extract(text, current);
    final amount = _extractAmount(text);
    final items = ItemExtractor.extract(text, learnedItemLabels);
    final category = ItemExtractor.inferCategory(text, amount, items);
    final title = ItemExtractor.makeTitle(
      text,
      category,
      items,
      amount,
      needsDueDateConfirmation:
          dueDate == null &&
          (DateExtractor.hasAmbiguousDeadline(text) ||
              DateExtractor.hasPastMonthDayDate(text, current)),
    );

    return ExtractionDraft(
      title: title,
      category: category,
      dueDate: dueDate,
      amount: amount,
      items: items,
      note: text.length > 500 ? '${_safeTruncate(text, 500)}...' : text,
      rawText: text,
    );
  }

  /// コードユニット境界でサロゲートペア（絵文字等）を分割しない切り詰め。
  static String _safeTruncate(String text, int maxCodeUnits) {
    var end = maxCodeUnits;
    while (end > 0 &&
        text.codeUnitAt(end - 1) >= 0xD800 &&
        text.codeUnitAt(end - 1) <= 0xDBFF) {
      end--;
    }
    return text.substring(0, end);
  }

  static List<ExtractionDraft> extractMany(
    String rawText, {
    DateTime? now,
    Iterable<String> learnedItemLabels = const [],
  }) {
    final current = now ?? DateTime.now();
    final text = TextNormalizer.normalize(rawText);
    final segments = _splitCandidateTexts(text);
    final drafts = <ExtractionDraft>[];
    final seen = <String>{};

    for (final segment in segments) {
      final draft = extract(
        segment,
        now: current,
        learnedItemLabels: learnedItemLabels,
      );
      if (!_isActionableDraft(draft)) continue;
      final key = [
        draft.title,
        draft.category.name,
        draft.dueDate?.toIso8601String() ?? '',
        draft.amount?.toString() ?? '',
        draft.items.join('|'),
      ].join('\u0000');
      if (seen.add(key)) {
        drafts.add(draft);
      }
    }

    if (drafts.length < 2) {
      final fallback = extract(
        text,
        now: current,
        learnedItemLabels: learnedItemLabels,
      );
      return _isActionableDraft(fallback) ? [fallback] : [];
    }
    return drafts;
  }

  static String normalize(String input) => TextNormalizer.normalize(input);

  static List<String> _splitCandidateTexts(String text) {
    return text
        .split(RegExp(r'(?:\r?\n)+|[。．.!！?？]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  static bool _isActionableDraft(ExtractionDraft draft) {
    if (draft.category != TodoCategory.other) return true;
    if (draft.dueDate != null) return true;
    if (draft.amount != null) return true;
    return draft.items.isNotEmpty;
  }

  static final _yenAmountPattern = RegExp(r'¥\s*([0-9,]+)');
  static final _yenSuffixPattern = RegExp(r'([0-9,]+)\s*円');
  static final _amountKeywordPattern = RegExp(r'(集金|代金|納付|負担)');
  static const _amountKeywordRadius = 20;

  static int? _extractAmount(String text) {
    final allMatches = [
      for (final pattern in [_yenAmountPattern, _yenSuffixPattern])
        ...pattern.allMatches(text),
    ];
    final match =
        allMatches
            .where((candidate) => _nearAmountKeyword(text, candidate))
            .firstOrNull ??
        _firstAmountMatch(text);
    if (match != null) {
      return int.tryParse(match.group(1)!.replaceAll(',', ''));
    }
    return null;
  }

  static RegExpMatch? _firstAmountMatch(String text) {
    for (final pattern in [_yenAmountPattern, _yenSuffixPattern]) {
      final match = pattern.firstMatch(text);
      if (match != null) return match;
    }
    return null;
  }

  static bool _nearAmountKeyword(String text, RegExpMatch amount) {
    for (final keyword in _amountKeywordPattern.allMatches(text)) {
      final distance = amount.start >= keyword.end
          ? amount.start - keyword.end
          : keyword.start - amount.end;
      if (distance <= _amountKeywordRadius) return true;
    }
    return false;
  }
}
