import 'package:flutter/material.dart';
import '../../core/enums/noble_mode.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum RelationshipGoal { serious, casual, marriage, undecided }

enum EducationLevel { highSchool, bachelor, master, phd, other }

enum FamilyPlan { wantsKids, hasKids, doesntWantKids, undecided }

enum LifestyleSmoke { nonSmoker, smoker, occasionally }

enum LifestyleDrink { nonDrinker, drinker, occasionally }

enum EventType { rooftopDinner, artOpening, networkingNight, yoga, travel, other }

extension RelationshipGoalX on RelationshipGoal {
  String get label {
    switch (this) {
      case RelationshipGoal.serious:
        return 'Serious relationship';
      case RelationshipGoal.casual:
        return 'Casual dating';
      case RelationshipGoal.marriage:
        return 'Marriage';
      case RelationshipGoal.undecided:
        return 'Not sure yet';
    }
  }
}

extension EducationLevelX on EducationLevel {
  String get label {
    switch (this) {
      case EducationLevel.highSchool:
        return 'High School';
      case EducationLevel.bachelor:
        return 'Bachelor\'s';
      case EducationLevel.master:
        return 'Master\'s';
      case EducationLevel.phd:
        return 'PhD';
      case EducationLevel.other:
        return 'Other';
    }
  }
}

extension FamilyPlanX on FamilyPlan {
  String get label {
    switch (this) {
      case FamilyPlan.wantsKids:
        return 'Wants kids';
      case FamilyPlan.hasKids:
        return 'Has kids';
      case FamilyPlan.doesntWantKids:
        return 'Doesn\'t want kids';
      case FamilyPlan.undecided:
        return 'Undecided';
    }
  }
}

extension LifestyleSmokeX on LifestyleSmoke {
  String get label {
    switch (this) {
      case LifestyleSmoke.nonSmoker:
        return 'Non-smoker';
      case LifestyleSmoke.smoker:
        return 'Smoker';
      case LifestyleSmoke.occasionally:
        return 'Occasionally';
    }
  }
}

extension LifestyleDrinkX on LifestyleDrink {
  String get label {
    switch (this) {
      case LifestyleDrink.nonDrinker:
        return 'Non-drinker';
      case LifestyleDrink.drinker:
        return 'Social drinker';
      case LifestyleDrink.occasionally:
        return 'Occasionally';
    }
  }
}

extension EventTypeX on EventType {
  String get label {
    switch (this) {
      case EventType.rooftopDinner:
        return 'Rooftop Dinner';
      case EventType.artOpening:
        return 'Art Opening';
      case EventType.networkingNight:
        return 'Networking Night';
      case EventType.yoga:
        return 'Wellness & Yoga';
      case EventType.travel:
        return 'Travel Meetups';
      case EventType.other:
        return 'Other';
    }
  }
}

// ---------------------------------------------------------------------------
// FilterOptions
// ---------------------------------------------------------------------------

class FilterOptions {
  // Common
  final RangeValues ageRange;
  final double maxDistance; // km
  final String? city;

  // Noble Date
  final RelationshipGoal? relationshipGoal;
  final EducationLevel? education;
  final String? profession;
  final FamilyPlan? familyPlan;
  final LifestyleSmoke? smoking;
  final LifestyleDrink? drinking;

  // Noble BFF / Social — shared interests
  final List<String> interests;
  final List<String> languages;

  // Noble Social
  final List<EventType> eventTypes;
  final List<String> availabilityDays;

  const FilterOptions({
    this.ageRange = const RangeValues(18, 65),
    this.maxDistance = 100,
    this.city,
    this.relationshipGoal,
    this.education,
    this.profession,
    this.familyPlan,
    this.smoking,
    this.drinking,
    this.interests = const [],
    this.languages = const [],
    this.eventTypes = const [],
    this.availabilityDays = const [],
  });

  FilterOptions copyWith({
    RangeValues? ageRange,
    double? maxDistance,
    String? city,
    RelationshipGoal? relationshipGoal,
    EducationLevel? education,
    String? profession,
    FamilyPlan? familyPlan,
    LifestyleSmoke? smoking,
    LifestyleDrink? drinking,
    List<String>? interests,
    List<String>? languages,
    List<EventType>? eventTypes,
    List<String>? availabilityDays,
    bool clearCity = false,
    bool clearRelationshipGoal = false,
    bool clearEducation = false,
    bool clearProfession = false,
    bool clearFamilyPlan = false,
    bool clearSmoking = false,
    bool clearDrinking = false,
  }) {
    return FilterOptions(
      ageRange: ageRange ?? this.ageRange,
      maxDistance: maxDistance ?? this.maxDistance,
      city: clearCity ? null : (city ?? this.city),
      relationshipGoal: clearRelationshipGoal
          ? null
          : (relationshipGoal ?? this.relationshipGoal),
      education: clearEducation ? null : (education ?? this.education),
      profession: clearProfession ? null : (profession ?? this.profession),
      familyPlan: clearFamilyPlan ? null : (familyPlan ?? this.familyPlan),
      smoking: clearSmoking ? null : (smoking ?? this.smoking),
      drinking: clearDrinking ? null : (drinking ?? this.drinking),
      interests: interests ?? this.interests,
      languages: languages ?? this.languages,
      eventTypes: eventTypes ?? this.eventTypes,
      availabilityDays: availabilityDays ?? this.availabilityDays,
    );
  }

  int activeCount(NobleMode mode) {
    int count = 0;
    if (ageRange.start != 18 || ageRange.end != 65) count++;
    if (maxDistance != 100) count++;
    if (city != null) count++;

    switch (mode) {
      case NobleMode.date:
        if (relationshipGoal != null) count++;
        if (education != null) count++;
        if (profession != null) count++;
        if (familyPlan != null) count++;
        if (smoking != null) count++;
        if (drinking != null) count++;
      case NobleMode.bff:
        if (interests.isNotEmpty) count++;
        if (languages.isNotEmpty) count++;
      case NobleMode.social:
        if (eventTypes.isNotEmpty) count++;
        if (availabilityDays.isNotEmpty) count++;
        if (interests.isNotEmpty) count++;
      case NobleMode.noblara:
        break;
    }
    return count;
  }

  FilterOptions reset() => const FilterOptions();
}

// ---------------------------------------------------------------------------
// Static lists for UI chips
// ---------------------------------------------------------------------------

const allInterests = [
  'Travel', 'Art', 'Music', 'Fitness', 'Food & Wine',
  'Photography', 'Reading', 'Tech', 'Fashion', 'Nature',
  'Film', 'Yoga', 'Sailing', 'Architecture', 'Investing',
];

const allLanguages = [
  'Turkish', 'English', 'Arabic', 'French', 'German',
  'Spanish', 'Italian', 'Russian', 'Japanese', 'Persian',
];

const allDays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday',
  'Friday', 'Saturday', 'Sunday',
];
