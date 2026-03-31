import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/enums/noble_mode.dart';
import '../../data/models/filter_state.dart';
import '../models/profile_card.dart';

class FeedRepository {
  final SupabaseClient? _supabase;

  FeedRepository({SupabaseClient? supabase}) : _supabase = supabase;

  Future<List<ProfileCard>> fetchFeedProfiles({
    required String userId,
    required String mode,
    required Set<String> excludeIds,
    FilterState? filters,
  }) async {
    final client = _supabase!;

    // Step 1: approved users
    final gatingData = await client
        .from('gating_status')
        .select('user_id')
        .eq('is_entry_approved', true);

    final approvedIds = {for (final r in gatingData) r['user_id'] as String};
    final excluded = {userId, ...excludeIds};
    if (approvedIds.isEmpty) return [];
    final toFetch = approvedIds.difference(excluded);
    if (toFetch.isEmpty) return [];

    // Step 2: build filtered query
    var query = client
        .from('profiles')
        .select()
        .eq('is_verified', true)
        .eq('is_paused', false)
        .filter('active_modes', 'cs', '{"$mode"}')
        .inFilter('id', toFetch.toList());

    if (filters != null) {
      // Age
      if (filters.ageRange.start > 18) {
        query = query.gte('age', filters.ageRange.start.round());
      }
      if (filters.ageRange.end < 65) {
        query = query.lte('age', filters.ageRange.end.round());
      }

      // Trust Shield
      if (filters.trustShieldEnabled) {
        query = query
            .eq('is_onboarded', true)
            .inFilter('nob_tier', ['explorer', 'noble']);
      }

      // Verified / Complete
      if (filters.verifiedOnly) query = query.eq('is_verified', true);
      if (filters.completeOnly) query = query.eq('is_onboarded', true);

      // Tier badge
      if (filters.statusBadge == 'Explorer+') {
        query = query.inFilter('nob_tier', ['explorer', 'noble']);
      } else if (filters.statusBadge == 'Noble only') {
        query = query.eq('nob_tier', 'noble');
      }

      // Lifestyle DB filters (strict = hard filter, preference = sort later)
      if (filters.drinks != null && filters.isStrict('drinks')) {
        query = query.eq('drinks', filters.drinks!);
      }
      if (filters.smokes != null && filters.isStrict('smokes')) {
        query = query.eq('smokes', filters.smokes!);
      }
      if (filters.nightlife != null && filters.isStrict('nightlife')) {
        query = query.eq('nightlife', filters.nightlife!);
      }
      if (filters.socialEnergy != null && filters.isStrict('socialEnergy')) {
        query = query.eq('social_energy', filters.socialEnergy!);
      }
      if (filters.routine != null && filters.isStrict('routine')) {
        query = query.eq('routine', filters.routine!);
      }
      if (filters.faithSensitivity != null && filters.isStrict('faith')) {
        query = query.eq('faith_sensitivity', filters.faithSensitivity!);
      }

      // Looking for (dating)
      if (filters.lookingFor != null && filters.isStrict('lookingFor')) {
        query = query.eq('looking_for', filters.lookingFor!);
      }

      // BFF looking for
      if (filters.bffLookingFor != null && filters.isStrict('bffLookingFor')) {
        query = query.eq('bff_looking_for', filters.bffLookingFor!);
      }

      // Has Nob posts (6+ photos not checkable from profiles alone)
      if (filters.hasNobs) {
        query = query.gt('daily_nob_count', 0);
      }

      // Has prompts
      if (filters.hasPrompts) {
        query = query.gte('prompts_answered', 2);
      }
    }

    // Step 3: execute with ranking
    final data = await query
        .order('maturity_score', ascending: false)
        .limit(30);

    final nobleMode = NobleMode.values
        .firstWhere((m) => m.name == mode, orElse: () => NobleMode.date);

    var results = data.map((row) => ProfileCard.fromDb(row, nobleMode)).toList();

    // Step 4: client-side preference sorting (non-strict filters)
    if (filters != null) {
      results = _applyPreferenceSorting(results, filters);
    }

    return results;
  }

  /// Real oracle counter
  Future<int> countFilteredProfiles({
    required String userId,
    required String mode,
    FilterState? filters,
  }) async {
    final client = _supabase!;
    final result = await client.rpc('count_filtered_profiles', params: {
      'p_user_id': userId,
      'p_mode': mode,
      'p_age_min': filters?.ageRange.start.round() ?? 18,
      'p_age_max': filters?.ageRange.end.round() ?? 65,
      'p_verified_only': filters?.verifiedOnly ?? false,
      'p_complete_only': filters?.completeOnly ?? false,
      'p_tier_filter': filters?.statusBadge == 'Noble only'
          ? 'noble'
          : filters?.statusBadge == 'Explorer+'
              ? null
              : null,
    });
    return (result as int?) ?? 0;
  }

  List<ProfileCard> _applyPreferenceSorting(
    List<ProfileCard> cards,
    FilterState filters,
  ) {
    if (cards.isEmpty) return cards;

    // Score each card by preference match count
    int score(ProfileCard c) {
      int s = 0;
      if (filters.languages.isNotEmpty &&
          c.languages.any((l) => filters.languages.contains(l))) {
        s += 2;
      }
      if (filters.interests.isNotEmpty &&
          c.interests.any((i) => filters.interests.contains(i))) {
        s += 2;
      }
      return s;
    }

    cards.sort((a, b) => score(b).compareTo(score(a)));
    return cards;
  }
}
