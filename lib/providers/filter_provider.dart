import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/filter_state.dart';

const _prefsKeyBase = 'noblara_filter_state';

class FilterNotifier extends StateNotifier<FilterState> {
  String? _userId;

  FilterNotifier() : super(const FilterState()) {
    _load();
  }

  String get _prefsKey => _userId != null ? '${_prefsKeyBase}_$_userId' : _prefsKeyBase;

  void setUserId(String? uid) {
    if (_userId == uid) return;
    _userId = uid;
    _load();
  }

  void set(FilterState newState) {
    state = newState;
    _save();
  }

  void update(FilterState Function(FilterState) updater) {
    state = updater(state);
    _save();
  }

  void reset() {
    state = const FilterState();
    _save();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json == null) return;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      state = FilterState(
        ageRange: RangeValues(
          (map['ageMin'] as num?)?.toDouble() ?? 18,
          (map['ageMax'] as num?)?.toDouble() ?? 45,
        ),
        maxDistance: (map['maxDistance'] as num?)?.toDouble() ?? 25,
        trustShieldEnabled: map['trustShield'] as bool? ?? false,
        hasNobs: map['hasNobs'] as bool? ?? false,
        hasPrompts: map['hasPrompts'] as bool? ?? false,
        sixPlusPhotos: map['sixPlusPhotos'] as bool? ?? false,
        pinnedNobExists: map['pinnedNobExists'] as bool? ?? false,
        sameCityOnly: map['sameCityOnly'] as bool? ?? false,
        lookingFor: map['lookingFor'] as String?,
        drinks: map['drinks'] as String?,
        smokes: map['smokes'] as String?,
        nightlife: map['nightlife'] as String?,
        socialEnergy: map['socialEnergy'] as String?,
        routine: map['routine'] as String?,
        faithSensitivity: map['faith'] as String?,
        statusBadge: map['statusBadge'] as String?,
        bffLookingFor: map['bffLookingFor'] as String?,
        languages: (map['languages'] as List<dynamic>?)?.cast<String>() ?? [],
        interests: (map['interests'] as List<dynamic>?)?.cast<String>() ?? [],
      );
    } catch (e) { debugPrint('[filters] Load from prefs failed: $e'); }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final map = {
      'ageMin': state.ageRange.start,
      'ageMax': state.ageRange.end,
      'maxDistance': state.maxDistance,
      'trustShield': state.trustShieldEnabled,
      'hasNobs': state.hasNobs,
      'hasPrompts': state.hasPrompts,
      'sixPlusPhotos': state.sixPlusPhotos,
      'pinnedNobExists': state.pinnedNobExists,
      'sameCityOnly': state.sameCityOnly,
      'lookingFor': state.lookingFor,
      'drinks': state.drinks,
      'smokes': state.smokes,
      'nightlife': state.nightlife,
      'socialEnergy': state.socialEnergy,
      'faith': state.faithSensitivity,
      'routine': state.routine,
      'statusBadge': state.statusBadge,
      'bffLookingFor': state.bffLookingFor,
      'languages': state.languages,
      'interests': state.interests,
    };
    await prefs.setString(_prefsKey, jsonEncode(map));
  }
}

final filterProvider =
    StateNotifierProvider<FilterNotifier, FilterState>((ref) {
  return FilterNotifier();
});
