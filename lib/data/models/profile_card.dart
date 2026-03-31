import '../../core/enums/noble_mode.dart';

class ProfileCard {
  final String id;
  final String name;
  final int age;
  final String city;
  final String? bio;
  final String photoUrl;
  final String? education;
  final String? profession;
  final List<String> interests;
  final List<String> languages;
  final bool isVerified;
  final NobleMode mode;

  // BFF networking fields
  final String? industry;       // e.g. 'Technology', 'Creative Arts'
  final String? expertise;      // e.g. 'AI Investments · Deep Tech'
  final String? connectionGoal; // e.g. 'Looking for a Tennis Partner'

  const ProfileCard({
    required this.id,
    required this.name,
    required this.age,
    required this.city,
    this.bio,
    required this.photoUrl,
    this.education,
    this.profession,
    this.interests = const [],
    this.languages = const [],
    this.isVerified = false,
    this.mode = NobleMode.date,
    this.industry,
    this.expertise,
    this.connectionGoal,
  });

  /// Maps a public.profiles DB row to a ProfileCard for the feed.
  /// Picks mode-specific bio and avatar; falls back to photos[] then picsum.
  factory ProfileCard.fromDb(Map<String, dynamic> row, NobleMode mode) {
    final bio = switch (mode) {
      NobleMode.date    => row['date_bio'],
      NobleMode.bff     => row['bff_bio'],
      NobleMode.social  => row['social_bio'],
      NobleMode.noblara => row['bio'],
    } as String? ??
        row['bio'] as String?;

    final avatar = switch (mode) {
      NobleMode.date    => row['date_avatar_url'],
      NobleMode.bff     => row['bff_avatar_url'],
      NobleMode.social  => row['social_avatar_url'],
      NobleMode.noblara => null,
    } as String?;

    final photos =
        (row['photos'] as List<dynamic>?)?.cast<String>() ?? [];
    final photoUrl = avatar ??
        (photos.isNotEmpty ? photos.first : null) ??
        'https://picsum.photos/seed/${row['id']}/600/800';

    return ProfileCard(
      id: (row['user_id'] ?? row['id']) as String,
      name: (row['display_name'] as String?)?.trim().isNotEmpty == true
          ? row['display_name'] as String
          : 'Unknown',
      age: (row['age'] as int?) ?? 18,
      city: (row['city'] as String?) ?? '',
      bio: bio,
      photoUrl: photoUrl,
      education: row['education'] as String?,
      profession: row['profession'] as String?,
      interests:
          (row['hobbies'] as List<dynamic>?)?.cast<String>() ?? [],
      languages:
          (row['languages'] as List<dynamic>?)?.cast<String>() ?? [],
      isVerified: (row['is_verified'] as bool?) ?? false,
      mode: mode,
    );
  }

  factory ProfileCard.fromJson(Map<String, dynamic> json) {
    return ProfileCard(
      id: json['id'] as String,
      name: json['name'] as String,
      age: json['age'] as int,
      city: json['city'] as String,
      bio: json['bio'] as String?,
      photoUrl: json['photo_url'] as String,
      education: json['education'] as String?,
      profession: json['profession'] as String?,
      interests: (json['interests'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      languages: (json['languages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isVerified: (json['is_verified'] as bool?) ?? false,
      industry: json['industry'] as String?,
      expertise: json['expertise'] as String?,
      connectionGoal: json['connection_goal'] as String?,
    );
  }

}
