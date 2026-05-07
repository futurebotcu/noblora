import 'package:flutter/material.dart';
import '../../core/enums/noble_mode.dart';

/// Complete filter state for the Discovery Control Panel.
class FilterState {
  // ── Common ──
  final RangeValues ageRange;
  final double maxDistance;
  final bool trustShieldEnabled;
  final List<String> languages;
  final String? statusBadge; // 'all', 'explorer_plus', 'noble'

  // ── Dating ──
  final String? lookingFor; // Serious / Long-term / Intentional / Open
  final String? drinks;
  final String? smokes;
  final String? nightlife;
  final String? socialEnergy;
  final String? routine;
  final String? faithSensitivity;
  final bool hasNobs;
  final bool hasPrompts;
  final bool sixPlusPhotos;
  final bool pinnedNobExists;
  final bool sameCityOnly;
  // ── BFF ──
  final String? bffLookingFor; // New friends / Activity buddy / City companion / Social circle
  final List<String> interests;

  const FilterState({
    this.ageRange = const RangeValues(18, 45),
    this.maxDistance = 25,
    this.trustShieldEnabled = false,
    this.languages = const [],
    this.statusBadge,
    this.lookingFor,
    this.drinks,
    this.smokes,
    this.nightlife,
    this.socialEnergy,
    this.routine,
    this.faithSensitivity,
    this.hasNobs = false,
    this.hasPrompts = false,
    this.sixPlusPhotos = false,
    this.pinnedNobExists = false,
    this.sameCityOnly = false,
    this.bffLookingFor,
    this.interests = const [],
  });

  FilterState copyWith({
    RangeValues? ageRange,
    double? maxDistance,
    bool? trustShieldEnabled,
    List<String>? languages,
    String? statusBadge,
    String? lookingFor,
    String? drinks,
    String? smokes,
    String? nightlife,
    String? socialEnergy,
    String? routine,
    String? faithSensitivity,
    bool? hasNobs,
    bool? hasPrompts,
    bool? sixPlusPhotos,
    bool? pinnedNobExists,
    bool? sameCityOnly,
    String? bffLookingFor,
    List<String>? interests,
    bool clearLookingFor = false,
    bool clearDrinks = false,
    bool clearSmokes = false,
    bool clearNightlife = false,
    bool clearSocialEnergy = false,
    bool clearRoutine = false,
    bool clearFaith = false,
    bool clearStatusBadge = false,
    bool clearBffLookingFor = false,
  }) {
    return FilterState(
      ageRange: ageRange ?? this.ageRange,
      maxDistance: maxDistance ?? this.maxDistance,
      trustShieldEnabled: trustShieldEnabled ?? this.trustShieldEnabled,
      languages: languages ?? this.languages,
      statusBadge: clearStatusBadge ? null : (statusBadge ?? this.statusBadge),
      lookingFor: clearLookingFor ? null : (lookingFor ?? this.lookingFor),
      drinks: clearDrinks ? null : (drinks ?? this.drinks),
      smokes: clearSmokes ? null : (smokes ?? this.smokes),
      nightlife: clearNightlife ? null : (nightlife ?? this.nightlife),
      socialEnergy: clearSocialEnergy ? null : (socialEnergy ?? this.socialEnergy),
      routine: clearRoutine ? null : (routine ?? this.routine),
      faithSensitivity: clearFaith ? null : (faithSensitivity ?? this.faithSensitivity),
      hasNobs: hasNobs ?? this.hasNobs,
      hasPrompts: hasPrompts ?? this.hasPrompts,
      sixPlusPhotos: sixPlusPhotos ?? this.sixPlusPhotos,
      pinnedNobExists: pinnedNobExists ?? this.pinnedNobExists,
      sameCityOnly: sameCityOnly ?? this.sameCityOnly,
      bffLookingFor: clearBffLookingFor ? null : (bffLookingFor ?? this.bffLookingFor),
      interests: interests ?? this.interests,
    );
  }

  /// True when filters are active that the oracle RPC doesn't support
  bool get hasExtraFilters =>
      hasNobs || hasPrompts || sixPlusPhotos || pinnedNobExists ||
      drinks != null || smokes != null || nightlife != null ||
      socialEnergy != null || routine != null || faithSensitivity != null ||
      lookingFor != null || bffLookingFor != null || sameCityOnly;

  /// Count of active filters for badge display.
  int activeCount(NobleMode mode) {
    int c = 0;
    if (ageRange.start != 18 || ageRange.end != 45) c++;
    if (maxDistance != 25) c++;
    if (trustShieldEnabled) c++;
    if (languages.isNotEmpty) c++;
    if (statusBadge != null) c++;

    if (mode == NobleMode.date) {
      if (lookingFor != null) c++;
      if (drinks != null) c++;
      if (smokes != null) c++;
      if (nightlife != null) c++;
      if (socialEnergy != null) c++;
      if (routine != null) c++;
      if (faithSensitivity != null) c++;
      if (hasNobs) c++;
      if (hasPrompts) c++;
      if (sixPlusPhotos) c++;
      if (pinnedNobExists) c++;
      if (sameCityOnly) c++;
    } else if (mode == NobleMode.bff) {
      if (bffLookingFor != null) c++;
      if (interests.isNotEmpty) c++;
      if (socialEnergy != null) c++;
      if (routine != null) c++;
      if (hasNobs) c++;
    }
    return c;
  }

  /// Mock result count based on active filters.
  int estimatedResults(NobleMode mode) {
    const base = 50;
    final total = activeCount(mode);
    return (base - total).clamp(0, 99);
  }
}

// ── Chip option lists ────────────────────────────────────────────────

const datingLookingForOptions = ['Serious relationship', 'Long-term', 'Intentional', 'Open'];
const bffLookingForOptions = ['New friends', 'Activity buddy', 'City companion', 'Social circle'];
const drinksOptions = ['Never', 'Sometimes', 'Socially', 'Often'];
const smokesOptions = ['Never', 'Sometimes', 'Often'];
const nightlifeOptions = ['Rarely', 'Sometimes', 'Often'];
const socialEnergyOptions = ['Quiet', 'Balanced', 'Social'];
const bffSocialEnergyOptions = ['Quiet', 'Balanced', 'Very social'];
const routineOptions = ['Structured', 'Flexible', 'Spontaneous'];
const faithOptions = ['Not important', 'Somewhat', 'Important'];
const bffInterestOptions = [
  'Reading', 'Coffee', 'Walking', 'Gym', 'Running', 'Coding',
  'Design', 'Startups', 'Gaming', 'Museums', 'Travel', 'Writing',
  'Language learning', 'Nature', 'Entrepreneurship',
];
const languageOptions = ['Turkish', 'English', 'Arabic', 'French', 'German', 'Spanish', 'Italian', 'Russian', 'Japanese', 'Persian'];
const statusBadgeOptions = ['All', 'Explorer+', 'Noble only'];
