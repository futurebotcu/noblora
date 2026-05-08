class RoomMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final bool goldFlagged;
  final bool blueFlagged;
  final String? blueFlaggedBy;
  final DateTime createdAt;

  // Joined from profiles
  final String? senderName;
  final String? senderAvatarUrl;

  // Computed
  final bool isHost;

  RoomMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    this.goldFlagged = false,
    this.blueFlagged = false,
    this.blueFlaggedBy,
    required this.createdAt,
    this.senderName,
    this.senderAvatarUrl,
    this.isHost = false,
  });

  factory RoomMessage.fromJson(Map<String, dynamic> json, {String? hostId}) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return RoomMessage(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      goldFlagged: json['gold_flagged'] as bool? ?? false,
      blueFlagged: json['blue_flagged'] as bool? ?? false,
      blueFlaggedBy: json['blue_flagged_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      senderName: profile?['display_name'] as String?,
      senderAvatarUrl: profile?['date_avatar_url'] as String?,
      isHost: json['sender_id'] == hostId,
    );
  }
}
