import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';

class EchoRepository {
  final SupabaseClient? _supabase;

  EchoRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Echo a post (anonymous repost). Returns true on success, false otherwise.
  Future<bool> echo({required String postId, required String userId, String? comment}) async {
    if (isMockMode) return true;
    try {
      await _supabase!.from('post_echoes').insert({
        'post_id': postId,
        'user_id': userId,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });
      return true;
    } catch (e) {
      debugPrint('[echo] Insert failed: $e');
      return false;
    }
  }

  Future<bool> unecho({required String postId, required String userId}) async {
    if (isMockMode) return true;
    try {
      await _supabase!
          .from('post_echoes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('[echo] Delete failed: $e');
      return false;
    }
  }

  Future<bool> hasEchoed({required String postId, required String userId}) async {
    if (isMockMode) return false;
    try {
      final row = await _supabase!
          .from('post_echoes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();
      return row != null;
    } catch (e, st) {
      debugPrint('[EchoRepository.hasEchoed] error: $e\n$st');
      return false;
    }
  }

  /// Batch fetch echo counts for multiple posts.
  /// Uses fetch_echo_counts_batch SECURITY DEFINER RPC so the per-row user_id
  /// stays server-side under the tightened echoes_select_own RLS policy.
  Future<Map<String, int>> echoCountsBatch(List<String> postIds) async {
    if (isMockMode || postIds.isEmpty) return {};
    try {
      final rows = await _supabase!.rpc(
        'fetch_echo_counts_batch',
        params: {'p_post_ids': postIds},
      );
      if (rows is! List) return {};
      final counts = <String, int>{};
      for (final r in rows) {
        final pid = r['post_id'] as String;
        counts[pid] = (r['cnt'] as num).toInt();
      }
      return counts;
    } catch (e, st) {
      debugPrint('[EchoRepository.echoCountsBatch] error: $e\n$st');
      return {};
    }
  }

  /// Batch fetch which of the given posts the user has echoed.
  Future<Set<String>> userEchoedPostIds({required String userId, required List<String> postIds}) async {
    if (isMockMode || postIds.isEmpty) return {};
    try {
      final rows = await _supabase!
          .from('post_echoes')
          .select('post_id')
          .eq('user_id', userId)
          .inFilter('post_id', postIds);
      return rows.map((r) => r['post_id'] as String).toSet();
    } catch (e, st) {
      debugPrint('[EchoRepository.userEchoedPostIds] error: $e\n$st');
      return {};
    }
  }
}
