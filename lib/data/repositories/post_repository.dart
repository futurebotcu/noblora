import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/post.dart';
import '../models/post_revision.dart';

class PostRepository {
  final SupabaseClient? _supabase;

  PostRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Fetch posts for a specific lane (all/near_you/country/echoes/mood)
  Future<List<Post>> fetchLane({
    required String lane,
    String? mood,
    int limit = 30,
    int offset = 0,
    String? userId,
  }) async {
    if (isMockMode) return _mockPosts();

    if (userId != null) {
      final rows = await _supabase!.rpc('fetch_nob_lane', params: {
        'p_user_id': userId,
        'p_lane': lane,
        'p_mood': mood,
        'p_limit': limit,
        'p_offset': offset,
      });
      if (rows is List) {
        return _enrichWithProfiles(List<Map<String, dynamic>>.from(rows));
      }
      return [];
    }

    // Anonymous fallback
    final rows = await _supabase!
        .from('posts')
        .select()
        .eq('is_draft', false)
        .eq('is_archived', false)
        .order('quality_score', ascending: false)
        .order('published_at', ascending: false)
        .range(offset, offset + limit - 1);
    return _enrichWithProfiles(rows);
  }

  /// Fetch a single post by id, with anonymity masking applied server-side.
  /// Used by the realtime fan-out path when a feed_events row arrives.
  Future<Post?> fetchPostById(String postId, {String? userId}) async {
    if (isMockMode) return null;
    try {
      final rows = await _supabase!.rpc(
        'fetch_post_by_id',
        params: {
          'p_post_id': postId,
          'p_user_id':
              userId ?? '00000000-0000-0000-0000-000000000000',
        },
      );
      if (rows is! List || rows.isEmpty) return null;
      final list = await _enrichWithProfiles(
        List<Map<String, dynamic>>.from(rows),
      );
      return list.isEmpty ? null : list.first;
    } catch (e, st) {
      debugPrint('[PostRepository.fetchPostById] error: $e\n$st');
      return null;
    }
  }

  /// Refresh reaction + echo + comment counts for a single post id.
  Future<({Map<String, int> reactions, int echo, int comment})>
      fetchAggregateCountsFor(String postId) async {
    if (isMockMode) {
      return (reactions: <String, int>{}, echo: 0, comment: 0);
    }
    try {
      final reactionsFuture = _supabase!.rpc(
        'fetch_reaction_counts_batch',
        params: {'p_post_ids': [postId]},
      );
      final echoFuture = _supabase.rpc(
        'fetch_echo_counts_batch',
        params: {'p_post_ids': [postId]},
      );
      final commentFuture = _supabase.rpc(
        'fetch_comment_counts_batch',
        params: {'p_post_ids': [postId]},
      );
      final results = await Future.wait([reactionsFuture, echoFuture, commentFuture]);
      final reactionRows = results[0] as List? ?? const [];
      final echoRows = results[1] as List? ?? const [];
      final commentRows = results[2] as List? ?? const [];
      final reactionMap = <String, int>{};
      for (final r in reactionRows) {
        reactionMap[r['reaction_type'] as String] =
            (r['cnt'] as num).toInt();
      }
      final echoCount = echoRows.isEmpty ? 0 : (echoRows.first['cnt'] as num).toInt();
      final commentCount =
          commentRows.isEmpty ? 0 : (commentRows.first['cnt'] as num).toInt();
      return (reactions: reactionMap, echo: echoCount, comment: commentCount);
    } catch (e, st) {
      debugPrint('[PostRepository.fetchAggregateCountsFor] error: $e\n$st');
      return (reactions: <String, int>{}, echo: 0, comment: 0);
    }
  }

  /// Discover dynamic mood lanes from recent posts
  Future<List<String>> discoverDynamicMoodLanes({int limit = 2}) async {
    if (isMockMode) return [];
    try {
      final rows = await _supabase!.rpc('discover_mood_lanes', params: {'p_limit': limit});
      if (rows is List) {
        return rows.map((r) => r['mood'] as String).toList();
      }
      return [];
    } catch (e, st) {
      debugPrint('[PostRepository.discoverDynamicMoodLanes] error: $e\n$st');
      return [];
    }
  }

  /// Get reaction counts for author's own posts
  Future<Map<String, int>> getOwnReactionCounts(String postId, String authorId) async {
    if (isMockMode) return {};
    final result = await _supabase!.rpc('get_own_reaction_counts', params: {
      'p_post_id': postId,
      'p_author_id': authorId,
    });
    if (result is Map) {
      return {
        'appreciate': (result['appreciate'] as num?)?.toInt() ?? 0,
        'support': (result['support'] as num?)?.toInt() ?? 0,
        'pass': (result['pass'] as num?)?.toInt() ?? 0,
        'total': (result['total'] as num?)?.toInt() ?? 0,
      };
    }
    return {};
  }

  /// Batch version — single RPC instead of N+1 loop
  Future<Map<String, Map<String, int>>> getOwnReactionCountsBatch(
      List<String> postIds, String authorId) async {
    if (isMockMode || postIds.isEmpty) return {};
    try {
      final result = await _supabase!.rpc('get_own_reaction_counts_batch', params: {
        'p_post_ids': postIds,
        'p_author_id': authorId,
      });
      final map = <String, Map<String, int>>{};
      if (result is List) {
        for (final row in result) {
          map[row['post_id'] as String] = {
            'appreciate': (row['appreciate'] as num?)?.toInt() ?? 0,
            'support': (row['support'] as num?)?.toInt() ?? 0,
            'pass': (row['pass'] as num?)?.toInt() ?? 0,
            'total': (row['total'] as num?)?.toInt() ?? 0,
          };
        }
      }
      return map;
    } catch (e, st) {
      debugPrint('[PostRepository.getOwnReactionCountsBatch] error: $e\n$st');
      return {};
    }
  }

  /// Trigger quality score computation via edge function.
  /// The function needs the full content to score, not just the id.
  ///
  /// The fire-and-forget pattern is intentional — feed UX must not block on
  /// Gemini latency — but we DO inspect the response body so a non-throwing
  /// fallback (`ai_status` ≠ "ok") still surfaces in client logs. Without
  /// this the function could 200 + populate defaults forever and we'd never
  /// notice from the client side.
  Future<void> computeQualityScore({
    required String postId,
    required String content,
    required String nobType,
  }) async {
    if (isMockMode) return;
    try {
      final res = await _supabase!.functions.invoke('nob-quality-check', body: {
        'post_id': postId,
        'content': content,
        'nob_type': nobType,
      });
      final data = res.data;
      if (data is Map && data['ai_status'] != null && data['ai_status'] != 'ok') {
        debugPrint(
          '[nob-quality-check] $postId fell back: '
          'ai_status=${data['ai_status']} ai_error=${data['ai_error']}',
        );
      }
    } catch (e) {
      debugPrint('[nob-quality-check] AI scoring failed for $postId: $e');
    }
  }

  Future<List<Post>> fetchLastNobs(String userId, {int limit = 3}) async {
    if (isMockMode) return [];
    final rows = await _supabase!
        .from('posts')
        .select()
        .eq('user_id', userId)
        .eq('is_draft', false)
        .eq('is_archived', false)
        .order('published_at', ascending: false)
        .limit(limit);
    return rows.map((r) => Post.fromJson(r)).toList();
  }

  Future<Post> createPost({
    required String userId,
    required String content,
    required String nobType,
    String? photoUrl,
    String? caption,
    bool isDraft = false,
    bool isAnonymous = false,
    DateTime? revisitAt,
  }) async {
    if (isMockMode) {
      return Post(
        id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        content: content,
        nobType: nobType,
        photoUrl: photoUrl,
        caption: caption,
        isDraft: isDraft,
        publishedAt: isDraft ? null : DateTime.now(),
        createdAt: DateTime.now(),
        authorName: 'You',
        isAnonymous: isAnonymous,
      );
    }
    final data = <String, dynamic>{
      'user_id': userId,
      'content': content,
      'nob_type': nobType,
      'is_draft': isDraft,
      'is_anonymous': isAnonymous,
    };
    if (photoUrl != null) data['photo_url'] = photoUrl;
    if (caption != null) data['caption'] = caption;
    if (!isDraft) data['published_at'] = DateTime.now().toIso8601String();
    if (revisitAt != null) {
      data['is_future_nob'] = true;
      data['revisit_at'] = revisitAt.toIso8601String();
      data['future_nob_status'] = 'waiting';
    }
    final row = await _supabase!.from('posts').insert(data).select().single();
    return Post.fromJson(row);
  }

  Future<void> deletePost(String postId) async {
    if (isMockMode) return;
    await _supabase!.from('posts').delete().eq('id', postId);
  }

  // ── Second Thought / Edit ─────────────────────────────────────────

  Future<({bool ok, String? error})> performMinorEdit({
    required String postId,
    required String newContent,
    String? newCaption,
  }) async {
    if (isMockMode) return (ok: true, error: null);
    final result = await _supabase!.rpc('perform_minor_edit', params: {
      'p_post_id': postId,
      'p_new_content': newContent,
      if (newCaption != null) 'p_new_caption': newCaption,
    });
    if (result is Map && result['error'] != null) {
      return (ok: false, error: result['message'] as String? ?? result['error'] as String);
    }
    return (ok: true, error: null);
  }

  Future<({bool ok, String? error})> performSecondThought({
    required String postId,
    required String newContent,
    String? newCaption,
    String? reason,
  }) async {
    if (isMockMode) return (ok: true, error: null);
    final result = await _supabase!.rpc('perform_second_thought', params: {
      'p_post_id': postId,
      'p_new_content': newContent,
      if (newCaption != null) 'p_new_caption': newCaption,
      if (reason != null) 'p_reason': reason,
    });
    if (result is Map && result['error'] != null) {
      return (ok: false, error: result['message'] as String? ?? result['error'] as String);
    }
    return (ok: true, error: null);
  }

  Future<List<PostRevision>> fetchRevisions(String postId) async {
    if (isMockMode) return const [];
    final rows = await _supabase!
        .from('post_revisions')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    return rows.map((r) => PostRevision.fromJson(r)).toList();
  }

  Future<bool> canPublishToday(String userId, String nobType) async {
    if (isMockMode) return true;
    try {
      final result = await _supabase!.rpc('check_nob_limit',
          params: {'p_user_id': userId, 'p_type': nobType});
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('[canPublishToday] RPC failed: $e');
      // Rethrow so the caller can show a connection-error message instead
      // of silently allowing unlimited publishes. Server-side RLS still
      // enforces limits, but the UX is clearer when we surface the failure.
      rethrow;
    }
  }

  Future<void> react({
    required String postId,
    required String userId,
    required String reactionType,
  }) async {
    if (isMockMode) return;
    await _supabase!.from('post_reactions').upsert({
      'post_id': postId,
      'user_id': userId,
      'reaction_type': reactionType,
    });
  }

  Future<void> removeReaction({required String postId, required String userId}) async {
    if (isMockMode) return;
    await _supabase!.from('post_reactions')
        .delete().eq('post_id', postId).eq('user_id', userId);
  }

  Future<List<Post>> _enrichWithProfiles(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return [];
    // user_id is null for anonymous posts owned by someone else (server-masked).
    final userIds = rows
        .map((r) => r['user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final postIds = rows.map((r) => r['id'] as String).toList();

    // Parallelize profile lookup + aggregated reaction-counts RPC. Reactions
    // are fetched as anonymized counts (no user identity); the current user's
    // own reaction list is fetched separately by the provider via own-row RLS.
    final profilesFuture = userIds.isEmpty
        ? Future.value(const <Map<String, dynamic>>[])
        : _supabase!
            .from('profiles')
            .select('id, display_name, date_avatar_url, nob_tier')
            .inFilter('id', userIds);
    final countsFuture = _supabase!
        .rpc('fetch_reaction_counts_batch', params: {'p_post_ids': postIds});

    final profiles = await profilesFuture;
    final countsRows = (await countsFuture) as List? ?? const [];

    final profileMap = <String, Map<String, dynamic>>{
      for (final p in profiles) p['id'] as String: Map<String, dynamic>.from(p)
    };
    // post_id → { reaction_type → count }
    final reactionCountsByPost = <String, Map<String, int>>{};
    for (final r in countsRows) {
      final pid = r['post_id'] as String;
      final type = r['reaction_type'] as String;
      final cnt = (r['cnt'] as num).toInt();
      reactionCountsByPost
          .putIfAbsent(pid, () => <String, int>{})[type] = cnt;
    }

    return rows.map((r) {
      final uid = r['user_id'] as String?;
      final post = Post.fromJson(
        r,
        profile: uid != null ? profileMap[uid] : null,
      );
      return post.copyWith(
        reactionCounts: reactionCountsByPost[post.id] ?? const {},
      );
    }).toList();
  }

  List<Post> _mockPosts() => [
        Post(
          id: 'mock-1',
          userId: 'mock-user-1',
          content: 'Quietness is underrated.',
          nobType: 'thought',
          qualityScore: 0.9,
          isPinned: true,
          publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          authorName: 'Alexandra',
          authorTier: NobTier.noble,
        ),
        Post(
          id: 'mock-2',
          userId: 'mock-user-2',
          content: 'Something I noticed today that changed how I see things.',
          nobType: 'thought',
          qualityScore: 0.75,
          publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          authorName: 'Mehmet',
          authorTier: NobTier.explorer,
        ),
        Post(
          id: 'mock-3',
          userId: 'mock-user-3',
          content: '',
          nobType: 'moment',
          caption: 'A quiet morning.',
          qualityScore: 0.8,
          publishedAt: DateTime.now().subtract(const Duration(days: 1)),
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          authorName: 'Zeynep',
          authorTier: NobTier.noble,
        ),
      ];
}
