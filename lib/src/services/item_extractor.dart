// lib/src/services/item_extractor.dart
// OCR テキストから持ち物・提出物を辞書引きで抽出する。
// 関連: extraction_service.dart

import '../models/enums.dart';

class ItemExtractor {
  ItemExtractor._();

  static const itemDictionary = <String>[
    '水筒',
    '上履き',
    '上履き袋',
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

  static List<String> extract(
    String text,
    Iterable<String> learnedItemLabels,
  ) {
    final itemCandidates = _itemCandidates(learnedItemLabels);
    final selectedPositions = <String, int>{};
    final coveredSpans = <_MatchSpan>[];

    for (final item in itemCandidates) {
      final matches = _findMatches(text, item);
      if (matches.isEmpty) continue;

      // 長い語の範囲内にしか現れない短い語は同一項目として抑制する。
      // 一方、別の位置にも明記されていれば、上履き／上履き袋のように両方残す。
      final standaloneMatches = matches
          .where(
            (match) => !coveredSpans.any((covered) => covered.contains(match)),
          )
          .toList(growable: false);
      if (standaloneMatches.isEmpty) continue;

      selectedPositions[item] = standaloneMatches.first.start;
      coveredSpans.addAll(standaloneMatches);
    }

    final found = selectedPositions.entries.toList(growable: false);
    found.sort((a, b) => a.value.compareTo(b.value));
    return found.map((entry) => entry.key).toList(growable: false);
  }

  static List<_MatchSpan> _findMatches(String text, String item) {
    final matches = <_MatchSpan>[];
    if (item.isEmpty) return matches;

    var offset = 0;
    while (offset <= text.length - item.length) {
      final index = text.indexOf(item, offset);
      if (index < 0) break;
      matches.add(_MatchSpan(index, index + item.length));
      offset = index + item.length;
    }
    return matches;
  }

  static List<String> _itemCandidates(Iterable<String> learnedItemLabels) {
    final labels = <String>{
      ...itemDictionary,
      ...learnedItemLabels
          .map((label) => label.trim())
          .where((label) => label.isNotEmpty),
    }.toList(growable: false);
    labels.sort((a, b) => b.length.compareTo(a.length));
    return labels;
  }

  static TodoCategory inferCategory(
    String text,
    int? amount,
    List<String> items,
  ) {
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

  static String makeTitle(
    String text,
    TodoCategory category,
    List<String> items,
    int? amount, {
    bool needsDueDateConfirmation = false,
  }) {
    final String title;
    switch (category) {
      case TodoCategory.payment:
        title = amount == null ? '集金を確認' : '集金 $amount円';
      case TodoCategory.submit:
        final submitItem = items.firstWhere(
          (e) => e.contains('申込書') || e.contains('同意書') || e.contains('封筒'),
          orElse: () => '',
        );
        title = submitItem.isEmpty ? '提出物を確認' : '$submitItemを提出';
      case TodoCategory.item:
        title = items.isEmpty ? '持ち物を確認' : '持ち物：${items.take(3).join('・')}';
      case TodoCategory.event:
        title = '行事予定を確認';
      case TodoCategory.other:
        final firstLine = text
            .split('\n')
            .where((e) => e.trim().isNotEmpty)
            .firstOrNull;
        title = firstLine == null
            ? 'プリントを確認'
            : firstLine.length > 24
            ? '${firstLine.substring(0, 24)}…'
            : firstLine;
    }
    if (!needsDueDateConfirmation) return title;
    if (title.startsWith('期限確認：')) return title;
    return '期限確認：$title';
  }
}

class _MatchSpan {
  const _MatchSpan(this.start, this.end);

  final int start;
  final int end;

  bool contains(_MatchSpan other) => start <= other.start && end >= other.end;
}
