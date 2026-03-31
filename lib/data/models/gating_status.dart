class GatingStatus {
  final bool isVerified;
  final bool isEntryApproved;
  final String? verificationMessage;
  final String? entryMessage;

  const GatingStatus({
    required this.isVerified,
    required this.isEntryApproved,
    this.verificationMessage,
    this.entryMessage,
  });

  factory GatingStatus.fromJson(Map<String, dynamic> json) {
    return GatingStatus(
      isVerified: (json['is_verified'] as bool?) ?? false,
      isEntryApproved: (json['is_entry_approved'] as bool?) ?? false,
      verificationMessage: json['verification_message'] as String?,
      entryMessage: json['entry_message'] as String?,
    );
  }

  // Mock: all gates open
  factory GatingStatus.mockOpen() {
    return const GatingStatus(
      isVerified: true,
      isEntryApproved: true,
    );
  }
}
