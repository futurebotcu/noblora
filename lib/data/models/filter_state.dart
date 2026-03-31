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
  final bool verifiedOnly;
  final bool completeOnly;
  final bool hasNobs;
  final bool hasPrompts;
  final bool sixPlusPhotos;
  final List<String> fromCountries;

  // ── BFF ──
  final String? bffLookingFor; // New friends / Activity buddy / City companion / Social circle
  final List<String> vibes;
  final List<String> interests;

  // ── Strict mode ──
  final Set<String> strictFilters; // keys of filters that are strict (hard)

  // ── Presets ──
  final String? activePreset;

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
    this.verifiedOnly = false,
    this.completeOnly = false,
    this.hasNobs = false,
    this.hasPrompts = false,
    this.sixPlusPhotos = false,
    this.fromCountries = const [],
    this.bffLookingFor,
    this.vibes = const [],
    this.interests = const [],
    this.strictFilters = const {},
    this.activePreset,
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
    bool? verifiedOnly,
    bool? completeOnly,
    bool? hasNobs,
    bool? hasPrompts,
    bool? sixPlusPhotos,
    List<String>? fromCountries,
    String? bffLookingFor,
    List<String>? vibes,
    List<String>? interests,
    Set<String>? strictFilters,
    String? activePreset,
    bool clearLookingFor = false,
    bool clearDrinks = false,
    bool clearSmokes = false,
    bool clearNightlife = false,
    bool clearSocialEnergy = false,
    bool clearRoutine = false,
    bool clearFaith = false,
    bool clearStatusBadge = false,
    bool clearBffLookingFor = false,
    bool clearPreset = false,
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
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      completeOnly: completeOnly ?? this.completeOnly,
      hasNobs: hasNobs ?? this.hasNobs,
      hasPrompts: hasPrompts ?? this.hasPrompts,
      sixPlusPhotos: sixPlusPhotos ?? this.sixPlusPhotos,
      fromCountries: fromCountries ?? this.fromCountries,
      bffLookingFor: clearBffLookingFor ? null : (bffLookingFor ?? this.bffLookingFor),
      vibes: vibes ?? this.vibes,
      interests: interests ?? this.interests,
      strictFilters: strictFilters ?? this.strictFilters,
      activePreset: clearPreset ? null : (activePreset ?? this.activePreset),
    );
  }

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
      if (verifiedOnly) c++;
      if (completeOnly) c++;
      if (hasNobs) c++;
      if (hasPrompts) c++;
      if (sixPlusPhotos) c++;
      if (fromCountries.isNotEmpty) c++;
    } else if (mode == NobleMode.bff) {
      if (bffLookingFor != null) c++;
      if (vibes.isNotEmpty) c++;
      if (interests.isNotEmpty) c++;
      if (socialEnergy != null) c++;
      if (routine != null) c++;
      if (verifiedOnly) c++;
      if (completeOnly) c++;
      if (hasNobs) c++;
    }
    return c;
  }

  /// Mock result count based on active filters.
  int estimatedResults(NobleMode mode) {
    int base = 50;
    final strict = strictFilters.length;
    final total = activeCount(mode);
    final prefs = total - strict;
    return (base - strict * 3 - prefs).clamp(0, 99);
  }

  bool isStrict(String key) => strictFilters.contains(key);

  FilterState toggleStrict(String key) {
    final next = Set<String>.from(strictFilters);
    next.contains(key) ? next.remove(key) : next.add(key);
    return copyWith(strictFilters: next, clearPreset: true);
  }
}

// ── Preset definitions ──────────────────────────────────────────────

class FilterPreset {
  final String id;
  final String label;
  final NobleMode mode;
  final FilterState Function(FilterState) apply;
  const FilterPreset({required this.id, required this.label, required this.mode, required this.apply});
}

final datingPresets = [
  FilterPreset(
    id: 'serious_only', label: 'Serious Only', mode: NobleMode.date,
    apply: (s) => s.copyWith(lookingFor: 'Serious relationship', verifiedOnly: true, statusBadge: 'noble'),
  ),
  FilterPreset(
    id: 'calm_profiles', label: 'Calm Profiles', mode: NobleMode.date,
    apply: (s) => s.copyWith(socialEnergy: 'Quiet', completeOnly: true),
  ),
  FilterPreset(
    id: 'lifestyle_aligned', label: 'Lifestyle Aligned', mode: NobleMode.date,
    apply: (s) => s.copyWith(
      strictFilters: {'drinks', 'smokes', 'routine'},
    ),
  ),
];

final bffPresets = [
  FilterPreset(
    id: 'weekend_mode', label: 'Weekend Mode', mode: NobleMode.bff,
    apply: (s) => s.copyWith(socialEnergy: 'Very social', maxDistance: 10),
  ),
  FilterPreset(
    id: 'coffee_buddy', label: 'Coffee Buddy', mode: NobleMode.bff,
    apply: (s) => s.copyWith(interests: ['Coffee'], maxDistance: 2),
  ),
  FilterPreset(
    id: 'structured', label: 'Structured People', mode: NobleMode.bff,
    apply: (s) => s.copyWith(routine: 'Structured', verifiedOnly: true),
  ),
];

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
const vibeOptions = ['Calm', 'Reflective', 'Social', 'Grounded', 'Structured', 'Curious', 'Creative', 'Playful'];
const bffInterestOptions = [
  'Reading', 'Coffee', 'Walking', 'Gym', 'Running', 'Coding',
  'Design', 'Startups', 'Gaming', 'Museums', 'Travel', 'Writing',
  'Language learning', 'Nature', 'Entrepreneurship',
];
const languageOptions = ['Turkish', 'English', 'Arabic', 'French', 'German', 'Spanish', 'Italian', 'Russian', 'Japanese', 'Persian'];
const statusBadgeOptions = ['All', 'Explorer+', 'Noble only'];
