import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';

/// Aggregation reads for the Status surface: parallel counts for the
/// dashboard cards (status_screen) and sequential profile + activity
/// snapshot for the StatusData notifier (status_provider). Returns raw
/// rows / counts so callers keep their own DTO mapping.
class StatusRepository {
  final SupabaseClient? _supabase;

  StatusRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// 6 parallel queries for the dashboard counters + recent activity feed.
  /// Mirrors the previous `Future.wait([...])` block at status_screen:66-75.
  Future<({
    int notesReceived,
    int notesSent,
    int signalsReceived,
    int signalsSent,
    int connectionCount,
    List<Map<String, dynamic>> recentActivity,
  })> fetchStatusCounts(String userId) async {
    if (isMockMode) {
      return (
        notesReceived: 0,
        notesSent: 0,
        signalsReceived: 0,
        signalsSent: 0,
        connectionCount: 0,
        recentActivity: const <Map<String, dynamic>>[],
      );
    }
    final c = _supabase!;
    final results = await Future.wait([
      c.from('notes').select('id').eq('receiver_id', userId),
      c.from('notes').select('id').eq('sender_id', userId),
      c.from('signals').select('id').eq('receiver_id', userId),
      c.from('signals').select('id').eq('sender_id', userId),
      c
          .from('matches')
          .select('id')
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .neq('status', 'expired')
          .neq('status', 'closed'),
      c
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20),
    ]);
    return (
      notesReceived: (results[0] as List).length,
      notesSent: (results[1] as List).length,
      signalsReceived: (results[2] as List).length,
      signalsSent: (results[3] as List).length,
      connectionCount: (results[4] as List).length,
      recentActivity: List<Map<String, dynamic>>.from(
        (results[5] as List).map((r) => Map<String, dynamic>.from(r as Map)),
      ),
    );
  }

  /// 4 sequential queries (post_reactions depends on prior post-id list).
  /// Returns raw profile row + counts; caller parses fields and maps to
  /// `StatusData`. Mirrors status_provider:163-201.
  Future<({
    Map<String, dynamic>? profileRow,
    int matchCount,
    int myPostsCount,
    int reactionCount,
  })> fetchStatusData(String userId) async {
    if (isMockMode) {
      return (
        profileRow: null,
        matchCount: 0,
        myPostsCount: 0,
        reactionCount: 0,
      );
    }
    final c = _supabase!;

    final profileRow = await c
        .from('profiles')
        .select('profile_views, is_noble, super_likes_remaining, rewinds_remaining, boost_active_until')
        .eq('id', userId)
        .maybeSingle();

    final matchRows = await c
        .from('matches')
        .select('id')
        .or('user1_id.eq.$userId,user2_id.eq.$userId');

    final myPosts = await c
        .from('posts')
        .select('id')
        .eq('user_id', userId);
    final postIds = myPosts.map((r) => r['id'] as String).toList();

    int reactionCount = 0;
    if (postIds.isNotEmpty) {
      final reactions = await c
          .from('post_reactions')
          .select('id')
          .inFilter('post_id', postIds);
      reactionCount = reactions.length;
    }

    return (
      profileRow: profileRow,
      matchCount: matchRows.length,
      myPostsCount: myPosts.length,
      reactionCount: reactionCount,
    );
  }
}
