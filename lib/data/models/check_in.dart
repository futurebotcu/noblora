class CheckIn {
  final String id;
  final String meetingId;
  final String userId;
  final String response; // 'great' | 'okay' | 'rather_not_say' | 'report'
  final DateTime createdAt;

  const CheckIn({
    required this.id,
    required this.meetingId,
    required this.userId,
    required this.response,
    required this.createdAt,
  });

  factory CheckIn.fromJson(Map<String, dynamic> json) {
    return CheckIn(
      id: json['id'] as String,
      meetingId: json['meeting_id'] as String,
      userId: json['user_id'] as String,
      response: json['response'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isGreat => response == 'great';
  bool get isOkay => response == 'okay';
  bool get isReport => response == 'report';
}
