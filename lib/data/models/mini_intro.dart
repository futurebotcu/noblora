class MiniIntro {
  final String id;
  final String matchId;
  final String senderId;
  final String message;
  final DateTime createdAt;

  const MiniIntro({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.message,
    required this.createdAt,
  });

  factory MiniIntro.fromJson(Map<String, dynamic> json) {
    return MiniIntro(
      id: json['id'] as String,
      matchId: json['match_id'] as String,
      senderId: json['sender_id'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'match_id': matchId,
        'sender_id': senderId,
        'message': message,
      };
}
