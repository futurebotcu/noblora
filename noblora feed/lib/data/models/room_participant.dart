class RoomParticipant {
  final String id;
  final String roomId;
  final String userId;
  final DateTime joinedAt;

  // Joined from profiles
  final String? displayName;
  final String? avatarUrl;

  RoomParticipant({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.joinedAt,
    this.displayName,
    this.avatarUrl,
  });

  factory RoomParticipant.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return RoomParticipant(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      userId: json['user_id'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      displayName: profile?['display_name'] as String?,
      avatarUrl: profile?['date_avatar_url'] as String?,
    );
  }
}
