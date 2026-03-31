import 'package:flutter/material.dart';

class BffPlan {
  final String id;
  final String conversationId;
  final String createdBy;
  final String planType;
  final String? location;
  final DateTime scheduledAt;
  final String status;
  final DateTime createdAt;

  BffPlan({
    required this.id,
    required this.conversationId,
    required this.createdBy,
    required this.planType,
    this.location,
    required this.scheduledAt,
    required this.status,
    required this.createdAt,
  });

  factory BffPlan.fromJson(Map<String, dynamic> json) {
    return BffPlan(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      createdBy: json['created_by'] as String,
      planType: json['plan_type'] as String,
      location: json['location'] as String?,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      status: json['status'] as String? ?? 'proposed',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isProposed => status == 'proposed';
  bool get isAccepted => status == 'accepted';

  String get typeLabel => _planTypes[planType]?.label ?? planType;
  String get typeEmoji => _planTypes[planType]?.emoji ?? '';
  IconData get typeIcon => _planTypes[planType]?.icon ?? Icons.event;
}

class _PlanType {
  final String label;
  final String emoji;
  final IconData icon;
  const _PlanType(this.label, this.emoji, this.icon);
}

const _planTypes = {
  'coffee': _PlanType('Coffee', '\u2615', Icons.coffee_rounded),
  'walk': _PlanType('Walk', '\ud83d\udeb6', Icons.directions_walk_rounded),
  'cowork': _PlanType('Work together', '\ud83d\udcbb', Icons.laptop_rounded),
  'culture': _PlanType('Bookstore / Exhibition', '\ud83d\udcda', Icons.museum_rounded),
  'city': _PlanType('Short city plan', '\ud83c\udfd9', Icons.location_city_rounded),
};

const bffPlanTypes = ['coffee', 'walk', 'cowork', 'culture', 'city'];
