import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/mini_intro.dart';

class MiniIntroRepository {
  final SupabaseClient? _supabase;

  MiniIntroRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Send a mini intro message for a connection.
  Future<MiniIntro> sendIntro({
    required String matchId,
    required String senderId,
    required String message,
  }) async {
    if (isMockMode) {
      return MiniIntro(
        id: 'mock-intro-${DateTime.now().millisecondsSinceEpoch}',
        matchId: matchId,
        senderId: senderId,
        message: message,
        createdAt: DateTime.now(),
      );
    }

    final data = await _supabase!.from('mini_intros').upsert({
      'match_id': matchId,
      'sender_id': senderId,
      'message': message,
    }).select().single();

    return MiniIntro.fromJson(data);
  }

  /// Fetch intros for a match (both users' intros).
  Future<List<MiniIntro>> fetchForMatch(String matchId) async {
    if (isMockMode) return [];

    final rows = await _supabase!
        .from('mini_intros')
        .select()
        .eq('match_id', matchId)
        .order('created_at');

    return rows.map((r) => MiniIntro.fromJson(r)).toList();
  }

  /// Realtime stream for intros on a match.
  Stream<List<MiniIntro>> watchForMatch(String matchId) {
    if (isMockMode) return const Stream.empty();
    return _supabase!
        .from('mini_intros')
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .order('created_at')
        .map((rows) => rows.map((r) => MiniIntro.fromJson(r)).toList());
  }

  /// Advance match from pending_intro to pending_video (authorized + state-checked).
  Future<void> advanceToVideo(String matchId, String userId) async {
    if (isMockMode) return;
    await _supabase!.rpc('safe_advance_to_video', params: {
      'p_match_id': matchId,
      'p_user_id': userId,
    });
  }
}
