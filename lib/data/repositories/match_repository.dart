import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/match.dart';

class MatchRepository {
  final SupabaseClient? _supabase;

  MatchRepository({SupabaseClient? supabase}) : _supabase = supabase;

  Future<List<NobleMatch>> fetchMatches(String userId) async {
    if (isMockMode) return _mockMatches(userId);

    // Fetch matches where current user is user1 or user2
    final data = await _supabase!
        .from('matches')
        .select('''
          *,
          user1:profiles!matches_user1_id_fkey(display_name, date_avatar_url),
          user2:profiles!matches_user2_id_fkey(display_name, date_avatar_url)
        ''')
        .or('user1_id.eq.$userId,user2_id.eq.$userId')
        .neq('status', 'expired')
        .order('matched_at', ascending: false);

    return data.map<NobleMatch>((row) {
      final match = NobleMatch.fromJson(row);
      final isUser1 = row['user1_id'] == userId;
      final otherUser = isUser1
          ? row['user2'] as Map<String, dynamic>?
          : row['user1'] as Map<String, dynamic>?;
      final otherId = isUser1 ? row['user2_id'] as String : row['user1_id'] as String;

      return match.withOtherUser(
        userId: otherId,
        name: otherUser?['display_name'] as String? ?? 'User',
        photoUrl: otherUser?['date_avatar_url'] as String?,
      );
    }).toList();
  }

  Future<NobleMatch?> fetchMatch(String matchId) async {
    if (isMockMode) return null;
    final data = await _supabase!
        .from('matches')
        .select()
        .eq('id', matchId)
        .maybeSingle();
    if (data == null) return null;
    return NobleMatch.fromJson(data);
  }

  Future<void> updateStatus(String matchId, String status) async {
    if (isMockMode) return;
    await _supabase!
        .from('matches')
        .update({'status': status})
        .eq('id', matchId);
  }

  /// Lightweight expiry check used by the chat screen — reads only the two
  /// columns the caller needs, avoiding a full match fetch each time the
  /// chat is opened or a message is sent.
  Future<({String? status, String? chatExpiresAt})> fetchStatusAndExpiry(
    String matchId,
  ) async {
    if (isMockMode) return (status: null, chatExpiresAt: null);
    final row = await _supabase!
        .from('matches')
        .select('status, chat_expires_at')
        .eq('id', matchId)
        .maybeSingle();
    if (row == null) return (status: null, chatExpiresAt: null);
    return (
      status: row['status'] as String?,
      chatExpiresAt: row['chat_expires_at'] as String?,
    );
  }

  /// Subscribe to realtime UPDATE/INSERT/DELETE events on the `matches`
  /// table for [userId] (filtered server-side via two `onPostgresChanges`
  /// listeners — one for user1_id, one for user2_id). Returns the channel
  /// so the caller can unsubscribe via `RealtimeRepository.unsubscribe`.
  /// Returns null in mock mode (no realtime backend).
  RealtimeChannel? subscribeToMatches(
    String userId,
    void Function(Map<String, dynamic>) onChange,
  ) {
    if (isMockMode) return null;
    return _supabase!
        .channel('matches_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user1_id',
            value: userId,
          ),
          callback: (payload) => onChange(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user2_id',
            value: userId,
          ),
          callback: (payload) => onChange(payload.newRecord),
        )
        .subscribe();
  }

  List<NobleMatch> _mockMatches(String userId) {
    return [];
  }
}
