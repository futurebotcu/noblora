class EventParticipant {
  final String id;
  final String eventId;
  final String userId;
  final String attendanceStatus;
  final int companionCount;
  final DateTime joinedAt;
  final String? displayName;
  final String? photoUrl;
  final bool isHost;

  EventParticipant({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.attendanceStatus,
    this.companionCount = 0,
    required this.joinedAt,
    this.displayName,
    this.photoUrl,
    this.isHost = false,
  });

  factory EventParticipant.fromJson(Map<String, dynamic> json, {bool isHost = false}) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return EventParticipant(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      attendanceStatus: json['attendance_status'] as String? ?? 'going',
      companionCount: json['companion_count'] as int? ?? 0,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      displayName: profile?['display_name'] as String?,
      photoUrl: profile?['date_avatar_url'] as String?,
      isHost: isHost,
    );
  }

  String get statusIcon => switch (attendanceStatus) {
    'going' => '\u2705',
    'maybe' => '\u2754',
    'on_my_way' => '\u231B',
    'arrived' => '\uD83D\uDCCD',
    _ => '',
  };
}
