class Signal {
  final String id;
  final String senderId;
  final String receiverId;
  final DateTime createdAt;

  // Joined fields
  final String? senderName;
  final String? senderPhotoUrl;

  const Signal({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.createdAt,
    this.senderName,
    this.senderPhotoUrl,
  });

  factory Signal.fromJson(Map<String, dynamic> json) {
    return Signal(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      senderName: json['sender_name'] as String?,
      senderPhotoUrl: json['sender_photo_url'] as String?,
    );
  }
}
