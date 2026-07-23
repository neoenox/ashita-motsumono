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
    return DocumentRecord(
      id: id,
      sourceType: sourceType,
      localImagePath: json['localImagePath'] as String?,
      ocrText: json['ocrText'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
