import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/match.dart';

class SwipeRepository {
  final SupabaseClient? _supabase;

  SwipeRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Records a swipe and returns a NobleMatch if it created a mutual match.
  Future<NobleMatch?> swipe({
    required String swiperId,
    required String targetId,
    required String direction, // 'right' | 'left' | 'super'
    required String mode,
  }) async {
    if (isMockMode) {
      // In mock mode, every right-swipe creates an instant connection
      if (direction == 'right' || direction == 'super') {
        return NobleMatch(
          id: 'mock-match-${DateTime.now().millisecondsSinceEpoch}',
          user1Id: swiperId,
          user2Id: targetId,
          mode: mode,
          status: 'pending_intro',
          matchedAt: DateTime.now(),
          videoDeadlineAt: DateTime.now().add(const Duration(hours: 24)),
        );
      }
      return null;
    }

    // Increment swipe counter (server-side limit check happens in feed)
    await _supabase!.rpc('increment_swipe_count', params: {'p_user_id': swiperId});

    // Insert swipe record
    await _supabase.from('swipes').upsert({
      'swiper_id': swiperId,
      'swiped_id': targetId,
      'direction': direction,
      'mode': mode,
    });

    if (direction == 'left') return null;

    // Call DB function to check for mutual match
    final result = await _supabase.rpc('check_and_create_match', params: {
      'p_swiper': swiperId,
      'p_target': targetId,
      'p_mode': mode,
    });

    if (result == null) return null;
    try {
      return NobleMatch.fromJson(result as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Fetch all users this user has already swiped (to exclude from feed)
  Future<Set<String>> fetchSwipedIds(String userId, String mode) async {
    if (isMockMode) return {};
    try {
      final data = await _supabase!
          .from('swipes')
          .select('swiped_id')
          .eq('swiper_id', userId)
          .eq('mode', mode);
      return {for (final row in data) row['swiped_id'] as String};
    } catch (e) {
      // ignore: avoid_print
      print('[SwipeRepo] fetchSwipedIds failed (schema mismatch?): $e');
      return {};
    }
  }
}
