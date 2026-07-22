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

  factory PersonProfile.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final colorValue = json['colorValue'];
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('PersonProfile.id is invalid');
    }
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('PersonProfile.name is invalid');
    }
    if (colorValue is! int || createdAt == null || updatedAt == null) {
      throw const FormatException('PersonProfile fields are invalid');
    }
    return PersonProfile(
      id: id,
      name: name,
      colorValue: colorValue,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
