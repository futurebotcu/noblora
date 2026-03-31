import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';
import '../models/post.dart';

class PostRepository {
  final SupabaseClient? _supabase;

  PostRepository({SupabaseClient? supabase}) : _supabase = supabase;

  Future<List<Post>> fetchFeed({int limit = 50}) async {
    if (isMockMode) return _mockPosts();
    final rows = await _supabase!
        .from('posts')
        .select()
        .eq('is_draft', false)
        .eq('is_archived', false)
        .order('is_pinned', ascending: false)
        .order('quality_score', ascending: false)
        .order('published_at', ascending: false)
        .limit(limit);
    return _enrichWithProfiles(rows);
  }

  Future<List<Post>> fetchDrafts(String userId) async {
    if (isMockMode) return [];
    final rows = await _supabase!
        .from('posts')
        .select()
        .eq('user_id', userId)
        .eq('is_draft', true)
        .eq('is_archived', false)
        .order('created_at', ascending: false);
    return rows.map((r) => Post.fromJson(r)).toList();
  }

  Future<List<Post>> fetchLastNobs(String userId, {int limit = 3}) async {
    if (isMockMode) return [];
    final rows = await _supabase!
        .from('posts')
        .select()
        .eq('user_id', userId)
        .eq('is_draft', false)
        .eq('is_archived', false)
        .order('is_pinned', ascending: false)
        .order('published_at', ascending: false)
        .limit(limit);
    return rows.map((r) => Post.fromJson(r)).toList();
  }

  Future<List<Post>> fetchArchived(String userId) async {
    if (isMockMode) return [];
    final rows = await _supabase!
        .from('posts')
        .select()
        .eq('user_id', userId)
        .eq('is_archived', true)
        .order('created_at', ascending: false);
    return rows.map((r) => Post.fromJson(r)).toList();
  }

  Future<Post> createPost({
    required String userId,
    required String content,
    required String nobType,
    String? photoUrl,
    String? caption,
    bool isDraft = true,
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
      );
    }
    final data = <String, dynamic>{
      'user_id': userId,
      'content': content,
      'nob_type': nobType,
      'is_draft': isDraft,
    };
    if (photoUrl != null) data['photo_url'] = photoUrl;
    if (caption != null) data['caption'] = caption;
    if (!isDraft) data['published_at'] = DateTime.now().toIso8601String();
    final row = await _supabase!.from('posts').insert(data).select().single();
    return Post.fromJson(row);
  }

  Future<Post?> publishDraft(String postId) async {
    if (isMockMode) return null;
    final row = await _supabase!
        .from('posts')
        .update({'is_draft': false, 'published_at': DateTime.now().toIso8601String()})
        .eq('id', postId)
        .select()
        .single();
    return Post.fromJson(row);
  }

  Future<Post?> updateDraft({
    required String postId,
    required String content,
    String? photoUrl,
    String? caption,
  }) async {
    if (isMockMode) return null;
    final data = <String, dynamic>{'content': content};
    if (photoUrl != null) data['photo_url'] = photoUrl;
    if (caption != null) data['caption'] = caption;
    final row = await _supabase!
        .from('posts').update(data).eq('id', postId).select().single();
    return Post.fromJson(row);
  }

  Future<void> togglePin(String postId, String userId, bool pin) async {
    if (isMockMode) return;
    await _supabase!.from('posts').update({'is_pinned': false}).eq('user_id', userId);
    if (pin) {
      await _supabase.from('posts').update({'is_pinned': true}).eq('id', postId);
    }
  }

  Future<void> archivePost(String postId) async {
    if (isMockMode) return;
    await _supabase!.from('posts')
        .update({'is_archived': true, 'is_pinned': false}).eq('id', postId);
  }

  Future<void> unarchivePost(String postId) async {
    if (isMockMode) return;
    await _supabase!.from('posts').update({'is_archived': false}).eq('id', postId);
  }

  Future<void> deletePost(String postId) async {
    if (isMockMode) return;
    await _supabase!.from('posts').delete().eq('id', postId);
  }

  Future<bool> canPublishToday(String userId, String nobType) async {
    if (isMockMode) return true;
    try {
      final result = await _supabase!.rpc('check_nob_limit',
          params: {'p_user_id': userId, 'p_type': nobType});
      return result as bool? ?? false;
    } catch (_) {
      return false;
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

  Stream<List<Post>> feedStream() {
    if (isMockMode) return Stream.value(_mockPosts());
    return _supabase!
        .from('posts')
        .stream(primaryKey: ['id'])
        .eq('is_draft', false)
        .order('quality_score', ascending: false)
        .limit(50)
        .asyncMap((rows) async {
          final published = rows.where((r) => r['is_archived'] == false).toList();
          return _enrichWithProfiles(published);
        });
  }

  Future<List<Post>> _enrichWithProfiles(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return [];
    final userIds = rows.map((r) => r['user_id'] as String).toSet().toList();
    final profiles = await _supabase!
        .from('profiles')
        .select('id, display_name, date_avatar_url, nob_tier')
        .inFilter('id', userIds);
    final profileMap = {
      for (final p in profiles) p['id'] as String: p
    };
    final posts = rows
        .map((r) => Post.fromJson(r, profile: profileMap[r['user_id'] as String]))
        .toList();
    if (posts.isEmpty) return posts;
    final postIds = posts.map((p) => p.id).toList();
    final reactionRows =
        await _supabase.from('post_reactions').select().inFilter('post_id', postIds);
    final reactionsByPost = <String, List<PostReaction>>{};
    for (final r in reactionRows) {
      final reaction = PostReaction.fromJson(r);
      reactionsByPost.putIfAbsent(reaction.postId, () => []).add(reaction);
    }
    return posts
        .map((p) => p.copyWith(reactions: reactionsByPost[p.id] ?? []))
        .toList();
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
