class PhotoVerification {
  final String id;
  final String userId;
  final String photoUrl;
  final String photoType;     // 'profile' | 'selfie'
  final String status;        // 'pending' | 'approved' | 'rejected' | 'manual_review'
  final String? claimedGender; // 'male' | 'female' | 'other' — user's declaration at submission time
  final Map<String, dynamic>? geminiResponse;
  final String? rejectionReason;
  final double? realSelfieProbability;
  final String? genderDetected; // AI-detected gender
  final String? decision;
  final String? aiReason;
  final DateTime createdAt;

  const PhotoVerification({
    required this.id,
    required this.userId,
    required this.photoUrl,
    required this.photoType,
    required this.status,
    this.claimedGender,
    this.geminiResponse,
    this.rejectionReason,
    this.realSelfieProbability,
    this.genderDetected,
    this.decision,
    this.aiReason,
    required this.createdAt,
  });

  factory PhotoVerification.fromJson(Map<String, dynamic> json) {
    return PhotoVerification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      photoUrl: json['photo_url'] as String,
      photoType: json['photo_type'] as String,
      status: json['status'] as String,
      claimedGender: json['claimed_gender'] as String?,
      geminiResponse: json['gemini_response'] as Map<String, dynamic>?,
      rejectionReason: json['rejection_reason'] as String?,
      realSelfieProbability: (json['real_selfie_probability'] as num?)?.toDouble(),
      genderDetected: json['gender_detected'] as String?,
      decision: json['decision'] as String?,
      aiReason: json['ai_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isManualReview => status == 'manual_review';
}
