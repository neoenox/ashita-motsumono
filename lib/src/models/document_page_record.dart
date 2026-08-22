// lib/src/models/document_page_record.dart
// 文書の1ページを表すモデル。PDFや複数画像のページ単位データを保持する。
// 関連: document_record.dart, app_database.dart, entities.dart

import 'package:flutter/foundation.dart';

@immutable
class DocumentPageRecord {
  const DocumentPageRecord({
    required this.id,
    required this.documentId,
    required this.pageIndex,
    required this.localImagePath,
    required this.ocrText,
  });

  final String id;
  final String documentId;
  final int pageIndex;
  final String localImagePath;
  final String ocrText;

  DocumentPageRecord copyWith({
    String? id,
    String? documentId,
    int? pageIndex,
    String? localImagePath,
    String? ocrText,
  }) {
    return DocumentPageRecord(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      pageIndex: pageIndex ?? this.pageIndex,
      localImagePath: localImagePath ?? this.localImagePath,
      ocrText: ocrText ?? this.ocrText,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'documentId': documentId,
    'pageIndex': pageIndex,
    'ocrText': ocrText,
  };

  factory DocumentPageRecord.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final documentId = json['documentId'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('DocumentPageRecord.id is invalid');
    }
    if (documentId is! String || documentId.trim().isEmpty) {
      throw const FormatException('DocumentPageRecord.documentId is invalid');
    }
    return DocumentPageRecord(
      id: id,
      documentId: documentId,
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      localImagePath: (json['localImagePath'] as String?) ?? '',
      ocrText: (json['ocrText'] as String?) ?? '',
    );
  }
}
