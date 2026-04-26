import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';
import '../data/models/post.dart';
import '../data/repositories/post_repository.dart';
import '../data/repositories/comment_repository.dart';
import '../data/repositories/echo_repository.dart';
import 'auth_provider.dart';
import 'realtime_provider.dart';
import 'supabase_client_provider.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) {
  if (isMockMode) return PostRepository();
  return PostRepository(supabase: ref.watch(supabaseClientProvider));
});

// ---------------------------------------------------------------------------
// Feed state
// ---------------------------------------------------------------------------

class PostsState {
  final List<Post> posts;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  // Pagination
  final bool hasMore;
  final bool isLoadingMore;
  // Lane state
  final String activeLane; // 'all' | 'near_you' | 'country' | 'echoes' | 'mood'
  final String? activeMood; // populated when activeLane == 'mood'
  final List<String> dynamicMoodLanes;

  const PostsState({
    this.posts = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.activeLane = 'all',
    this.activeMood,
    this.dynamicMoodLanes = const [],
  });

  PostsState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    bool? hasMore,
    bool? isLoadingMore,
    String? activeLane,
    String? activeMood,
    bool clearMood = false,
    List<String>? dynamicMoodLanes,
  }) =>
      PostsState(
        posts: posts ?? this.posts,
        isLoading: isLoading ?? this.isLoading,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: clearError ? null : (error ?? this.error),
        hasMore: hasMore ?? this.hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        activeLane: activeLane ?? this.activeLane,
        activeMood: clearMood ? null : (activeMood ?? this.activeMood),
        dynamicMoodLanes: dynamicMoodLanes ?? this.dynamicMoodLanes,
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class PostsNotifier extends StateNotifier<PostsState> {
  final PostRepository _repo;
  final Ref _ref;

  /// Realtime fan-out subscription on the public feed_events table.
  /// Carries no identity — just (event_type, post_id, comment_id).
  RealtimeChannel? _eventsChannel;

  /// Highest feed_events.id we've already processed, used so we never
  /// re-apply an event when the channel resubscribes.
  int _lastProcessedEventId = 0;

  /// Lane generation counter — incremented on every setLane.
  /// Realtime callbacks capture the gen at the moment they fire and
  /// no-op if the user has since switched lanes (race protection).
  int _laneGen = 0;

  PostsNotifier(this._repo, this._ref) : super(const PostsState()) {
    _loadInitial();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    final ch = _eventsChannel;
    if (ch != null) {
      try {
        _ref.read(realtimeRepositoryProvider).unsubscribe(ch);
      } catch (e) {
        debugPrint('[posts] dispose channel: $e');
      }
    }
    super.dispose();
  }

  static const _pageSize = 30;

  Future<void> _loadInitial() async {
    // Load lanes and feed in parallel
    _loadDynamicLanes();
    await _loadLane();
  }

  // ── Realtime fan-out ────────────────────────────────────────────────────

  void _subscribeRealtime() {
    if (isMockMode) return;
    try {
      _eventsChannel = _ref
          .read(postRepositoryProvider)
          .subscribeToFeedEvents((row) {
        final id = (row['id'] as num?)?.toInt() ?? 0;
        if (id <= _lastProcessedEventId) return;
        _lastProcessedEventId = id;
        final type = row['event_type'] as String?;
        final postId = row['post_id'] as String?;
        if (type == null || postId == null) return;
        _handleEvent(type, postId);
      });
    } catch (e) {
      debugPrint('[realtime] subscribe failed: $e');
    }
  }

  Future<void> _handleEvent(String type, String postId) async {
    final genAtFire = _laneGen;
    try {
      switch (type) {
        case 'post_new':
          await _onNewPost(postId, genAtFire);
          break;
        case 'comment_new':
        case 'reaction_change':
        case 'echo_change':
          await _refreshCounts(postId, genAtFire);
          break;
        case 'second_thought':
          await _onSecondThought(postId, genAtFire);
          break;
      }
    } catch (e) {
      debugPrint('[realtime] _handleEvent($type, $postId) failed: $e');
    }
  }

  Future<void> _onNewPost(String postId, int genAtFire) async {
    // Skip if already in feed (e.g. owner already prepended optimistically)
    if (state.posts.any((p) => p.id == postId)) return;
    // Only auto-prepend on the 'all' lane to avoid putting a post into a
    // filtered lane it doesn't belong to. Other lanes get refreshed on
    // pull-to-refresh / next loadMore.
    if (state.activeLane != 'all') return;
    final uid = _ref.read(authProvider).userId;
    final fresh = await _repo.fetchPostById(postId, userId: uid);
    if (fresh == null) return;
    if (!mounted) return;
    if (genAtFire != _laneGen) return; // user switched lanes mid-fetch
    if (state.posts.any((p) => p.id == postId)) return;
    state = state.copyWith(posts: [fresh, ...state.posts]);
  }

  Future<void> _refreshCounts(String postId, int genAtFire) async {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx < 0) return;
    final result = await _repo.fetchAggregateCountsFor(postId);
    if (!mounted) return;
    if (genAtFire != _laneGen) return;
    final stillIdx = state.posts.indexWhere((p) => p.id == postId);
    if (stillIdx < 0) return;
    final updated = [...state.posts];
    updated[stillIdx] = updated[stillIdx].copyWith(
      reactionCounts: result.reactions,
      echoCount: result.echo,
      commentCount: result.comment,
    );
    state = state.copyWith(posts: updated);
  }

  Future<void> refresh() async {
    _loadDynamicLanes();
    await _loadLane();
  }

  /// Switch to a different lane (re-fetches with new params).
  /// Bumps the lane generation so any in-flight realtime callbacks for the
  /// previous lane no-op when they return.
  Future<void> setLane(String lane, {String? mood}) async {
    _laneGen++;
    state = state.copyWith(
      activeLane: lane,
      activeMood: mood,
      clearMood: mood == null,
      posts: const [],
      hasMore: true,
    );
    await _loadLane();
  }

  Future<void> _loadDynamicLanes() async {
    try {
      final lanes = await _repo.discoverDynamicMoodLanes(limit: 2);
      if (mounted) {
        state = state.copyWith(dynamicMoodLanes: lanes);
      }
    } catch (e) {
      debugPrint('[_loadDynamicLanes] $e');
    }
  }

  Future<void> _loadLane() async {
    state = state.copyWith(isLoading: true, clearError: true, hasMore: true);
    try {
      final uid = _ref.read(authProvider).userId;
      final posts = await _repo.fetchLane(
        userId: uid,
        lane: state.activeLane,
        mood: state.activeMood,
        limit: _pageSize,
        offset: 0,
      );
      final enriched = await _enrich(posts, uid);
      state = state.copyWith(
        posts: enriched,
        isLoading: false,
        hasMore: posts.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final uid = _ref.read(authProvider).userId;
      final more = await _repo.fetchLane(
        userId: uid,
        lane: state.activeLane,
        mood: state.activeMood,
        limit: _pageSize,
        offset: state.posts.length,
      );
      final existing = state.posts.map((p) => p.id).toSet();
      final fresh = more.where((p) => !existing.contains(p.id)).toList();
      final enriched = await _enrich(fresh, uid);
      state = state.copyWith(
        posts: [...state.posts, ...enriched],
        isLoadingMore: false,
        hasMore: more.length >= _pageSize,
      );
    } catch (e) {
      debugPrint('[loadMore] $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<List<Post>> _enrich(List<Post> posts, String? uid) async {
    if (posts.isEmpty) return posts;

    final commentRepo = isMockMode
        ? CommentRepository()
        : CommentRepository(supabase: _ref.read(supabaseClientProvider));
    final echoRepo = isMockMode
        ? EchoRepository()
        : EchoRepository(supabase: _ref.read(supabaseClientProvider));

    final allPostIds = posts.map((p) => p.id).toList();
    final commentCounts = await commentRepo.commentCountsBatch(allPostIds);
    final echoCounts = await echoRepo.echoCountsBatch(allPostIds);
    final myEchoes = uid != null
        ? await echoRepo.userEchoedPostIds(userId: uid, postIds: allPostIds)
        : <String>{};

    // Current user's own reactions on these posts (for the active highlight).
    // Under tightened RLS, post_reactions SELECT only returns own rows, so a
    // direct query is safe and identity-free for everyone else.
    final myReactionsByPost = <String, PostReaction>{};
    if (uid != null && !isMockMode) {
      try {
        final rows = await Supabase.instance.client
            .from('post_reactions')
            .select()
            .eq('user_id', uid)
            .inFilter('post_id', allPostIds);
        for (final r in rows) {
          final reaction =
              PostReaction.fromJson(Map<String, dynamic>.from(r));
          myReactionsByPost[reaction.postId] = reaction;
        }
      } catch (e) {
        debugPrint('[enrich:myReactions] $e');
      }
    }

    Map<String, Map<String, int>> ownCountsMap = {};
    if (uid != null) {
      final ownPostIds =
          posts.where((p) => p.userId == uid).map((p) => p.id).toList();
      if (ownPostIds.isNotEmpty) {
        ownCountsMap = await _repo.getOwnReactionCountsBatch(ownPostIds, uid);
      }
    }

    return posts.map((p) {
      final mine = myReactionsByPost[p.id];
      return p.copyWith(
        commentCount: commentCounts[p.id] ?? 0,
        echoCount: echoCounts[p.id] ?? 0,
        hasEchoed: myEchoes.contains(p.id),
        reactions: mine != null ? [mine] : const [],
        ownCounts:
            (uid != null && ownCountsMap.containsKey(p.id)) ? ownCountsMap[p.id] : null,
      );
    }).toList();
  }

  // ── Local count sync helpers (called by comment/echo providers) ─────────

  /// Bump comment count for a post in the live feed state.
  void bumpCommentCount(String postId, int delta) {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx < 0) return;
    final updated = [...state.posts];
    final p = updated[idx];
    final next = (p.commentCount + delta).clamp(0, 1 << 30);
    updated[idx] = p.copyWith(commentCount: next);
    state = state.copyWith(posts: updated);
  }

  /// Set absolute comment count for a post (used after a thread reload).
  void setCommentCount(String postId, int count) {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx < 0) return;
    final updated = [...state.posts];
    updated[idx] = updated[idx].copyWith(commentCount: count);
    state = state.copyWith(posts: updated);
  }

  // ── Echo ────────────────────────────────────────────────────────────────

  Future<void> toggleEcho(String postId) async {
    final uid = _ref.read(authProvider).userId;
    if (uid == null) return;
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx < 0) return;
    final post = state.posts[idx];
    final repo = isMockMode
        ? EchoRepository()
        : EchoRepository(supabase: _ref.read(supabaseClientProvider));

    // Optimistic update
    final wasEchoed = post.hasEchoed;
    final newCount = wasEchoed ? (post.echoCount - 1).clamp(0, 1 << 30) : post.echoCount + 1;
    final updatedPosts = [...state.posts];
    updatedPosts[idx] = post.copyWith(hasEchoed: !wasEchoed, echoCount: newCount);
    state = state.copyWith(posts: updatedPosts);

    final ok = wasEchoed
        ? await repo.unecho(postId: postId, userId: uid)
        : await repo.echo(postId: postId, userId: uid);

    if (!ok) {
      debugPrint('[toggleEcho] server rejected, rolling back');
      final rollbackPosts = [...state.posts];
      final i = rollbackPosts.indexWhere((p) => p.id == postId);
      if (i >= 0) {
        rollbackPosts[i] = rollbackPosts[i].copyWith(hasEchoed: wasEchoed, echoCount: post.echoCount);
        state = state.copyWith(posts: rollbackPosts, error: 'Echo failed. Try again.');
      }
    }
  }

  // ── Create / publish ────────────────────────────────────────────────────

  Future<Post?> createNob({
    required String content,
    required String nobType,
    String? photoUrl,
    String? caption,
    bool isAnonymous = false,
    DateTime? revisitAt,
  }) async {
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return null;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final post = await _repo.createPost(
        userId: userId,
        content: content,
        nobType: nobType,
        photoUrl: photoUrl,
        caption: caption,
        isDraft: false,
        isAnonymous: isAnonymous,
        revisitAt: revisitAt,
      );

      // Enrich the new post with the author profile so it shows the user's
      // name + avatar in the feed immediately (instead of "Noblara" fallback).
      Post enriched = post;
      if (!isMockMode) {
        try {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('display_name, date_avatar_url, nob_tier')
              .eq('id', userId)
              .maybeSingle();
          if (profile != null) {
            enriched = post.copyWith(
              authorName: profile['display_name'] as String?,
              authorAvatarUrl: profile['date_avatar_url'] as String?,
              authorTier: NobTier.fromString(profile['nob_tier'] as String?),
            );
          }
        } catch (e) {
          debugPrint('[createNob:enrich] profile fetch failed: $e');
        }
      }

      state = state.copyWith(posts: [enriched, ...state.posts], isSubmitting: false);
      // Trigger background quality score computation (fire-and-forget)
      _repo.computeQualityScore(
        postId: post.id,
        content: nobType == 'moment' ? (caption ?? '') : content,
        nobType: nobType,
      );
      return enriched;
    } catch (e) {
      debugPrint('[CREATE_NOB] ERROR: $e');
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return null;
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────

  Future<void> deletePost(String postId) async {
    final previous = state.posts;
    state = state.copyWith(
      posts: previous.where((p) => p.id != postId).toList(),
    );
    try {
      await _repo.deletePost(postId);
    } catch (e) {
      // Rollback
      state = state.copyWith(posts: previous, error: 'Could not delete: $e');
    }
  }

  // ── Reactions ───────────────────────────────────────────────────────────

  Future<void> react(String postId, String reactionType) async {
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return;

    final post = state.posts.where((p) => p.id == postId).firstOrNull;
    if (post == null) return;

    final previousReactions = List<PostReaction>.from(post.reactions);
    final previousCounts = Map<String, int>.from(post.reactionCounts);
    final existing = post.myReaction(userId);

    Map<String, int> bump(Map<String, int> base, String type, int delta) {
      final next = Map<String, int>.from(base);
      next[type] = ((next[type] ?? 0) + delta).clamp(0, 1 << 30);
      return next;
    }

    try {
      if (existing != null && existing.reactionType == reactionType) {
        // Toggle off — remove own reaction + decrement count
        final newReactions =
            post.reactions.where((r) => r.userId != userId).toList();
        final newCounts = bump(post.reactionCounts, reactionType, -1);
        _applyReactionState(postId, newReactions, newCounts);
        await _repo.removeReaction(postId: postId, userId: userId);
      } else {
        // Add or replace — drop own previous reaction first
        final newReactions = [
          ...post.reactions.where((r) => r.userId != userId),
          PostReaction(
            id: 'opt-${DateTime.now().millisecondsSinceEpoch}',
            postId: postId,
            userId: userId,
            reactionType: reactionType,
            createdAt: DateTime.now(),
          ),
        ];
        var newCounts = post.reactionCounts;
        if (existing != null) {
          newCounts = bump(newCounts, existing.reactionType, -1);
        }
        newCounts = bump(newCounts, reactionType, 1);
        _applyReactionState(postId, newReactions, newCounts);
        await _repo.react(
            postId: postId, userId: userId, reactionType: reactionType);
      }
    } catch (e) {
      debugPrint('[react] server error, rolling back: $e');
      _applyReactionState(postId, previousReactions, previousCounts);
      state = state.copyWith(error: 'Reaction failed. Try again.');
    }
  }

  void _applyReactionState(
      String postId, List<PostReaction> reactions, Map<String, int> counts) {
    state = state.copyWith(
      posts: state.posts
          .map((p) => p.id == postId
              ? p.copyWith(reactions: reactions, reactionCounts: counts)
              : p)
          .toList(),
    );
  }

  // ── Second Thought / Edit ────────────────────────────────────────────────

  Future<({bool ok, String? error})> minorEdit(
      String postId, String newContent, {String? newCaption}) async {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    final previous = idx >= 0 ? state.posts[idx] : null;
    if (idx >= 0) {
      final updated = [...state.posts];
      updated[idx] = updated[idx].copyWith(
        content: newContent,
        caption: newCaption,
        editCount: updated[idx].editCount + 1,
        lastEditedAt: DateTime.now(),
      );
      state = state.copyWith(posts: updated);
    }
    final result = await _repo.performMinorEdit(
        postId: postId, newContent: newContent, newCaption: newCaption);
    if (!result.ok && previous != null && mounted) {
      final rollback = [...state.posts];
      final i = rollback.indexWhere((p) => p.id == postId);
      if (i >= 0) rollback[i] = previous;
      state = state.copyWith(posts: rollback, error: result.error);
    }
    return result;
  }

  Future<({bool ok, String? error})> secondThought(
      String postId, String newContent,
      {String? newCaption, String? reason}) async {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    final previous = idx >= 0 ? state.posts[idx] : null;
    if (idx >= 0) {
      final p = state.posts[idx];
      final updated = [...state.posts];
      updated[idx] = p.copyWith(
        content: newContent,
        caption: newCaption,
        hasSecondThought: true,
        secondThoughtReason: reason,
        editCount: p.editCount + 1,
        lastEditedAt: DateTime.now(),
        originalContent: p.originalContent ?? p.content,
        originalCaption: p.originalCaption ?? p.caption,
      );
      state = state.copyWith(posts: updated);
    }
    final result = await _repo.performSecondThought(
        postId: postId,
        newContent: newContent,
        newCaption: newCaption,
        reason: reason);
    if (!result.ok && previous != null && mounted) {
      final rollback = [...state.posts];
      final i = rollback.indexWhere((p) => p.id == postId);
      if (i >= 0) rollback[i] = previous;
      state = state.copyWith(posts: rollback, error: result.error);
    }
    if (result.ok) {
      final post = state.posts.where((p) => p.id == postId).firstOrNull;
      if (post != null) {
        _repo.computeQualityScore(
          postId: postId,
          content: post.isMoment ? (post.caption ?? '') : newContent,
          nobType: post.nobType,
        );
      }
    }
    return result;
  }

  Future<void> _onSecondThought(String postId, int genAtFire) async {
    final uid = _ref.read(authProvider).userId;
    final fresh = await _repo.fetchPostById(postId, userId: uid);
    if (fresh == null || !mounted) return;
    if (genAtFire != _laneGen) return;
    final updated = [...state.posts];
    final idx = updated.indexWhere((p) => p.id == postId);
    if (idx >= 0) {
      updated[idx] = fresh.copyWith(
        reactions: updated[idx].reactions,
        reactionCounts: updated[idx].reactionCounts,
        commentCount: updated[idx].commentCount,
        echoCount: updated[idx].echoCount,
        hasEchoed: updated[idx].hasEchoed,
      );
      state = state.copyWith(posts: updated);
    }
  }

  // ── Limit check ─────────────────────────────────────────────────────────

  Future<bool> canPublishToday(String nobType) async {
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return false;
    return _repo.canPublishToday(userId, nobType);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final postsProvider = StateNotifierProvider<PostsNotifier, PostsState>((ref) {
  final repo = ref.watch(postRepositoryProvider);
  return PostsNotifier(repo, ref);
});

// Last nobs for a specific user (used by My Nobs and other surfaces)
final lastNobsProvider =
    FutureProvider.autoDispose.family<List<Post>, String>((ref, userId) async {
  final repo = ref.watch(postRepositoryProvider);
  return repo.fetchLastNobs(userId, limit: 3);
});

// Current user's nob tier — autoDispose so it re-fetches on user switch.
final nobTierProvider = FutureProvider.autoDispose<NobTier>((ref) async {
  if (isMockMode) return NobTier.noble;
  final userId = ref.watch(authProvider).userId;
  if (userId == null) return NobTier.observer;
  try {
    final row = await Supabase.instance.client
        .from('profiles')
        .select('nob_tier')
        .eq('id', userId)
        .maybeSingle();
    return NobTier.fromString(row?['nob_tier'] as String?);
  } catch (e) {
    debugPrint('[posts] nob_tier fetch failed: $e');
    return NobTier.observer;
  }
});

// Whether current user is an admin — autoDispose so it refreshes on user switch.
final isAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (isMockMode) return true;
  final userId = ref.watch(authProvider).userId;
  if (userId == null) return false;
  final row = await Supabase.instance.client
      .from('profiles')
      .select('is_admin')
      .eq('id', userId)
      .maybeSingle();
  return row?['is_admin'] as bool? ?? false;
});
