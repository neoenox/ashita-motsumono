import 'package:flutter/foundation.dart';

import 'document_page_record.dart';

@immutable
class DocumentRecord {
  const DocumentRecord({
    required this.id,
    required this.sourceType,
    required this.createdAt,
    required this.updatedAt,
    this.localImagePath,
    this.ocrText,
    this.sourceMimeType,
    this.sourceFingerprint,
    this.pages = const [],
  });

  final String id;
  final String sourceType;
  final String? localImagePath;
  final String? ocrText;
  final String? sourceMimeType;
  final String? sourceFingerprint;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DocumentPageRecord> pages;

  DocumentRecord copyWith({
    String? id,
    String? sourceType,
    String? localImagePath,
    String? ocrText,
    String? sourceMimeType,
    String? sourceFingerprint,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<DocumentPageRecord>? pages,
    bool clearLocalImagePath = false,
    bool clearSourceFingerprint = false,
    bool clearPages = false,
  }) {
    return DocumentRecord(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      localImagePath: clearLocalImagePath
          ? null
          : localImagePath ?? this.localImagePath,
      ocrText: ocrText ?? this.ocrText,
      sourceMimeType: sourceMimeType ?? this.sourceMimeType,
      sourceFingerprint: clearSourceFingerprint
          ? null
          : sourceFingerprint ?? this.sourceFingerprint,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pages: clearPages ? [] : pages ?? this.pages,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceType': sourceType,
    'localImagePath': localImagePath,
    'ocrText': ocrText,
    'sourceMimeType': sourceMimeType,
    'sourceFingerprint': sourceFingerprint,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'pages': pages.map((p) => p.toJson()!).toList(),
  };

  factory DocumentRecord.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final sourceType = json['sourceType'];
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('DocumentRecord.id is invalid');
    }
    if (sourceType is! String || sourceType.trim().isEmpty) {
      throw const FormatException('DocumentRecord.sourceType is invalid');
    }
    if (createdAt == null || updatedAt == null) {
      throw const FormatException('DocumentRecord dates are invalid');
    }
    final pagesList = <DocumentPageRecord>[];
    final rawPages = json['pages'];
    if (rawPages is List) {
      for (final p in rawPages) {
        if (p is Map<String, dynamic>) {
          pagesList.add(DocumentPageRecord.fromJson(p));
        }
      }
    }
    return DocumentRecord(
      id: id,
      sourceType: sourceType,
      localImagePath: json['localImagePath'] as String?,
      ocrText: json['ocrText'] as String?,
      sourceMimeType: json['sourceMimeType'] as String?,
      sourceFingerprint: json['sourceFingerprint'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
      pages: pagesList,
    );
  }
}
