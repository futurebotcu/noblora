class ChatMessage {
  final String id;
  final String conversationId;
  final String? senderId;
  final String senderDisplayName;
  final String content;
  final String mode; // 'date' | 'bff' | 'social'
  final bool isSystem;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    this.senderId,
    required this.senderDisplayName,
    required this.content,
    required this.mode,
    this.isSystem = false,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String?,
      senderDisplayName: json['sender_display_name'] as String? ?? '?',
      content: json['content'] as String,
      mode: json['mode'] as String? ?? 'date',
      isSystem: json['is_system'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
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
    };
  }
}
