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
  final int? age;
  final String? city;
  final String? occupation;
  final int? height;
  final String? philosophy;
  final String? drinks;
  final String? smokes;
  final String? faithSensitivity;
  final List<String> languages;
  final String? fromCountry;
  final List<String> countriesVisited;
  final List<String> interests;
  final String? vibe;
  final String? lookingFor;
  final String? zodiac;
  final List<String> photoUrls;

  // Rich profile data (from profile_data JSONB)
  final String? longBio;
  final String? tagline;
  final String? currentFocus;
  final String? pronouns;
  final String? wantsChildren;
  final List<String> relationshipType;
  final List<String> datingStyle;
  final List<String> communicationStyle;
  final List<String> loveLanguages;
  final List<String> musicGenres;
  final List<String> movieGenres;
  final List<String> weekendStyle;
  final List<String> humorStyle;
  final String? sleepStyle;
  final String? dietStyle;
  final String? fitnessRoutine;
  final String? workStyle;
  final String? entrepreneurshipStatus;
  final List<String> buildingNow;
  final List<String> industry;
  final List<String> aiTools;
  final String? socialMediaUsage;
  final String? techRelation;
  final List<String> travelStyle;
  final List<String> livedCountries;
  final List<String> wishlistCountries;
  final List<PromptAnswer> prompts;
  final Map<String, String> visibility;

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
    this.age,
    this.city,
    this.occupation,
    this.height,
    this.philosophy,
    this.drinks,
    this.smokes,
    this.faithSensitivity,
    this.languages = const [],
    this.fromCountry,
    this.countriesVisited = const [],
    this.interests = const [],
    this.vibe,
    this.lookingFor,
    this.zodiac,
    this.photoUrls = const [],
    this.longBio,
    this.tagline,
    this.currentFocus,
    this.pronouns,
    this.wantsChildren,
    this.relationshipType = const [],
    this.datingStyle = const [],
    this.communicationStyle = const [],
    this.loveLanguages = const [],
    this.musicGenres = const [],
    this.movieGenres = const [],
    this.weekendStyle = const [],
    this.humorStyle = const [],
    this.sleepStyle,
    this.dietStyle,
    this.fitnessRoutine,
    this.workStyle,
    this.entrepreneurshipStatus,
    this.buildingNow = const [],
    this.industry = const [],
    this.aiTools = const [],
    this.socialMediaUsage,
    this.techRelation,
    this.travelStyle = const [],
    this.livedCountries = const [],
    this.wishlistCountries = const [],
    this.prompts = const [],
    this.visibility = const {},
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
    final pd = (json['profile_data'] as Map<String, dynamic>?) ?? const {};
    List<String> strList(dynamic v) =>
        (v is List) ? v.whereType<String>().toList() : const [];

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
      age: json['age'] as int?,
      city: json['city'] as String?,
      occupation: json['occupation'] as String?,
      height: json['height'] as int?,
      philosophy: json['philosophy'] as String?,
      drinks: json['drinks'] as String?,
      smokes: json['smokes'] as String?,
      faithSensitivity: json['faith_sensitivity'] as String?,
      languages: (json['languages'] as List<dynamic>?)?.cast<String>() ?? const [],
      fromCountry: json['from_country'] as String?,
      countriesVisited: (json['countries_visited'] as List<dynamic>?)?.cast<String>() ?? const [],
      interests: (json['interests'] as List<dynamic>?)?.cast<String>() ??
          (json['hobbies'] as List<dynamic>?)?.cast<String>() ?? const [],
      vibe: json['vibe'] as String?,
      lookingFor: json['looking_for'] as String?,
      zodiac: json['zodiac'] as String?,
      photoUrls: (json['photo_urls'] as List<dynamic>?)?.cast<String>() ??
          (json['photos'] as List<dynamic>?)?.cast<String>() ?? const [],
      // Rich profile_data fields
      longBio: pd['long_bio'] as String?,
      tagline: pd['tagline'] as String?,
      currentFocus: pd['current_focus'] as String?,
      pronouns: pd['pronouns'] as String?,
      wantsChildren: pd['wants_children'] as String?,
      relationshipType: strList(pd['relationship_type']),
      datingStyle: strList(pd['dating_style']),
      communicationStyle: strList(pd['communication_style']),
      loveLanguages: strList(pd['love_languages']),
      musicGenres: strList(pd['music_genres']),
      movieGenres: strList(pd['movie_genres']),
      weekendStyle: strList(pd['weekend_style']),
      humorStyle: strList(pd['humor_style']),
      sleepStyle: pd['sleep_style'] as String?,
      dietStyle: pd['diet_style'] as String?,
      fitnessRoutine: pd['fitness_routine'] as String?,
      workStyle: pd['work_style'] as String?,
      entrepreneurshipStatus: pd['entrepreneurship_status'] as String?,
      buildingNow: strList(pd['building_now']),
      industry: strList(pd['industry']),
      aiTools: strList(pd['ai_tools']),
      socialMediaUsage: pd['social_media_usage'] as String?,
      techRelation: pd['tech_relation'] as String?,
      travelStyle: strList(pd['travel_style']),
      livedCountries: strList(pd['lived_countries']),
      wishlistCountries: strList(pd['wishlist_countries']),
      prompts: (pd['prompts'] as List?)
              ?.map((e) => PromptAnswer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      visibility: (pd['visibility'] as Map<String, dynamic>?)?.cast<String, String>() ?? const {},
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
    int? age,
    String? city,
    String? occupation,
    int? height,
    String? philosophy,
    String? drinks,
    String? smokes,
    String? faithSensitivity,
    List<String>? languages,
    String? fromCountry,
    List<String>? countriesVisited,
    List<String>? interests,
    String? vibe,
    String? lookingFor,
    String? zodiac,
    List<String>? photoUrls,
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
      age: age ?? this.age,
      city: city ?? this.city,
      occupation: occupation ?? this.occupation,
      height: height ?? this.height,
      philosophy: philosophy ?? this.philosophy,
      drinks: drinks ?? this.drinks,
      smokes: smokes ?? this.smokes,
      faithSensitivity: faithSensitivity ?? this.faithSensitivity,
      languages: languages ?? this.languages,
      fromCountry: fromCountry ?? this.fromCountry,
      countriesVisited: countriesVisited ?? this.countriesVisited,
      interests: interests ?? this.interests,
      vibe: vibe ?? this.vibe,
      lookingFor: lookingFor ?? this.lookingFor,
      zodiac: zodiac ?? this.zodiac,
      photoUrls: photoUrls ?? this.photoUrls,
    );
  }

  /// Returns true if a field should be visible to a viewer based on the
  /// profile owner's visibility preferences.
  ///
  /// [isMatch] should be true when the viewer has an active match/connection
  /// with this profile owner (dating or BFF). When null, match status is
  /// unknown and we fall back to the safe default (hide matches-only fields).
  bool canViewField(String fieldKey, {bool? isMatch}) {
    final v = visibility[fieldKey];
    if (v == null || v == 'Public') return true;
    if (v == 'Private') return false;
    // 'Matches only' — visible only if viewer is a confirmed match
    return isMatch == true;
  }

  /// Convenience for contexts where match status is not available.
  /// Treats 'Matches only' as hidden (safe default for strangers).
  bool isFieldPublic(String fieldKey) => canViewField(fieldKey);
}

// ---------------------------------------------------------------------------
// Prompt answer (conversation starter)
// ---------------------------------------------------------------------------

class PromptAnswer {
  final String question;
  final String answer;

  const PromptAnswer({required this.question, required this.answer});

  factory PromptAnswer.fromJson(Map<String, dynamic> json) => PromptAnswer(
        question: json['question'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
      );

  bool get hasAnswer => answer.trim().isNotEmpty;
}
