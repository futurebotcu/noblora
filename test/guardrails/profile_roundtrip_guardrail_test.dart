import 'package:flutter_test/flutter_test.dart';
import 'package:noblara/data/models/post.dart';
import 'package:noblara/data/models/profile.dart';

/// Guardrail: `Profile` modelinin HER alanı için:
///   1) `copyWith` çağrısı (tek alan değişikliği) diğer alanları korumalı.
///   2) `toJson -> fromJson` roundtrip alanları korumalı.
///
/// Şu an bu test büyük ihtimalle KIRIK — amacımız fix değil, EKSİKLERİ
/// GÖRÜNÜR KILMAK. Hangi alan `copyWith`'te kaybolmuş, hangi alan
/// `toJson`'da hiç serialize edilmiyor — her bir alan için ayrı
/// `expect` satırı olduğundan, test çıktısı doğrudan "kayıp" listesini
/// verir.
///
/// CLAUDE.md §7 Model Protokolü: `Profile`'a alan eklendiğinde bu test
/// de güncellenmelidir.
void main() {
  group('Profile copyWith preserves all fields', () {
    final original = _buildFullProfile();
    // Tek bir alanı (displayName) değiştirip diğerlerinin kaybolup
    // kaybolmadığını kontrol ediyoruz.
    final modified = original.copyWith(displayName: 'Changed Name');

    test('displayName was actually changed', () {
      expect(modified.displayName, 'Changed Name');
    });

    // 38 top-level alan (id, userId, displayName, gender, mode, scoreler,
    // bio alanları, liste alanları ...) — displayName hariç hepsi
    // değişmemiş olmalı.
    _testPreserved('id', original.id, () => modified.id);
    _testPreserved('userId', original.userId, () => modified.userId);
    _testPreserved('gender', original.gender, () => modified.gender);
    _testPreserved('mode', original.mode, () => modified.mode);
    _testPreserved('nobleScore', original.nobleScore, () => modified.nobleScore);
    _testPreserved('trustScore', original.trustScore, () => modified.trustScore);
    _testPreserved('nobTier', original.nobTier, () => modified.nobTier);
    _testPreserved('maturityScore', original.maturityScore, () => modified.maturityScore);
    _testPreserved('vitalityScore', original.vitalityScore, () => modified.vitalityScore);
    _testPreserved('profileCompletenessScore', original.profileCompletenessScore, () => modified.profileCompletenessScore);
    _testPreserved('communityScore', original.communityScore, () => modified.communityScore);
    _testPreserved('depthScore', original.depthScore, () => modified.depthScore);
    _testPreserved('followThroughScore', original.followThroughScore, () => modified.followThroughScore);
    _testPreserved('lastActiveAt', original.lastActiveAt, () => modified.lastActiveAt);
    _testPreserved('dateBio', original.dateBio, () => modified.dateBio);
    _testPreserved('dateAvatarUrl', original.dateAvatarUrl, () => modified.dateAvatarUrl);
    _testPreserved('bffBio', original.bffBio, () => modified.bffBio);
    _testPreserved('bffAvatarUrl', original.bffAvatarUrl, () => modified.bffAvatarUrl);
    _testPreserved('bio', original.bio, () => modified.bio);
    _testPreserved('age', original.age, () => modified.age);
    _testPreserved('city', original.city, () => modified.city);
    _testPreserved('occupation', original.occupation, () => modified.occupation);
    _testPreserved('height', original.height, () => modified.height);
    _testPreserved('philosophy', original.philosophy, () => modified.philosophy);
    _testPreserved('drinks', original.drinks, () => modified.drinks);
    _testPreserved('smokes', original.smokes, () => modified.smokes);
    _testPreserved('faithSensitivity', original.faithSensitivity, () => modified.faithSensitivity);
    _testPreserved('languages', original.languages, () => modified.languages);
    _testPreserved('fromCountry', original.fromCountry, () => modified.fromCountry);
    _testPreserved('countriesVisited', original.countriesVisited, () => modified.countriesVisited);
    _testPreserved('interests', original.interests, () => modified.interests);
    _testPreserved('vibe', original.vibe, () => modified.vibe);
    _testPreserved('lookingFor', original.lookingFor, () => modified.lookingFor);
    _testPreserved('zodiac', original.zodiac, () => modified.zodiac);
    _testPreserved('photoUrls', original.photoUrls, () => modified.photoUrls);

    // 35 rich profile_data alanı — bunlar hiç copyWith parametresinde
    // değil, yani const list / null defaultlarına düşmeleri bekleniyor.
    _testPreserved('longBio', original.longBio, () => modified.longBio);
    _testPreserved('tagline', original.tagline, () => modified.tagline);
    _testPreserved('currentFocus', original.currentFocus, () => modified.currentFocus);
    _testPreserved('pronouns', original.pronouns, () => modified.pronouns);
    _testPreserved('wantsChildren', original.wantsChildren, () => modified.wantsChildren);
    _testPreserved('relationshipType', original.relationshipType, () => modified.relationshipType);
    _testPreserved('datingStyle', original.datingStyle, () => modified.datingStyle);
    _testPreserved('communicationStyle', original.communicationStyle, () => modified.communicationStyle);
    _testPreserved('loveLanguages', original.loveLanguages, () => modified.loveLanguages);
    _testPreserved('musicGenres', original.musicGenres, () => modified.musicGenres);
    _testPreserved('movieGenres', original.movieGenres, () => modified.movieGenres);
    _testPreserved('weekendStyle', original.weekendStyle, () => modified.weekendStyle);
    _testPreserved('humorStyle', original.humorStyle, () => modified.humorStyle);
    _testPreserved('sleepStyle', original.sleepStyle, () => modified.sleepStyle);
    _testPreserved('dietStyle', original.dietStyle, () => modified.dietStyle);
    _testPreserved('fitnessRoutine', original.fitnessRoutine, () => modified.fitnessRoutine);
    _testPreserved('workStyle', original.workStyle, () => modified.workStyle);
    _testPreserved('entrepreneurshipStatus', original.entrepreneurshipStatus, () => modified.entrepreneurshipStatus);
    _testPreserved('secondaryRole', original.secondaryRole, () => modified.secondaryRole);
    _testPreserved('socialEnergy', original.socialEnergy, () => modified.socialEnergy);
    _testPreserved('workIntensity', original.workIntensity, () => modified.workIntensity);
    _testPreserved('educationLevel', original.educationLevel, () => modified.educationLevel);
    _testPreserved('relocationOpenness', original.relocationOpenness, () => modified.relocationOpenness);
    _testPreserved('interestedIn', original.interestedIn, () => modified.interestedIn);
    _testPreserved('firstMeetPreference', original.firstMeetPreference, () => modified.firstMeetPreference);
    _testPreserved('buildingNow', original.buildingNow, () => modified.buildingNow);
    _testPreserved('industry', original.industry, () => modified.industry);
    _testPreserved('aiTools', original.aiTools, () => modified.aiTools);
    _testPreserved('socialMediaUsage', original.socialMediaUsage, () => modified.socialMediaUsage);
    _testPreserved('techRelation', original.techRelation, () => modified.techRelation);
    _testPreserved('travelStyle', original.travelStyle, () => modified.travelStyle);
    _testPreserved('livedCountries', original.livedCountries, () => modified.livedCountries);
    _testPreserved('wishlistCountries', original.wishlistCountries, () => modified.wishlistCountries);
    _testPreserved('prompts', original.prompts, () => modified.prompts);
    _testPreserved('visibility', original.visibility, () => modified.visibility);
  });

  group('Profile toJson -> fromJson roundtrip', () {
    final original = _buildFullProfile();
    final json = original.toJson();
    final restored = Profile.fromJson(json);

    _testRoundtrip('id', original.id, () => restored.id);
    _testRoundtrip('userId', original.userId, () => restored.userId);
    _testRoundtrip('displayName', original.displayName, () => restored.displayName);
    _testRoundtrip('gender', original.gender, () => restored.gender);
    _testRoundtrip('mode', original.mode, () => restored.mode);
    _testRoundtrip('nobleScore', original.nobleScore, () => restored.nobleScore);
    _testRoundtrip('trustScore', original.trustScore, () => restored.trustScore);
    _testRoundtrip('nobTier', original.nobTier, () => restored.nobTier);
    _testRoundtrip('maturityScore', original.maturityScore, () => restored.maturityScore);
    _testRoundtrip('vitalityScore', original.vitalityScore, () => restored.vitalityScore);
    _testRoundtrip('profileCompletenessScore', original.profileCompletenessScore, () => restored.profileCompletenessScore);
    _testRoundtrip('communityScore', original.communityScore, () => restored.communityScore);
    _testRoundtrip('depthScore', original.depthScore, () => restored.depthScore);
    _testRoundtrip('followThroughScore', original.followThroughScore, () => restored.followThroughScore);
    _testRoundtrip('lastActiveAt', original.lastActiveAt, () => restored.lastActiveAt);
    _testRoundtrip('dateBio', original.dateBio, () => restored.dateBio);
    _testRoundtrip('dateAvatarUrl', original.dateAvatarUrl, () => restored.dateAvatarUrl);
    _testRoundtrip('bffBio', original.bffBio, () => restored.bffBio);
    _testRoundtrip('bffAvatarUrl', original.bffAvatarUrl, () => restored.bffAvatarUrl);
    _testRoundtrip('bio', original.bio, () => restored.bio);
    _testRoundtrip('age', original.age, () => restored.age);
    _testRoundtrip('city', original.city, () => restored.city);
    _testRoundtrip('occupation', original.occupation, () => restored.occupation);
    _testRoundtrip('height', original.height, () => restored.height);
    _testRoundtrip('philosophy', original.philosophy, () => restored.philosophy);
    _testRoundtrip('drinks', original.drinks, () => restored.drinks);
    _testRoundtrip('smokes', original.smokes, () => restored.smokes);
    _testRoundtrip('faithSensitivity', original.faithSensitivity, () => restored.faithSensitivity);
    _testRoundtrip('languages', original.languages, () => restored.languages);
    _testRoundtrip('fromCountry', original.fromCountry, () => restored.fromCountry);
    _testRoundtrip('countriesVisited', original.countriesVisited, () => restored.countriesVisited);
    _testRoundtrip('interests', original.interests, () => restored.interests);
    _testRoundtrip('vibe', original.vibe, () => restored.vibe);
    _testRoundtrip('lookingFor', original.lookingFor, () => restored.lookingFor);
    _testRoundtrip('zodiac', original.zodiac, () => restored.zodiac);
    _testRoundtrip('photoUrls', original.photoUrls, () => restored.photoUrls);

    _testRoundtrip('longBio', original.longBio, () => restored.longBio);
    _testRoundtrip('tagline', original.tagline, () => restored.tagline);
    _testRoundtrip('currentFocus', original.currentFocus, () => restored.currentFocus);
    _testRoundtrip('pronouns', original.pronouns, () => restored.pronouns);
    _testRoundtrip('wantsChildren', original.wantsChildren, () => restored.wantsChildren);
    _testRoundtrip('relationshipType', original.relationshipType, () => restored.relationshipType);
    _testRoundtrip('datingStyle', original.datingStyle, () => restored.datingStyle);
    _testRoundtrip('communicationStyle', original.communicationStyle, () => restored.communicationStyle);
    _testRoundtrip('loveLanguages', original.loveLanguages, () => restored.loveLanguages);
    _testRoundtrip('musicGenres', original.musicGenres, () => restored.musicGenres);
    _testRoundtrip('movieGenres', original.movieGenres, () => restored.movieGenres);
    _testRoundtrip('weekendStyle', original.weekendStyle, () => restored.weekendStyle);
    _testRoundtrip('humorStyle', original.humorStyle, () => restored.humorStyle);
    _testRoundtrip('sleepStyle', original.sleepStyle, () => restored.sleepStyle);
    _testRoundtrip('dietStyle', original.dietStyle, () => restored.dietStyle);
    _testRoundtrip('fitnessRoutine', original.fitnessRoutine, () => restored.fitnessRoutine);
    _testRoundtrip('workStyle', original.workStyle, () => restored.workStyle);
    _testRoundtrip('entrepreneurshipStatus', original.entrepreneurshipStatus, () => restored.entrepreneurshipStatus);
    _testRoundtrip('secondaryRole', original.secondaryRole, () => restored.secondaryRole);
    _testRoundtrip('socialEnergy', original.socialEnergy, () => restored.socialEnergy);
    _testRoundtrip('workIntensity', original.workIntensity, () => restored.workIntensity);
    _testRoundtrip('educationLevel', original.educationLevel, () => restored.educationLevel);
    _testRoundtrip('relocationOpenness', original.relocationOpenness, () => restored.relocationOpenness);
    _testRoundtrip('interestedIn', original.interestedIn, () => restored.interestedIn);
    _testRoundtrip('firstMeetPreference', original.firstMeetPreference, () => restored.firstMeetPreference);
    _testRoundtrip('buildingNow', original.buildingNow, () => restored.buildingNow);
    _testRoundtrip('industry', original.industry, () => restored.industry);
    _testRoundtrip('aiTools', original.aiTools, () => restored.aiTools);
    _testRoundtrip('socialMediaUsage', original.socialMediaUsage, () => restored.socialMediaUsage);
    _testRoundtrip('techRelation', original.techRelation, () => restored.techRelation);
    _testRoundtrip('travelStyle', original.travelStyle, () => restored.travelStyle);
    _testRoundtrip('livedCountries', original.livedCountries, () => restored.livedCountries);
    _testRoundtrip('wishlistCountries', original.wishlistCountries, () => restored.wishlistCountries);
    _testRoundtrip('promptsLength', original.prompts.length, () => restored.prompts.length);
    _testRoundtrip('visibility', original.visibility, () => restored.visibility);
  });
}

void _testPreserved<T>(String field, T expected, T Function() actualGetter) {
  test('copyWith preserves $field', () {
    expect(
      actualGetter(),
      equals(expected),
      reason: 'copyWith drift: field `$field` was not preserved',
    );
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

Profile _buildFullProfile() {
  return Profile(
    id: 'profile-id-1',
    userId: 'profile-id-1',
    displayName: 'Original Name',
    gender: 'male',
    mode: 'date',
    nobleScore: 42,
    trustScore: 77,
    nobTier: NobTier.noble,
    maturityScore: 55.5,
    vitalityScore: 88.0,
    profileCompletenessScore: 66,
    communityScore: 33,
    depthScore: 44,
    followThroughScore: 55,
    lastActiveAt: DateTime.utc(2026, 4, 20, 12, 0, 0),
    dateBio: 'date bio',
    dateAvatarUrl: 'https://example.com/date.jpg',
    bffBio: 'bff bio',
    bffAvatarUrl: 'https://example.com/bff.jpg',
    bio: 'general bio',
    age: 30,
    city: 'Istanbul',
    occupation: 'Engineer',
    height: 180,
    philosophy: 'Stoic',
    drinks: 'Socially',
    smokes: 'Never',
    faithSensitivity: 'Medium',
    languages: const ['English', 'Turkish'],
    fromCountry: 'TR',
    countriesVisited: const ['DE', 'FR'],
    interests: const ['climbing', 'chess'],
    vibe: 'calm',
    lookingFor: 'serious',
    zodiac: 'Leo',
    photoUrls: const ['a.jpg', 'b.jpg'],
    longBio: 'long long bio',
    tagline: 'a tagline',
    currentFocus: 'focus',
    pronouns: 'he/him',
    wantsChildren: 'Yes',
    relationshipType: const ['monogamous'],
    datingStyle: const ['slow'],
    communicationStyle: const ['direct'],
    loveLanguages: const ['quality_time'],
    musicGenres: const ['jazz'],
    movieGenres: const ['thriller'],
    weekendStyle: const ['outdoor'],
    humorStyle: const ['dry'],
    sleepStyle: 'early',
    dietStyle: 'flexitarian',
    fitnessRoutine: 'daily',
    workStyle: 'async',
    entrepreneurshipStatus: 'founder',
    secondaryRole: 'mentor',
    socialEnergy: 'ambivert',
    workIntensity: 'high',
    educationLevel: 'masters',
    relocationOpenness: 'open',
    interestedIn: const ['women'],
    firstMeetPreference: const ['coffee'],
    buildingNow: const ['startup'],
    industry: const ['tech'],
    aiTools: const ['claude'],
    socialMediaUsage: 'low',
    techRelation: 'high',
    travelStyle: const ['backpacking'],
    livedCountries: const ['TR', 'DE'],
    wishlistCountries: const ['JP'],
    prompts: const [PromptAnswer(question: 'q1', answer: 'a1')],
    visibility: const {'bio': 'Public', 'age': 'Private'},
  );
}
