import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/enums/noble_mode.dart';
import '../models/profile_card.dart';

class FeedRepository {
  final SupabaseClient? _supabase;

  FeedRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Fetches verified + entry-approved profiles for the feed:
  ///  - is_verified = true
  ///  - gating_status.is_entry_approved = true
  ///  - active mode matches
  ///  - excludes current user + already-swiped profiles
  ///  - max 30 cards
  Future<List<ProfileCard>> fetchFeedProfiles({
    required String userId,
    required String mode,
    required Set<String> excludeIds,
  }) async {
    final client = _supabase!;

    // Step 1: fetch entry-approved user IDs from gating_status
    // ignore: avoid_print
    print('[FeedRepo] fetchFeedProfiles — userId=$userId mode=$mode excludeIds=${excludeIds.length}');

    late List<Map<String, dynamic>> gatingData;
    try {
      gatingData = await client
          .from('gating_status')
          .select('user_id')
          .eq('is_entry_approved', true);
      // ignore: avoid_print
      print('[FeedRepo] gating_status rows returned: ${gatingData.length} — $gatingData');
    } catch (e) {
      // ignore: avoid_print
      print('[FeedRepo] ERROR querying gating_status: $e');
      rethrow;
    }
    final approvedIds =
        {for (final r in gatingData) r['user_id'] as String};

    // Build full exclusion set: self + swiped + not approved
    final excluded = {userId, ...excludeIds};
    // ignore: avoid_print
    print('[FeedRepo] approvedIds=${approvedIds.length} excluded=${excluded.length}');

    if (approvedIds.isEmpty) {
      // ignore: avoid_print
      print('[FeedRepo] EARLY RETURN — no entry-approved users in gating_status');
      return [];
    }

    final toFetch = approvedIds.difference(excluded);
    // ignore: avoid_print
    print('[FeedRepo] toFetch=${toFetch.length} ids=$toFetch');

    if (toFetch.isEmpty) {
      // ignore: avoid_print
      print('[FeedRepo] EARLY RETURN — toFetch is empty after exclusions');
      return [];
    }

    late List<Map<String, dynamic>> data;
    try {
      // ignore: avoid_print
      print('[FeedRepo] profiles query — is_verified=true current_mode=$mode inFilter(id, $toFetch)');
      data = await client
          .from('profiles')
          .select()
          .eq('is_verified', true)
          .eq('current_mode', mode)
          .filter('active_modes', 'cs', '{"$mode"}')
          .inFilter('id', toFetch.toList())
          .limit(30);
      // ignore: avoid_print
      print('[FeedRepo] profiles rows returned: ${data.length} — $data');
    } catch (e) {
      // ignore: avoid_print
      print('[FeedRepo] ERROR querying profiles: $e');
      rethrow;
    }

    final nobleMode = NobleMode.values
        .firstWhere((m) => m.name == mode, orElse: () => NobleMode.date);
    return data.map((row) => ProfileCard.fromDb(row, nobleMode)).toList();
  }
}
