import 'dart:math';

class Room {
  final String id;
  final String hostId;
  final String title;
  final String? description;
  final String roomType;
  final List<String> topicTags;
  final int maxParticipants;
  final int participantCount;
  final double? hostLat;
  final double? hostLng;
  final String status;
  final int qualityScore;
  final DateTime lastActivityAt;
  final DateTime createdAt;

  // Joined from profiles
  final String? hostName;
  final String? hostPhotoUrl;

  // Computed client-side
  final double? distanceKm;

  Room({
    required this.id,
    required this.hostId,
    required this.title,
    this.description,
    this.roomType = 'text',
    this.topicTags = const [],
    this.maxParticipants = 10,
    this.participantCount = 0,
    this.hostLat,
    this.hostLng,
    this.status = 'active',
    this.qualityScore = 0,
    required this.lastActivityAt,
    required this.createdAt,
    this.hostName,
    this.hostPhotoUrl,
    this.distanceKm,
  });

  factory Room.fromJson(Map<String, dynamic> json, {double? userLat, double? userLng}) {
    final host = json['host_profile'] as Map<String, dynamic>?;
    final hLat = (json['host_lat'] as num?)?.toDouble();
    final hLng = (json['host_lng'] as num?)?.toDouble();

    double? dist;
    if (userLat != null && userLng != null && hLat != null && hLng != null) {
      dist = _haversine(userLat, userLng, hLat, hLng);
    }

    final tags = json['topic_tags'];

    return Room(
      id: json['id'] as String,
      hostId: json['host_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      roomType: json['room_type'] as String? ?? 'text',
      topicTags: tags is List ? tags.cast<String>() : const [],
      maxParticipants: json['max_participants'] as int? ?? 10,
      participantCount: json['participant_count'] as int? ?? 0,
      hostLat: hLat,
      hostLng: hLng,
      status: json['status'] as String? ?? 'active',
      qualityScore: json['quality_score'] as int? ?? 0,
      lastActivityAt: DateTime.parse(json['last_activity_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      hostName: host?['display_name'] as String?,
      hostPhotoUrl: host?['date_avatar_url'] as String?,
      distanceKm: dist,
    );
  }

  bool get isActive => status == 'active';
  bool get isFull => participantCount >= maxParticipants;
  double get fillPercent =>
      maxParticipants > 0 ? (participantCount / maxParticipants).clamp(0.0, 1.0) : 0;

  String get distanceLabel {
    if (distanceKm == null) return 'Nearby';
    if (distanceKm! < 1) return '${(distanceKm! * 1000).round()} m away';
    if (distanceKm! < 10) return '${distanceKm!.toStringAsFixed(1)} km away';
    return '${distanceKm!.round()} km away';
  }

  String get ageLabel {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return 2 * r * asin(sqrt(a));
  }

  static double _rad(double deg) => deg * (pi / 180);
}
