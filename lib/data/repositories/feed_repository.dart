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

    // Step 1: fetch entry-approved user IDs from gating_status
    late List<Map<String, dynamic>> gatingData;
    try {
      gatingData = await client
          .from('gating_status')
          .select('user_id')
          .eq('is_entry_approved', true);
    } catch (e) {
      rethrow;
    }
    final approvedIds = {for (final r in gatingData) r['user_id'] as String};
    final excluded = {userId, ...excludeIds};

    if (approvedIds.isEmpty) return [];

    final toFetch = approvedIds.difference(excluded);
    if (toFetch.isEmpty) return [];

    // Step 2: Build filtered query
    var query = client
        .from('profiles')
        .select()
        .eq('is_verified', true)
        .filter('active_modes', 'cs', '{"$mode"}')
        .inFilter('id', toFetch.toList());

    // ── Apply filters from FilterState ──
    if (filters != null) {
      // Age range
      if (filters.ageRange.start > 18) {
        query = query.gte('age', filters.ageRange.start.round());
      }
      if (filters.ageRange.end < 65) {
        query = query.lte('age', filters.ageRange.end.round());
      }

      // City / distance (text-based for now)
      // Note: geo-distance filtering would require PostGIS; use city match as proxy

      // Trust Shield: Verified + Complete + Explorer+
      if (filters.trustShieldEnabled) {
        query = query
            .eq('is_verified', true)
            .eq('is_onboarded', true)
            .inFilter('nob_tier', ['explorer', 'noble']);
      }

      // Verified only
      if (filters.verifiedOnly) {
        query = query.eq('is_verified', true);
      }

      // Complete profiles only
      if (filters.completeOnly) {
        query = query.eq('is_onboarded', true);
      }

      // Status badge filter
      if (filters.statusBadge == 'Explorer+') {
        query = query.inFilter('nob_tier', ['explorer', 'noble']);
      } else if (filters.statusBadge == 'Noble only') {
        query = query.eq('nob_tier', 'noble');
      }

      // Has Nob posts — can't filter in profiles query directly,
      // would need a subquery or post-filter. Skip for now.
    }

    // Step 3: Order by tier ranking + maturity score, execute
    late List<Map<String, dynamic>> data;
    try {
      data = await query
          .order('maturity_score', ascending: false)
          .limit(30);
    } catch (e) {
      rethrow;
    }

    final nobleMode = NobleMode.values
        .firstWhere((m) => m.name == mode, orElse: () => NobleMode.date);

    // Step 4: Client-side filtering for fields not in DB
    var results = data.map((row) => ProfileCard.fromDb(row, nobleMode)).toList();

    if (filters != null) {
      results = _applyClientFilters(results, filters, mode);
    }

    return results;
  }

  /// Client-side filtering for lifestyle/preference fields
  /// These would ideally be DB columns, but for now we filter post-fetch
  List<ProfileCard> _applyClientFilters(
    List<ProfileCard> cards,
    FilterState filters,
    String mode,
  ) {
    var result = cards;

    // Language filter
    if (filters.languages.isNotEmpty) {
      if (filters.isStrict('languages')) {
        result = result.where((c) =>
            c.languages.any((l) => filters.languages.contains(l))).toList();
      }
      // Preference: sort matching ones first
      else {
        result.sort((a, b) {
          final aMatch = a.languages.where((l) => filters.languages.contains(l)).length;
          final bMatch = b.languages.where((l) => filters.languages.contains(l)).length;
          return bMatch.compareTo(aMatch);
        });
      }
    }

    // Interest filter (BFF mode)
    if (filters.interests.isNotEmpty) {
      if (filters.isStrict('interests')) {
        result = result.where((c) =>
            c.interests.any((i) => filters.interests.contains(i))).toList();
      } else {
        result.sort((a, b) {
          final aMatch = a.interests.where((i) => filters.interests.contains(i)).length;
          final bMatch = b.interests.where((i) => filters.interests.contains(i)).length;
          return bMatch.compareTo(aMatch);
        });
      }
    }

    // 6+ photos filter
    if (filters.sixPlusPhotos) {
      // Can't check from ProfileCard — would need photos count in model
      // This is a known gap
    }

    return result;
  }
}
