class EventCheckin {
  final String id;
  final String eventId;
  final String userId;
  final bool? eventWasReal;
  final bool? hostRating;
  final bool? noshowReported;
  final DateTime createdAt;

  EventCheckin({
    required this.id,
    required this.eventId,
    required this.userId,
    this.eventWasReal,
    this.hostRating,
    this.noshowReported,
    required this.createdAt,
  });

  factory EventCheckin.fromJson(Map<String, dynamic> json) {
    return EventCheckin(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      eventWasReal: json['event_was_real'] as bool?,
      hostRating: json['host_rating'] as bool?,
      noshowReported: json['noshow_reported'] as bool?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
