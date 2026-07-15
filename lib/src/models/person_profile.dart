// lib/src/models/person_profile.dart
// 人物のプロフィール（ID、名前、カラー、タイムスタンプ）を保持するモデル。
// スナップショット内で複数の人物を管理するために存在する。
// 関連: entities.dart, app_snapshot.dart

import 'package:flutter/foundation.dart';

@immutable
class PersonProfile {
  const PersonProfile({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int colorValue;
  final DateTime createdAt;
  final DateTime updatedAt;

  PersonProfile copyWith({
    String? id,
    String? name,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PersonProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PersonProfile.fromJson(Map<String, dynamic> json) => PersonProfile(
        id: (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        colorValue: (json['colorValue'] as int?) ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );
}
