class ChatMessage {
  final String id;
  final String conversationId;
  final String? senderId;
  final String senderDisplayName;
  final String content;
  final String mode; // 'date' | 'bff' | 'social'
  final bool isSystem;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String? mediaUrl;
  final String? mediaType; // 'image' | 'voice'

  const ChatMessage({
    required this.id,
    required this.conversationId,
    this.senderId,
    required this.senderDisplayName,
    required this.content,
    required this.mode,
    this.isSystem = false,
    required this.createdAt,
    this.deliveredAt,
    this.readAt,
    this.mediaUrl,
    this.mediaType,
  });

  bool get isDelivered => deliveredAt != null;
  bool get isRead => readAt != null;
  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;
  bool get isImage => mediaType == 'image';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String?,
      senderDisplayName: json['sender_display_name'] as String? ?? '?',
      content: json['content'] as String? ?? '',
      mode: json['mode'] as String? ?? 'date',
      isSystem: json['is_system'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      deliveredAt: json['delivered_at'] != null
          ? DateTime.tryParse(json['delivered_at'] as String)
          : null,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'conversation_id': conversationId,
      if (senderId != null) 'sender_id': senderId,
      'sender_display_name': senderDisplayName,
      'content': content,
      'mode': mode,
      'is_system': isSystem,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (mediaType != null) 'media_type': mediaType,
    };
  }
}
