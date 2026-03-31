class NobEvent {
  final String id;
  final String hostId;
  final String title;
  final String? description;
  final String? coverImageUrl;
  final DateTime eventDate;
  final String? locationText;
  final double? locationLat;
  final double? locationLng;
  final int maxAttendees;
  final bool plus3Enabled;
  final bool companionEnabled;
  final String status;
  final int qualityScore;
  final int attendeeCount;
  final DateTime createdAt;

  // Joined from profiles
  final String? hostName;
  final String? hostPhotoUrl;

  // User's own attendance
  final String? myAttendance;

  NobEvent({
    required this.id,
    required this.hostId,
    required this.title,
    this.description,
    this.coverImageUrl,
    required this.eventDate,
    this.locationText,
    this.locationLat,
    this.locationLng,
    required this.maxAttendees,
    this.plus3Enabled = false,
    this.companionEnabled = true,
    required this.status,
    this.qualityScore = 50,
    this.attendeeCount = 0,
    required this.createdAt,
    this.hostName,
    this.hostPhotoUrl,
    this.myAttendance,
  });

  factory NobEvent.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final host = json['host_profile'] as Map<String, dynamic>?;

    return NobEvent(
      id: json['id'] as String,
      hostId: json['host_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      eventDate: DateTime.parse(json['event_date'] as String),
      locationText: json['location_text'] as String?,
      locationLat: (json['location_lat'] as num?)?.toDouble(),
      locationLng: (json['location_lng'] as num?)?.toDouble(),
      maxAttendees: json['max_attendees'] as int? ?? 10,
      plus3Enabled: json['plus3_enabled'] as bool? ?? false,
      companionEnabled: json['companion_enabled'] as bool? ?? true,
      status: json['status'] as String? ?? 'active',
      qualityScore: json['quality_score'] as int? ?? 50,
      attendeeCount: json['attendee_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      hostName: host?['display_name'] as String?,
      hostPhotoUrl: host?['date_avatar_url'] as String?,
      myAttendance: json['my_attendance'] as String?,
    );
  }

  bool get isActive => status == 'active';
  bool get isLocked => status == 'locked';
  bool get isFull => attendeeCount >= maxAttendees;
  bool get isUpcoming => eventDate.isAfter(DateTime.now());
  bool get isAmHost => false; // set externally

  double get fillPercent =>
      maxAttendees > 0 ? (attendeeCount / maxAttendees).clamp(0.0, 1.0) : 0;

  String get timeLabel {
    final diff = eventDate.difference(DateTime.now());
    if (diff.isNegative) return 'Ended';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    return '${diff.inMinutes}m';
  }
}
