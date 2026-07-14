// lib/src/models/document_record.dart
// 撮影/スキャンした書類レコード（画像パス、OCRテキスト）を保持するモデル。
// スナップショット内でドキュメント一覧を管理するために存在する。
// 関連: entities.dart, app_snapshot.dart

import 'package:flutter/foundation.dart';

@immutable
class DocumentRecord {
  const DocumentRecord({
    required this.id,
    required this.sourceType,
    required this.createdAt,
    required this.updatedAt,
    this.localImagePath,
    this.ocrText,
  });

  final String id;
  final String sourceType;
  final String? localImagePath;
  final String? ocrText;
  final DateTime createdAt;
  final DateTime updatedAt;

  DocumentRecord copyWith({
    String? id,
    String? sourceType,
    String? localImagePath,
    String? ocrText,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearLocalImagePath = false,
  }) {
    return DocumentRecord(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      localImagePath: clearLocalImagePath
          ? null
          : localImagePath ?? this.localImagePath,
      ocrText: ocrText ?? this.ocrText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceType': sourceType,
    'localImagePath': localImagePath,
    'ocrText': ocrText,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory DocumentRecord.fromJson(Map<String, dynamic> json) => DocumentRecord(
    id: (json['id'] as String?) ?? '',
    sourceType: (json['sourceType'] as String?) ?? '',
    localImagePath: json['localImagePath'] as String?,
    ocrText: json['ocrText'] as String?,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );
}
