class NobleMatch {
  final String id;
  final String user1Id;
  final String user2Id;
  final String mode;
  final String status;
  final DateTime matchedAt;
  final DateTime? videoDeadlineAt;
  final DateTime? chatExpiresAt;
  final String? conversationId;

  // Populated by join when fetching
  final String? otherUserName;
  final String? otherUserPhotoUrl;
  final String? otherUserId;

  const NobleMatch({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.mode,
    required this.status,
    required this.matchedAt,
    this.videoDeadlineAt,
    this.chatExpiresAt,
    this.conversationId,
    this.otherUserName,
    this.otherUserPhotoUrl,
    this.otherUserId,
  });

  factory NobleMatch.fromJson(Map<String, dynamic> json) {
    return NobleMatch(
      id: json['id'] as String,
      user1Id: json['user1_id'] as String,
      user2Id: json['user2_id'] as String,
      mode: json['mode'] as String? ?? 'date',
      status: json['status'] as String? ?? 'pending_video',
      matchedAt: DateTime.parse(json['matched_at'] as String),
      videoDeadlineAt: json['video_deadline_at'] != null
          ? DateTime.parse(json['video_deadline_at'] as String)
          : null,
      chatExpiresAt: json['chat_expires_at'] != null
          ? DateTime.parse(json['chat_expires_at'] as String)
          : null,
      conversationId: json['conversation_id'] as String?,
      otherUserName: json['other_user_name'] as String?,
      otherUserPhotoUrl: json['other_user_photo_url'] as String?,
      otherUserId: json['other_user_id'] as String?,
    );
  }

  NobleMatch withOtherUser({
    required String userId,
    required String name,
    String? photoUrl,
  }) {
    return NobleMatch(
      id: id,
      user1Id: user1Id,
      user2Id: user2Id,
      mode: mode,
      status: status,
      matchedAt: matchedAt,
      videoDeadlineAt: videoDeadlineAt,
      chatExpiresAt: chatExpiresAt,
      conversationId: conversationId,
      otherUserId: userId,
      otherUserName: name,
      otherUserPhotoUrl: photoUrl,
    );
  }

  bool get isPendingIntro => status == 'pending_intro';
  bool get isPendingVideo => status == 'pending_video';
  bool get isVideoScheduled => status == 'video_scheduled';
  bool get isVideoCompleted => status == 'video_completed';
  bool get isChatting => status == 'chatting';
  bool get isExpired => status == 'expired';
  bool get isClosed => status == 'closed';
  bool get hasMeeting => status == 'meeting_scheduled';

  Duration? get videoTimeRemaining {
    if (videoDeadlineAt == null) return null;
    final remaining = videoDeadlineAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration? get chatTimeRemaining {
    if (chatExpiresAt == null) return null;
    final remaining = chatExpiresAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
