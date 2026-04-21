import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/post_comment.dart';

class CommentsBundle {
  final List<PostComment> replies; // threaded: top-level + nested
  final List<PostComment> chains;  // flat, chronological Soul Chain links
  const CommentsBundle({required this.replies, required this.chains});
}

class CommentRepository {
  final SupabaseClient? _supabase;

  CommentRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Result of fetching a post's discussion: replies (threaded) + chains (flat).
  /// Chains and replies are siblings on the post — chains are a separate
  /// "Soul Chain" continuation track, replies are the normal back-and-forth.
  Future<CommentsBundle> fetchComments(String postId) async {
    if (isMockMode) return const CommentsBundle(replies: [], chains: []);
    final db = _supabase!;
    final rows = await db
        .from('post_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: true)
        .limit(200);

    if (rows.isEmpty) return const CommentsBundle(replies: [], chains: []);

    final userIds = rows.map((r) => r['user_id'] as String).toSet().toList();
    final profiles = await db
        .from('profiles')
        .select('id, display_name, date_avatar_url')
        .inFilter('id', userIds);
    final profileMap = {for (final p in profiles) p['id'] as String: p};

    final all = rows.map((r) {
      final uid = r['user_id'] as String;
      return PostComment.fromJson(r, profile: profileMap[uid]);
    }).toList();

    // Split chains from replies. Chains are flat (no nesting).
    final chains = all.where((c) => c.isChain).toList();

    // For replies: build top-level + nested. Ignore chain nodes here.
    final replyComments = all.where((c) => !c.isChain).toList();
    final topLevel = <PostComment>[];
    final repliesByParent = <String, List<PostComment>>{};
    for (final c in replyComments) {
      if (c.parentId == null) {
        topLevel.add(c);
      } else {
        repliesByParent.putIfAbsent(c.parentId!, () => []).add(c);
      }
    }

    final replies = topLevel
        .map((c) => PostComment(
              id: c.id,
              postId: c.postId,
              userId: c.userId,
              content: c.content,
              createdAt: c.createdAt,
              parentId: c.parentId,
              chainType: c.chainType,
              authorName: c.authorName,
              authorAvatarUrl: c.authorAvatarUrl,
              replies: repliesByParent[c.id] ?? const [],
            ))
        .toList();

    return CommentsBundle(replies: replies, chains: chains);
  }

  Future<PostComment?> addComment({
    required String postId,
    required String userId,
    required String content,
    String? parentId,
    String chainType = 'reply',
  }) async {
    if (isMockMode) return null;
    try {
      final data = <String, dynamic>{
        'post_id': postId,
        'user_id': userId,
        'content': content,
        'chain_type': chainType,
      };
      if (parentId != null) data['parent_id'] = parentId;
      final row = await _supabase!
          .from('post_comments')
          .insert(data)
          .select()
          .single();
      return PostComment.fromJson(row);
    } catch (e) {
      debugPrint('[comments] Add failed: $e');
      return null;
    }
  }

  Future<void> deleteComment(String commentId) async {
    if (isMockMode) return;
    await _supabase!.from('post_comments').delete().eq('id', commentId);
  }

  Future<({bool ok, String? error})> editComment({
    required String commentId,
    required String newContent,
  }) async {
    if (isMockMode) return (ok: true, error: null);
    try {
      final result = await _supabase!.rpc('edit_comment', params: {
        'p_comment_id': commentId,
        'p_new_content': newContent,
      });
      if (result is Map && result['error'] != null) {
        return (ok: false, error: result['message'] as String? ?? result['error'] as String);
      }
      return (ok: true, error: null);
    } catch (e) {
      debugPrint('[comments:edit] $e');
      return (ok: false, error: 'Could not edit comment.');
    }
  }

  /// Aggregate comment counts via fetch_comment_counts_batch RPC. Comments
  /// remain readable directly (`view_comments` RLS is open) but using the
  /// RPC keeps the count-only path consistent with reactions/echoes and
  /// avoids pulling N rows just to count them.
  Future<Map<String, int>> commentCountsBatch(List<String> postIds) async {
    if (isMockMode || postIds.isEmpty) return {};
    try {
      final rows = await _supabase!.rpc(
        'fetch_comment_counts_batch',
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
      debugPrint('[CommentRepository.commentCountsBatch] error: $e\n$st');
      return {};
    }
  }
}
