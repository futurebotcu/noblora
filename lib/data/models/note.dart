class Note {
  final String id;
  final String senderId;
  final String receiverId;
  final String targetType; // 'profile' | 'post'
  final String targetId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  // Joined fields
  final String? senderName;
  final String? senderPhotoUrl;

  const Note({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.targetType,
    required this.targetId,
    required this.content,
    required this.isRead,
    required this.createdAt,
    this.senderName,
    this.senderPhotoUrl,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      targetType: json['target_type'] as String? ?? 'profile',
      targetId: json['target_id'] as String,
      content: json['content'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      senderName: json['sender_name'] as String?,
      senderPhotoUrl: json['sender_photo_url'] as String?,
    );
  }
}
