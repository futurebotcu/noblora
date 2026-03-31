class EventMessage {
  final String id;
  final String eventId;
  final String senderId;
  final String content;
  final bool goldFlagged;
  final bool blueFlagged;
  final String? blueFlaggedBy;
  final DateTime createdAt;
  final String? senderName;
  final String? senderPhotoUrl;
  final bool isHost;

  EventMessage({
    required this.id,
    required this.eventId,
    required this.senderId,
    required this.content,
    this.goldFlagged = false,
    this.blueFlagged = false,
    this.blueFlaggedBy,
    required this.createdAt,
    this.senderName,
    this.senderPhotoUrl,
    this.isHost = false,
  });

  factory EventMessage.fromJson(Map<String, dynamic> json, {String? hostId}) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return EventMessage(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      goldFlagged: json['gold_flagged'] as bool? ?? false,
      blueFlagged: json['blue_flagged'] as bool? ?? false,
      blueFlaggedBy: json['blue_flagged_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      senderName: profile?['display_name'] as String?,
      senderPhotoUrl: profile?['date_avatar_url'] as String?,
      isHost: json['sender_id'] == hostId,
    );
  }
}
