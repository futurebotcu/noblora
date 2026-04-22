import 'package:flutter_test/flutter_test.dart';
import 'package:noblara/features/profile/edit/profile_draft.dart';

/// Guardrail: ProfileDraft.toUpdateMap -> ProfileDraft.fromDbRow
/// roundtrip her alanı korumalı.
///
/// R2 (profile_draft asenkron) bu testle yüzeye çıkar. İlk run'da:
/// - lookingFor: read precedence yanlış (row öncelikli, full list pd'de)
///   → dolu listenin sadece ilk elemanı korunur, geri kalan kaybolur.
/// - visitedCountries: write toUpdateMap'te eksik → tamamen silinir.
/// Diğer 71 alan symmetric kontrat üzerinde.
///
/// CLAUDE.md §7 Model Protokolü: ProfileDraft'a alan eklendiğinde bu
/// test de güncellenmelidir.
void main() {
  group('ProfileDraft toUpdateMap -> fromDbRow roundtrip', () {
    final original = _buildFullDraft();
    final map = original.toUpdateMap();
    final restored = ProfileDraft.fromDbRow(map);

    // Photos & Media
    _testRoundtrip('photoUrls', original.photoUrls, () => restored.photoUrls);
    _testRoundtrip('videoIntroUrl', original.videoIntroUrl, () => restored.videoIntroUrl);
    _testRoundtrip('voiceIntroUrl', original.voiceIntroUrl, () => restored.voiceIntroUrl);

    // Basic Info
    _testRoundtrip('displayName', original.displayName, () => restored.displayName);
    _testRoundtrip('birthDate', original.birthDate, () => restored.birthDate);
    _testRoundtrip('age', original.age, () => restored.age);
    _testRoundtrip('height', original.height, () => restored.height);
    _testRoundtrip('city', original.city, () => restored.city);
    _testRoundtrip('country', original.country, () => restored.country);
    _testRoundtrip('hometown', original.hometown, () => restored.hometown);
    _testRoundtrip(
      'languages',
      original.languages.map((l) => l.toJson()).toList(),
      () => restored.languages.map((l) => l.toJson()).toList(),
    );
    _testRoundtrip('zodiac', original.zodiac, () => restored.zodiac);
    _testRoundtrip('educationLevel', original.educationLevel, () => restored.educationLevel);

    // About
    _testRoundtrip('shortBio', original.shortBio, () => restored.shortBio);
    _testRoundtrip('longBio', original.longBio, () => restored.longBio);
    _testRoundtrip('tagline', original.tagline, () => restored.tagline);
    _testRoundtrip('currentFocus', original.currentFocus, () => restored.currentFocus);

    // Identity & Life
    _testRoundtrip('gender', original.gender, () => restored.gender);
    _testRoundtrip('interestedIn', original.interestedIn, () => restored.interestedIn);
    _testRoundtrip('pronouns', original.pronouns, () => restored.pronouns);
    _testRoundtrip('religiousApproach', original.religiousApproach, () => restored.religiousApproach);
    _testRoundtrip('wantsChildren', original.wantsChildren, () => restored.wantsChildren);
    _testRoundtrip('petsStatus', original.petsStatus, () => restored.petsStatus);
    _testRoundtrip('petsPreference', original.petsPreference, () => restored.petsPreference);
    _testRoundtrip('smoking', original.smoking, () => restored.smoking);
    _testRoundtrip('alcohol', original.alcohol, () => restored.alcohol);
    _testRoundtrip('nightlife', original.nightlife, () => restored.nightlife);
    _testRoundtrip('socialEnergy', original.socialEnergy, () => restored.socialEnergy);
    _testRoundtrip('personalityStyle', original.personalityStyle, () => restored.personalityStyle);
    _testRoundtrip('organizationStyle', original.organizationStyle, () => restored.organizationStyle);

    // Relationship
    _testRoundtrip('lookingFor', original.lookingFor, () => restored.lookingFor);
    _testRoundtrip('relationshipType', original.relationshipType, () => restored.relationshipType);
    _testRoundtrip('datingStyle', original.datingStyle, () => restored.datingStyle);
    _testRoundtrip('communicationStyle', original.communicationStyle, () => restored.communicationStyle);
    _testRoundtrip('firstMeetPreference', original.firstMeetPreference, () => restored.firstMeetPreference);
    _testRoundtrip('loveLanguages', original.loveLanguages, () => restored.loveLanguages);
    _testRoundtrip('greenFlags', original.greenFlags, () => restored.greenFlags);
    _testRoundtrip('redFlags', original.redFlags, () => restored.redFlags);

    // Interests
    _testRoundtrip('interests', original.interests, () => restored.interests);
    _testRoundtrip('favoritesRanked', original.favoritesRanked, () => restored.favoritesRanked);

    // Culture & Social
    _testRoundtrip('musicGenres', original.musicGenres, () => restored.musicGenres);
    _testRoundtrip('movieGenres', original.movieGenres, () => restored.movieGenres);
    _testRoundtrip('weekendStyle', original.weekendStyle, () => restored.weekendStyle);
    _testRoundtrip('humorStyle', original.humorStyle, () => restored.humorStyle);

    // Travel
    _testRoundtrip('visitedCountries', original.visitedCountries, () => restored.visitedCountries);
    _testRoundtrip('livedCountries', original.livedCountries, () => restored.livedCountries);
    _testRoundtrip('wishlistCountries', original.wishlistCountries, () => restored.wishlistCountries);
    _testRoundtrip('favoriteCities', original.favoriteCities, () => restored.favoriteCities);
    _testRoundtrip('travelStyle', original.travelStyle, () => restored.travelStyle);
    _testRoundtrip('relocationOpenness', original.relocationOpenness, () => restored.relocationOpenness);

    // Career
    _testRoundtrip('primaryRole', original.primaryRole, () => restored.primaryRole);
    _testRoundtrip('secondaryRole', original.secondaryRole, () => restored.secondaryRole);
    _testRoundtrip('industry', original.industry, () => restored.industry);
    _testRoundtrip('workStyle', original.workStyle, () => restored.workStyle);
    _testRoundtrip('entrepreneurshipStatus', original.entrepreneurshipStatus, () => restored.entrepreneurshipStatus);
    _testRoundtrip('buildingNow', original.buildingNow, () => restored.buildingNow);
    _testRoundtrip('sideProjects', original.sideProjects, () => restored.sideProjects);
    _testRoundtrip('workIntensity', original.workIntensity, () => restored.workIntensity);

    // Digital Life
    _testRoundtrip('aiTools', original.aiTools, () => restored.aiTools);
    _testRoundtrip('socialMediaUsage', original.socialMediaUsage, () => restored.socialMediaUsage);
    _testRoundtrip('onlineStyle', original.onlineStyle, () => restored.onlineStyle);
    _testRoundtrip('techRelation', original.techRelation, () => restored.techRelation);
    _testRoundtrip('contentCreator', original.contentCreator, () => restored.contentCreator);

    // Lifestyle
    _testRoundtrip('sleepStyle', original.sleepStyle, () => restored.sleepStyle);
    _testRoundtrip('dietStyle', original.dietStyle, () => restored.dietStyle);
    _testRoundtrip('fitnessRoutine', original.fitnessRoutine, () => restored.fitnessRoutine);
    _testRoundtrip('planningStyle', original.planningStyle, () => restored.planningStyle);
    _testRoundtrip('spendingStyle', original.spendingStyle, () => restored.spendingStyle);
    _testRoundtrip('fashionStyle', original.fashionStyle, () => restored.fashionStyle);
    _testRoundtrip('homeVsOutside', original.homeVsOutside, () => restored.homeVsOutside);
    _testRoundtrip('cityVsNature', original.cityVsNature, () => restored.cityVsNature);

    // Prompts
    _testRoundtrip(
      'prompts',
      original.prompts.map((p) => p.toJson()).toList(),
      () => restored.prompts.map((p) => p.toJson()).toList(),
    );

    // Visibility
    _testRoundtrip('visibility', original.visibility, () => restored.visibility);
  });
}

void _testRoundtrip<T>(String field, T expected, T Function() actualGetter) {
  test('roundtrip preserves $field', () {
    expect(
      actualGetter(),
      equals(expected),
      reason: 'roundtrip lost field `$field`',
    );
  });
}

ProfileDraft _buildFullDraft() {
  return ProfileDraft(
    // Photos & Media
    photoUrls: const ['a.jpg', 'b.jpg'],
    videoIntroUrl: 'https://example.com/video.mp4',
    voiceIntroUrl: 'https://example.com/voice.m4a',
    // Basic Info
    displayName: 'Original Name',
    birthDate: '1995-06-15',
    age: 30,
    height: 180,
    city: 'Istanbul',
    country: 'TR',
    hometown: 'Izmir',
    languages: const [
      LanguageEntry(code: 'en', label: 'English', level: 'Fluent'),
      LanguageEntry(code: 'tr', label: 'Turkish', level: 'Native'),
    ],
    zodiac: 'Leo',
    educationLevel: 'masters',
    // About
    shortBio: 'short bio',
    longBio: 'long long bio',
    tagline: 'a tagline',
    currentFocus: 'focus',
    // Identity & Life
    gender: 'male',
    interestedIn: const ['women'],
    pronouns: 'he/him',
    religiousApproach: 'Medium',
    wantsChildren: 'Yes',
    petsStatus: 'has_dog',
    petsPreference: const ['dogs', 'cats'],
    smoking: 'Never',
    alcohol: 'Socially',
    nightlife: 'Sometimes',
    socialEnergy: 'ambivert',
    personalityStyle: 'INTJ',
    organizationStyle: 'planner',
    // Relationship — lookingFor BİLEREK çoklu (asimetri kanıtı)
    lookingFor: const ['serious', 'longterm', 'marriage'],
    relationshipType: const ['monogamous'],
    datingStyle: const ['slow'],
    communicationStyle: const ['direct'],
    firstMeetPreference: const ['coffee'],
    loveLanguages: const ['quality_time'],
    greenFlags: const ['kind', 'curious'],
    redFlags: const ['rude'],
    // Interests
    interests: const ['climbing', 'chess'],
    favoritesRanked: const ['book:dune', 'movie:arrival'],
    // Culture & Social
    musicGenres: const ['jazz'],
    movieGenres: const ['thriller'],
    weekendStyle: const ['outdoor'],
    humorStyle: const ['dry'],
    // Travel — visitedCountries BİLEREK dolu (asimetri kanıtı)
    visitedCountries: const ['DE', 'FR', 'JP'],
    livedCountries: const ['TR', 'DE'],
    wishlistCountries: const ['JP'],
    favoriteCities: const ['Tokyo', 'Berlin'],
    travelStyle: const ['backpacking'],
    relocationOpenness: 'open',
    // Career
    primaryRole: 'Engineer',
    secondaryRole: 'mentor',
    industry: const ['tech'],
    workStyle: 'async',
    entrepreneurshipStatus: 'founder',
    buildingNow: const ['startup'],
    sideProjects: const ['blog'],
    workIntensity: 'high',
    // Digital Life
    aiTools: const ['claude'],
    socialMediaUsage: 'low',
    onlineStyle: const ['lurker'],
    techRelation: 'high',
    contentCreator: true,
    // Lifestyle
    sleepStyle: 'early',
    dietStyle: 'flexitarian',
    fitnessRoutine: 'daily',
    planningStyle: 'planner',
    spendingStyle: 'saver',
    fashionStyle: const ['minimal'],
    homeVsOutside: 'home',
    cityVsNature: 'city',
    // Prompts
    prompts: const [
      PromptAnswer(question: 'q1', answer: 'a1'),
      PromptAnswer(question: 'q2', answer: 'a2'),
    ],
    // Visibility
    visibility: const {'bio': 'Public', 'age': 'Private'},
  );
}
