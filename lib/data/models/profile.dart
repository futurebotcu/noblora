import 'post.dart'; // NobTier enum

// ---------------------------------------------------------------------------
// Profile model — maps against public.profiles
// ---------------------------------------------------------------------------

class Profile {
  final String id;
  final String userId;
  final String displayName;
  final String? gender;
  final String? mode;
  final int nobleScore;
  final int trustScore;
  final NobTier nobTier;
  final double maturityScore;
  final double vitalityScore;
  final int profileCompletenessScore;
  final int communityScore;
  final int depthScore;
  final int followThroughScore;
  final DateTime? lastActiveAt;
  final String? dateBio;
  final String? dateAvatarUrl;
  final String? bffBio;
  final String? bffAvatarUrl;
  final String? socialBio;
  final String? socialAvatarUrl;
  final String? bio;

  const Profile({
    required this.id,
    required this.userId,
    required this.displayName,
    this.gender,
    this.mode,
    this.nobleScore = 0,
    this.trustScore = 50,
    this.nobTier = NobTier.observer,
    this.maturityScore = 0,
    this.vitalityScore = 100,
    this.profileCompletenessScore = 0,
    this.communityScore = 0,
    this.depthScore = 0,
    this.followThroughScore = 50,
    this.lastActiveAt,
    this.dateBio,
    this.dateAvatarUrl,
    this.bffBio,
    this.bffAvatarUrl,
    this.socialBio,
    this.socialAvatarUrl,
    this.bio,
  });

  String get fullName => displayName;
  String? get currentMode => mode;

  String get strengthLabel {
    final score = maturityScore.round();
    if (score >= 80) return 'Complete';
    if (score >= 60) return 'Strong';
    if (score >= 40) return 'Good';
    if (score >= 20) return 'Building up';
    return 'Just getting started';
  }

  List<String> get profileTips {
    final tips = <String>[];
    if (profileCompletenessScore < 60) {
      if (dateAvatarUrl == null && bffAvatarUrl == null) tips.add('Add a profile photo to make a first impression.');
      if (bio == null || (bio?.length ?? 0) < 10) tips.add('Write a short bio to let others know who you are.');
    }
    if (!_hasVerification) tips.add('Verifying your photo adds a layer of trust.');
    if (communityScore < 20) tips.add('Add a pinned Nob to let others see your world.');
    if (followThroughScore < 40) tips.add('Plans you honor shape your reputation here.');
    return tips;
  }

  bool get _hasVerification => trustScore > 60;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      userId: json['id'] as String,
      displayName: (json['display_name'] as String?) ?? (json['full_name'] as String?) ?? '',
      gender: json['gender'] as String?,
      mode: json['current_mode'] as String? ?? json['mode'] as String?,
      nobleScore: (json['noble_score'] as int?) ?? 0,
      trustScore: (json['trust_score'] as int?) ?? 50,
      nobTier: NobTier.fromString(json['nob_tier'] as String?),
      maturityScore: (json['maturity_score'] as num?)?.toDouble() ?? 0,
      vitalityScore: (json['vitality_score'] as num?)?.toDouble() ?? 100,
      profileCompletenessScore: (json['profile_completeness_score'] as int?) ?? 0,
      communityScore: (json['community_score'] as int?) ?? 0,
      depthScore: (json['depth_score'] as int?) ?? 0,
      followThroughScore: (json['follow_through_score'] as int?) ?? 50,
      lastActiveAt: json['last_active_at'] != null ? DateTime.tryParse(json['last_active_at'] as String) : null,
      dateBio: json['date_bio'] as String?,
      dateAvatarUrl: json['date_avatar_url'] as String?,
      bffBio: json['bff_bio'] as String?,
      bffAvatarUrl: json['bff_avatar_url'] as String?,
      socialBio: json['social_bio'] as String?,
      socialAvatarUrl: json['social_avatar_url'] as String?,
      bio: json['bio'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': displayName,
      'gender': gender,
      'current_mode': mode,
      'noble_score': nobleScore,
    };
  }

  Profile copyWith({
    String? displayName,
    String? gender,
    String? mode,
    int? nobleScore,
    int? trustScore,
    NobTier? nobTier,
    double? maturityScore,
    double? vitalityScore,
    int? profileCompletenessScore,
    int? communityScore,
    int? depthScore,
    int? followThroughScore,
    String? dateBio,
    String? dateAvatarUrl,
    String? bffBio,
    String? bffAvatarUrl,
    String? socialBio,
    String? socialAvatarUrl,
    String? bio,
  }) {
    return Profile(
      id: id,
      userId: userId,
      displayName: displayName ?? this.displayName,
      gender: gender ?? this.gender,
      mode: mode ?? this.mode,
      nobleScore: nobleScore ?? this.nobleScore,
      trustScore: trustScore ?? this.trustScore,
      nobTier: nobTier ?? this.nobTier,
      maturityScore: maturityScore ?? this.maturityScore,
      vitalityScore: vitalityScore ?? this.vitalityScore,
      profileCompletenessScore: profileCompletenessScore ?? this.profileCompletenessScore,
      communityScore: communityScore ?? this.communityScore,
      depthScore: depthScore ?? this.depthScore,
      followThroughScore: followThroughScore ?? this.followThroughScore,
      dateBio: dateBio ?? this.dateBio,
      dateAvatarUrl: dateAvatarUrl ?? this.dateAvatarUrl,
      bffBio: bffBio ?? this.bffBio,
      bffAvatarUrl: bffAvatarUrl ?? this.bffAvatarUrl,
      socialBio: socialBio ?? this.socialBio,
      socialAvatarUrl: socialAvatarUrl ?? this.socialAvatarUrl,
      bio: bio ?? this.bio,
    );
  }
}
