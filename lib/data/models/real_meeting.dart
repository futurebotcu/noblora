class RealMeeting {
  final String id;
  final String matchId;
  final String proposedBy;
  final DateTime scheduledAt;
  final String? locationText;
  final String status; // proposed | confirmed | completed | cancelled
  final DateTime createdAt;

  const RealMeeting({
    required this.id,
    required this.matchId,
    required this.proposedBy,
    required this.scheduledAt,
    this.locationText,
    required this.status,
    required this.createdAt,
  });

  factory RealMeeting.fromJson(Map<String, dynamic> json) {
    return RealMeeting(
      id: json['id'] as String,
      matchId: json['match_id'] as String,
      proposedBy: json['proposed_by'] as String? ?? '',
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      locationText: json['location_text'] as String?,
      status: json['status'] as String? ?? 'proposed',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isProposed => status == 'proposed';
  bool get isConfirmed => status == 'confirmed';
}
