// ---------------------------------------------------------------------------
// Profile model — maps against public.profiles
//
// Key columns (LIVE schema):
//   id           UUID  — PK = auth.users.id  ← ALL queries filter on this
//   full_name    TEXT  — shown name
//   current_mode TEXT  — 'date' | 'bff' | 'social'
//   noble_score  INTEGER (read-only, set by backend)
// ---------------------------------------------------------------------------

class Profile {
  final String id;           // profiles.id (PK = auth.users.id)
  final String userId;       // same as id — kept for compatibility
  final String displayName;  // full_name in DB
  final String? gender;      // 'male' | 'female' | 'other'
  final String? mode;        // current_mode in DB ('date' | 'bff' | 'social')
  final int nobleScore;      // noble_score
  final String? dateBio;
  final String? dateAvatarUrl;
  final String? bffBio;
  final String? bffAvatarUrl;
  final String? socialBio;
  final String? socialAvatarUrl;

  const Profile({
    required this.id,
    required this.userId,
    required this.displayName,
    this.gender,
    this.mode,
    this.nobleScore = 0,
    this.dateBio,
    this.dateAvatarUrl,
    this.bffBio,
    this.bffAvatarUrl,
    this.socialBio,
    this.socialAvatarUrl,
  });

  // Convenience alias used by existing UI code referencing .fullName
  String get fullName => displayName;
  // Convenience alias used by existing UI code referencing .currentMode
  String? get currentMode => mode;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      userId: json['id'] as String,
      displayName: (json['full_name'] as String?) ?? '',
      gender: json['gender'] as String?,
      mode: json['current_mode'] as String?,
      nobleScore: (json['noble_score'] as int?) ?? 0,
      dateBio: json['date_bio'] as String?,
      dateAvatarUrl: json['date_avatar_url'] as String?,
      bffBio: json['bff_bio'] as String?,
      bffAvatarUrl: json['bff_avatar_url'] as String?,
      socialBio: json['social_bio'] as String?,
      socialAvatarUrl: json['social_avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': displayName,
      'gender': gender,
      'current_mode': mode,
      'noble_score': nobleScore,
      'date_bio': dateBio,
      'date_avatar_url': dateAvatarUrl,
      'bff_bio': bffBio,
      'bff_avatar_url': bffAvatarUrl,
      'social_bio': socialBio,
      'social_avatar_url': socialAvatarUrl,
    };
  }

  Profile copyWith({
    String? displayName,
    String? gender,
    String? mode,
    int? nobleScore,
    String? dateBio,
    String? dateAvatarUrl,
    String? bffBio,
    String? bffAvatarUrl,
    String? socialBio,
    String? socialAvatarUrl,
  }) {
    return Profile(
      id: id,
      userId: userId,
      displayName: displayName ?? this.displayName,
      gender: gender ?? this.gender,
      mode: mode ?? this.mode,
      nobleScore: nobleScore ?? this.nobleScore,
      dateBio: dateBio ?? this.dateBio,
      dateAvatarUrl: dateAvatarUrl ?? this.dateAvatarUrl,
      bffBio: bffBio ?? this.bffBio,
      bffAvatarUrl: bffAvatarUrl ?? this.bffAvatarUrl,
      socialBio: socialBio ?? this.socialBio,
      socialAvatarUrl: socialAvatarUrl ?? this.socialAvatarUrl,
    );
  }
}
