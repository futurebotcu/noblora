// ---------------------------------------------------------------------------
// ProfileDraft — edit-time model that maps to profiles table + profile_data JSONB
// ---------------------------------------------------------------------------

class PromptAnswer {
  final String question;
  final String answer;
  const PromptAnswer({required this.question, this.answer = ''});

  Map<String, dynamic> toJson() => {'question': question, 'answer': answer};

  factory PromptAnswer.fromJson(Map<String, dynamic> j) => PromptAnswer(
    question: j['question'] as String? ?? '',
    answer: j['answer'] as String? ?? '',
  );
}

class LanguageEntry {
  final String code;
  final String label;
  final String level;
  const LanguageEntry({required this.code, required this.label, this.level = 'Intermediate'});

  Map<String, dynamic> toJson() => {'code': code, 'label': label, 'level': level};

  factory LanguageEntry.fromJson(Map<String, dynamic> j) => LanguageEntry(
    code: j['code'] as String? ?? '',
    label: j['label'] as String? ?? '',
    level: j['level'] as String? ?? 'Intermediate',
  );
}

class ProfileDraft {
  // ── Photos & Media ──
  List<String> photoUrls;
  String? videoIntroUrl;
  String? voiceIntroUrl;

  // ── Basic Info ──
  String displayName;
  String? birthDate;
  int? age;
  int? height;
  String? city;
  String? country;
  String? hometown;
  List<LanguageEntry> languages;
  String? zodiac;
  String? educationLevel;

  // ── About ──
  String? shortBio;
  String? longBio;
  String? tagline;
  String? currentFocus;

  // ── Identity & Life ──
  String? gender;
  List<String> interestedIn;
  String? pronouns;
  String? religiousApproach;
  String? wantsChildren;
  String? petsStatus;
  List<String> petsPreference;
  String? smoking;
  String? alcohol;
  String? nightlife;
  String? socialEnergy;
  String? personalityStyle;
  String? organizationStyle;

  // ── Relationship ──
  List<String> lookingFor;
  List<String> relationshipType;
  List<String> datingStyle;
  List<String> communicationStyle;
  List<String> firstMeetPreference;
  List<String> loveLanguages;
  List<String> greenFlags;
  List<String> redFlags;

  // ── Interests ──
  List<String> interests;
  List<String> favoritesRanked;

  // ── Culture & Social ──
  List<String> musicGenres;
  List<String> movieGenres;
  List<String> weekendStyle;
  List<String> humorStyle;

  // ── Travel ──
  List<String> visitedCountries;
  List<String> livedCountries;
  List<String> wishlistCountries;
  List<String> favoriteCities;
  List<String> travelStyle;
  String? relocationOpenness;

  // ── Career ──
  String? primaryRole;
  String? secondaryRole;
  List<String> industry;
  String? workStyle;
  String? entrepreneurshipStatus;
  List<String> buildingNow;
  List<String> sideProjects;
  String? workIntensity;

  // ── Digital Life ──
  List<String> aiTools;
  String? socialMediaUsage;
  List<String> onlineStyle;
  String? techRelation;
  bool contentCreator;

  // ── Lifestyle ──
  String? sleepStyle;
  String? dietStyle;
  String? fitnessRoutine;
  String? planningStyle;
  String? spendingStyle;
  List<String> fashionStyle;
  String? homeVsOutside;
  String? cityVsNature;

  // ── Prompts ──
  List<PromptAnswer> prompts;

  // ── Visibility ──
  Map<String, String> visibility;

  ProfileDraft({
    this.photoUrls = const [],
    this.videoIntroUrl,
    this.voiceIntroUrl,
    this.displayName = '',
    this.birthDate,
    this.age,
    this.height,
    this.city,
    this.country,
    this.hometown,
    this.languages = const [],
    this.zodiac,
    this.educationLevel,
    this.shortBio,
    this.longBio,
    this.tagline,
    this.currentFocus,
    this.gender,
    this.interestedIn = const [],
    this.pronouns,
    this.religiousApproach,
    this.wantsChildren,
    this.petsStatus,
    this.petsPreference = const [],
    this.smoking,
    this.alcohol,
    this.nightlife,
    this.socialEnergy,
    this.personalityStyle,
    this.organizationStyle,
    this.lookingFor = const [],
    this.relationshipType = const [],
    this.datingStyle = const [],
    this.communicationStyle = const [],
    this.firstMeetPreference = const [],
    this.loveLanguages = const [],
    this.greenFlags = const [],
    this.redFlags = const [],
    this.interests = const [],
    this.favoritesRanked = const [],
    this.musicGenres = const [],
    this.movieGenres = const [],
    this.weekendStyle = const [],
    this.humorStyle = const [],
    this.visitedCountries = const [],
    this.livedCountries = const [],
    this.wishlistCountries = const [],
    this.favoriteCities = const [],
    this.travelStyle = const [],
    this.relocationOpenness,
    this.primaryRole,
    this.secondaryRole,
    this.industry = const [],
    this.workStyle,
    this.entrepreneurshipStatus,
    this.buildingNow = const [],
    this.sideProjects = const [],
    this.workIntensity,
    this.aiTools = const [],
    this.socialMediaUsage,
    this.onlineStyle = const [],
    this.techRelation,
    this.contentCreator = false,
    this.sleepStyle,
    this.dietStyle,
    this.fitnessRoutine,
    this.planningStyle,
    this.spendingStyle,
    this.fashionStyle = const [],
    this.homeVsOutside,
    this.cityVsNature,
    this.prompts = const [],
    this.visibility = const {},
  });

  // ── Completion scoring ──
  int get completionScore {
    int score = 0;
    if (photoUrls.isNotEmpty) score += 20;
    if (shortBio != null && shortBio!.length > 10) score += 10;
    if (lookingFor.isNotEmpty) score += 12;
    if (interests.isNotEmpty) score += 12;
    if (lifestyleCount > 0) score += 10;
    if (primaryRole != null) score += 8;
    if (visitedCountries.isNotEmpty || travelStyle.isNotEmpty) score += 6;
    if (musicGenres.isNotEmpty || movieGenres.isNotEmpty) score += 6;
    if (aiTools.isNotEmpty || socialMediaUsage != null) score += 6;
    if (prompts.where((p) => p.answer.isNotEmpty).isNotEmpty) score += 10;
    return score.clamp(0, 100);
  }

  int get lifestyleCount {
    int c = 0;
    if (sleepStyle != null) c++;
    if (dietStyle != null) c++;
    if (fitnessRoutine != null) c++;
    if (planningStyle != null) c++;
    if (spendingStyle != null) c++;
    return c;
  }

  // ── Section completion helpers ──
  String photosStatus() => '${photoUrls.length}/6 photos';
  int basicInfoCount() {
    int c = 0;
    if (displayName.isNotEmpty) c++;
    if (age != null) c++;
    if (height != null) c++;
    if (city != null && city!.isNotEmpty) c++;
    if (hometown != null && hometown!.isNotEmpty) c++;
    if (country != null && country!.isNotEmpty) c++;
    if (languages.isNotEmpty) c++;
    if (zodiac != null) c++;
    if (educationLevel != null) c++;
    return c;
  }
  String basicInfoStatus() => '${basicInfoCount()}/9 completed';
  int aboutCount() {
    int c = 0;
    if (shortBio != null && shortBio!.isNotEmpty) c++;
    if (longBio != null && longBio!.isNotEmpty) c++;
    if (tagline != null && tagline!.isNotEmpty) c++;
    if (currentFocus != null && currentFocus!.isNotEmpty) c++;
    return c;
  }
  String aboutStatus() => '${aboutCount()}/4 completed';
  int identityCount() {
    int c = 0;
    if (gender != null) c++;
    if (interestedIn.isNotEmpty) c++;
    if (religiousApproach != null) c++;
    if (wantsChildren != null) c++;
    if (smoking != null) c++;
    if (alcohol != null) c++;
    if (socialEnergy != null) c++;
    if (personalityStyle != null) c++;
    return c;
  }
  String identityStatus() => '${identityCount()}/8 completed';
  int relationshipCount() {
    int c = 0;
    if (lookingFor.isNotEmpty) c++;
    if (relationshipType.isNotEmpty) c++;
    if (datingStyle.isNotEmpty) c++;
    if (communicationStyle.isNotEmpty) c++;
    if (firstMeetPreference.isNotEmpty) c++;
    if (loveLanguages.isNotEmpty) c++;
    return c;
  }
  String relationshipStatus() => '${relationshipCount()}/6 completed';
  String interestsStatus() => '${interests.length} selected';
  String cultureStatus() => '${musicGenres.length + movieGenres.length} selected';
  String travelStatus() => '${visitedCountries.length} countries';
  int careerCount() {
    int c = 0;
    if (primaryRole != null && primaryRole!.isNotEmpty) c++;
    if (workStyle != null) c++;
    if (entrepreneurshipStatus != null) c++;
    if (buildingNow.isNotEmpty) c++;
    return c;
  }
  String careerStatus() => '${careerCount()}/4 completed';
  String digitalStatus() => '${aiTools.length} tools';
  String lifestyleStatus() => '$lifestyleCount/5 completed';
  String promptsStatus() => '${prompts.where((p) => p.answer.isNotEmpty).length}/3 answered';

  // ── Preview strings for cards (real data) ──
  String? interestsPreview() => interests.isEmpty ? null : _joinPreview(interests, 5);
  String? relationshipPreview() {
    final parts = <String>[...lookingFor.take(2), ...relationshipType.take(1), ...datingStyle.take(1)];
    return parts.isEmpty ? null : parts.join(' · ');
  }
  String? identityPreview() {
    final parts = <String>[];
    if (gender != null) parts.add(gender!);
    if (socialEnergy != null) parts.add(socialEnergy!);
    if (personalityStyle != null) parts.add(personalityStyle!);
    return parts.isEmpty ? null : parts.join(' · ');
  }
  String? lifestylePreview() {
    final parts = <String>[];
    if (sleepStyle != null) parts.add(sleepStyle!);
    if (fitnessRoutine != null) parts.add('Fitness: $fitnessRoutine');
    if (dietStyle != null) parts.add(dietStyle!);
    return parts.isEmpty ? null : parts.join(' · ');
  }
  String? culturePreview() {
    final parts = <String>[...musicGenres.take(3), ...movieGenres.take(2)];
    return parts.isEmpty ? null : parts.join(' · ');
  }
  String? travelPreview() {
    if (visitedCountries.isEmpty) return null;
    return _joinPreview(visitedCountries, 4);
  }
  String? careerPreview() {
    final parts = <String>[];
    if (primaryRole != null && primaryRole!.isNotEmpty) parts.add(primaryRole!);
    if (workStyle != null) parts.add(workStyle!);
    if (entrepreneurshipStatus != null) parts.add(entrepreneurshipStatus!);
    return parts.isEmpty ? null : parts.join(' · ');
  }
  String? digitalPreview() {
    if (aiTools.isEmpty) return null;
    return _joinPreview(aiTools, 4);
  }
  String? basicInfoPreview() {
    final parts = <String>[];
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (age != null) parts.add('${age}y');
    if (zodiac != null) parts.add(zodiac!);
    if (languages.isNotEmpty) parts.add(languages.map((l) => l.label).take(2).join(', '));
    return parts.isEmpty ? null : parts.join(' · ');
  }
  String? aboutPreview() {
    if (shortBio != null && shortBio!.isNotEmpty) {
      return shortBio!.length > 60 ? '${shortBio!.substring(0, 60)}...' : shortBio!;
    }
    return tagline;
  }
  String? promptsPreview() {
    final answered = prompts.where((p) => p.answer.isNotEmpty);
    if (answered.isEmpty) return null;
    final first = answered.first;
    final ans = first.answer.length > 50 ? '${first.answer.substring(0, 50)}...' : first.answer;
    return '"$ans"';
  }

  String _joinPreview(List<String> items, int max) {
    final shown = items.take(max).join(', ');
    final extra = items.length - max;
    return extra > 0 ? '$shown +$extra' : shown;
  }

  double sectionProgress(int filled, int total) => total > 0 ? (filled / total).clamp(0.0, 1.0) : 0.0;

  // ── Serialization ──
  factory ProfileDraft.fromDbRow(Map<String, dynamic> row) {
    final pd = row['profile_data'] as Map<String, dynamic>? ?? {};
    List<String> strList(dynamic v) => (v as List<dynamic>?)?.cast<String>() ?? [];

    return ProfileDraft(
      photoUrls: strList(row['photo_urls']),
      videoIntroUrl: pd['video_intro_url'] as String?,
      voiceIntroUrl: pd['voice_intro_url'] as String?,
      displayName: (row['display_name'] as String?) ?? '',
      birthDate: pd['birth_date'] as String?,
      age: row['age'] as int?,
      height: row['height'] as int?,
      city: row['city'] as String?,
      country: pd['country'] as String?,
      hometown: row['from_country'] as String?,
      languages: (pd['languages'] as List?)?.map((e) => LanguageEntry.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      zodiac: row['zodiac'] as String?,
      educationLevel: pd['education_level'] as String?,
      shortBio: row['bio'] as String?,
      longBio: pd['long_bio'] as String?,
      tagline: pd['tagline'] as String?,
      currentFocus: pd['current_focus'] as String?,
      gender: row['gender'] as String?,
      interestedIn: strList(pd['interested_in']),
      pronouns: pd['pronouns'] as String?,
      religiousApproach: row['faith_sensitivity'] as String?,
      wantsChildren: pd['wants_children'] as String?,
      petsStatus: pd['pets_status'] as String?,
      petsPreference: strList(pd['pets_preference']),
      smoking: row['smokes'] as String?,
      alcohol: row['drinks'] as String?,
      nightlife: pd['nightlife'] as String?,
      socialEnergy: pd['social_energy'] as String?,
      personalityStyle: pd['personality_style'] as String?,
      organizationStyle: pd['organization_style'] as String?,
      lookingFor: row['looking_for'] != null ? [row['looking_for'] as String] : strList(pd['looking_for']),
      relationshipType: strList(pd['relationship_type']),
      datingStyle: strList(pd['dating_style']),
      communicationStyle: strList(pd['communication_style']),
      firstMeetPreference: strList(pd['first_meet_preference']),
      loveLanguages: strList(pd['love_languages']),
      greenFlags: strList(pd['green_flags']),
      redFlags: strList(pd['red_flags']),
      interests: strList(row['interests']),
      favoritesRanked: strList(pd['favorites_ranked']),
      musicGenres: strList(pd['music_genres']),
      movieGenres: strList(pd['movie_genres']),
      weekendStyle: strList(pd['weekend_style']),
      humorStyle: strList(pd['humor_style']),
      visitedCountries: strList(row['countries_visited']),
      livedCountries: strList(pd['lived_countries']),
      wishlistCountries: strList(pd['wishlist_countries']),
      favoriteCities: strList(pd['favorite_cities']),
      travelStyle: strList(pd['travel_style']),
      relocationOpenness: pd['relocation_openness'] as String?,
      primaryRole: row['occupation'] as String?,
      secondaryRole: pd['secondary_role'] as String?,
      industry: strList(pd['industry']),
      workStyle: pd['work_style'] as String?,
      entrepreneurshipStatus: pd['entrepreneurship_status'] as String?,
      buildingNow: strList(pd['building_now']),
      sideProjects: strList(pd['side_projects']),
      workIntensity: pd['work_intensity'] as String?,
      aiTools: strList(pd['ai_tools']),
      socialMediaUsage: pd['social_media_usage'] as String?,
      onlineStyle: strList(pd['online_style']),
      techRelation: pd['tech_relation'] as String?,
      contentCreator: pd['content_creator'] as bool? ?? false,
      sleepStyle: pd['sleep_style'] as String?,
      dietStyle: pd['diet_style'] as String?,
      fitnessRoutine: pd['fitness_routine'] as String?,
      planningStyle: pd['planning_style'] as String?,
      spendingStyle: pd['spending_style'] as String?,
      fashionStyle: strList(pd['fashion_style']),
      homeVsOutside: pd['home_vs_outside'] as String?,
      cityVsNature: pd['city_vs_nature'] as String?,
      prompts: (pd['prompts'] as List?)?.map((e) => PromptAnswer.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      visibility: (pd['visibility'] as Map<String, dynamic>?)?.cast<String, String>() ?? {},
    );
  }

  /// Returns the update map to write to Supabase
  Map<String, dynamic> toUpdateMap() {
    final profileData = <String, dynamic>{
      'video_intro_url': videoIntroUrl,
      'voice_intro_url': voiceIntroUrl,
      'birth_date': birthDate,
      'country': country,
      'languages': languages.map((l) => l.toJson()).toList(),
      'education_level': educationLevel,
      'long_bio': longBio,
      'tagline': tagline,
      'current_focus': currentFocus,
      'interested_in': interestedIn,
      'pronouns': pronouns,
      'wants_children': wantsChildren,
      'pets_status': petsStatus,
      'pets_preference': petsPreference,
      'nightlife': nightlife,
      'social_energy': socialEnergy,
      'personality_style': personalityStyle,
      'organization_style': organizationStyle,
      'looking_for': lookingFor,
      'relationship_type': relationshipType,
      'dating_style': datingStyle,
      'communication_style': communicationStyle,
      'first_meet_preference': firstMeetPreference,
      'love_languages': loveLanguages,
      'green_flags': greenFlags,
      'red_flags': redFlags,
      'favorites_ranked': favoritesRanked,
      'music_genres': musicGenres,
      'movie_genres': movieGenres,
      'weekend_style': weekendStyle,
      'humor_style': humorStyle,
      'lived_countries': livedCountries,
      'wishlist_countries': wishlistCountries,
      'favorite_cities': favoriteCities,
      'travel_style': travelStyle,
      'relocation_openness': relocationOpenness,
      'secondary_role': secondaryRole,
      'industry': industry,
      'work_style': workStyle,
      'entrepreneurship_status': entrepreneurshipStatus,
      'building_now': buildingNow,
      'side_projects': sideProjects,
      'work_intensity': workIntensity,
      'ai_tools': aiTools,
      'social_media_usage': socialMediaUsage,
      'online_style': onlineStyle,
      'tech_relation': techRelation,
      'content_creator': contentCreator,
      'sleep_style': sleepStyle,
      'diet_style': dietStyle,
      'fitness_routine': fitnessRoutine,
      'planning_style': planningStyle,
      'spending_style': spendingStyle,
      'fashion_style': fashionStyle,
      'home_vs_outside': homeVsOutside,
      'city_vs_nature': cityVsNature,
      'prompts': prompts.map((p) => p.toJson()).toList(),
      'visibility': visibility,
    };

    return {
      'display_name': displayName,
      'bio': shortBio,
      'age': age,
      'height': height,
      'city': city,
      'from_country': hometown,
      'zodiac': zodiac,
      'gender': gender,
      'smokes': smoking,
      'drinks': alcohol,
      'faith_sensitivity': religiousApproach,
      'looking_for': lookingFor.isNotEmpty ? lookingFor.first : null,
      'interests': interests,
      'occupation': primaryRole,
      'vibe': null, // deprecated — use profile_data fields
      'countries_visited': visitedCountries,
      'photo_urls': photoUrls,
      'profile_data': profileData,
      if (photoUrls.isNotEmpty) 'date_avatar_url': photoUrls.first,
      if (photoUrls.isNotEmpty) 'bff_avatar_url': photoUrls.first,
    };
  }
}
