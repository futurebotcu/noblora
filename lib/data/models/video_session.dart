class VideoSession {
  final String id;
  final String matchId;
  final DateTime scheduledAt;
  final String status;
  final String? proposedBy;
  final String? confirmedBy;
  final String? roomUrl;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final DateTime createdAt;
  // Scheduling rebuild fields
  final DateTime proposedAt;
  final DateTime? expiresAt;
  final DateTime? mustCompleteBy;
  final String? declineReason;
  final DateTime? counterProposedAt;

  final int callDurationMinutes;

  const VideoSession({
    required this.id,
    required this.matchId,
    required this.scheduledAt,
    required this.status,
    this.proposedBy,
    this.confirmedBy,
    this.roomUrl,
    this.startedAt,
    this.endedAt,
    this.durationSeconds,
    required this.createdAt,
    required this.proposedAt,
    this.expiresAt,
    this.mustCompleteBy,
    this.declineReason,
    this.counterProposedAt,
    this.callDurationMinutes = 4,
  });

  factory VideoSession.fromJson(Map<String, dynamic> json) {
    final proposedAtRaw = json['proposed_at'] as String?;
    final createdAtRaw = json['created_at'] as String;
    final proposedAt = proposedAtRaw != null
        ? DateTime.parse(proposedAtRaw)
        : DateTime.parse(createdAtRaw);
    return VideoSession(
      id: json['id'] as String,
      matchId: json['match_id'] as String,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      status: json['status'] as String? ?? 'pending',
      proposedBy: json['proposed_by'] as String?,
      confirmedBy: json['confirmed_by'] as String?,
      roomUrl: json['room_url'] as String?,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      durationSeconds: json['duration_seconds'] as int?,
      createdAt: DateTime.parse(createdAtRaw),
      proposedAt: proposedAt,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      mustCompleteBy: json['must_complete_by'] != null
          ? DateTime.parse(json['must_complete_by'] as String)
          : null,
      declineReason: json['decline_reason'] as String?,
      counterProposedAt: json['counter_proposed_at'] != null
          ? DateTime.parse(json['counter_proposed_at'] as String)
          : null,
      callDurationMinutes: json['call_duration_minutes'] as int? ?? 4,
    );
  }

  // Status helpers
  bool get isPending => status == 'pending';
  bool get isCounterProposed => status == 'counter_proposed';
  bool get isAccepted => status == 'accepted';
  bool get isCompleted => status == 'completed';
  bool get isExpired => status == 'expired';
  bool get isCancelled => status == 'cancelled';

  // Legacy aliases used in other screens
  bool get isProposed => isPending;
  bool get isConfirmed => isAccepted;
  bool get isActive => status == 'active';

  /// Remaining time until this proposal expires (12h window).
  Duration get timeUntilExpiry {
    final deadline = expiresAt ?? proposedAt.add(const Duration(hours: 12));
    final diff = deadline.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get isStartingSoon {
    final diff = scheduledAt.difference(DateTime.now());
    return diff.inMinutes <= 5 && !diff.isNegative;
  }
}
