import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';
import '../data/models/post.dart';
import '../data/repositories/post_repository.dart';
import 'auth_provider.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) {
  if (isMockMode) return PostRepository();
  return PostRepository(supabase: Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// Feed state
// ---------------------------------------------------------------------------

class PostsState {
  final List<Post> posts;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  // Feed filters
  final String? typeFilter;   // 'thought' | 'moment' | null=all
  final String sortMode;      // 'newest' | 'trending' | 'ai_pick'
  final String? toneFilter;   // 'reflective' | 'grounded' | 'curious' | 'creative'
  final bool hidePassed;
  final bool prioritizeConnected;

  const PostsState({
    this.posts = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.typeFilter,
    this.sortMode = 'newest',
    this.toneFilter,
    this.hidePassed = false,
    this.prioritizeConnected = false,
  });

  PostsState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    String? typeFilter,
    bool clearType = false,
    String? sortMode,
    String? toneFilter,
    bool clearTone = false,
    bool? hidePassed,
    bool? prioritizeConnected,
  }) =>
      PostsState(
        posts: posts ?? this.posts,
        isLoading: isLoading ?? this.isLoading,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: clearError ? null : (error ?? this.error),
        typeFilter: clearType ? null : (typeFilter ?? this.typeFilter),
        sortMode: sortMode ?? this.sortMode,
        toneFilter: clearTone ? null : (toneFilter ?? this.toneFilter),
        hidePassed: hidePassed ?? this.hidePassed,
        prioritizeConnected: prioritizeConnected ?? this.prioritizeConnected,
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class PostsNotifier extends StateNotifier<PostsState> {
  final PostRepository _repo;
  final Ref _ref;
  StreamSubscription<List<Post>>? _sub;

  PostsNotifier(this._repo, this._ref) : super(const PostsState()) {
    _init();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true, clearError: true);
    _sub?.cancel();
    _sub = _repo.feedStream().listen(
      (posts) {
        if (mounted) state = state.copyWith(posts: posts, isLoading: false);
      },
      onError: (Object e) {
        if (mounted) state = state.copyWith(isLoading: false, error: e.toString());
      },
    );
  }

  Future<void> refresh() => _loadFiltered();

  Future<void> _loadFiltered() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final uid = _ref.read(authProvider).userId;
      final posts = await _repo.fetchFeed(
        userId: uid,
        type: state.typeFilter,
        sort: state.sortMode,
        tone: state.toneFilter,
        hidePassed: state.hidePassed,
        prioritizeConnected: state.prioritizeConnected,
      );

      // Load own reaction counts for author's posts
      if (uid != null) {
        final enriched = <Post>[];
        for (final p in posts) {
          if (p.userId == uid) {
            final counts = await _repo.getOwnReactionCounts(p.id, uid);
            enriched.add(p.copyWith(ownCounts: counts));
          } else {
            enriched.add(p);
          }
        }
        state = state.copyWith(posts: enriched, isLoading: false);
      } else {
        state = state.copyWith(posts: posts, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setTypeFilter(String? type) {
    state = state.copyWith(typeFilter: type, clearType: type == null);
    _loadFiltered();
  }

  void setSortMode(String sort) {
    state = state.copyWith(sortMode: sort);
    _loadFiltered();
  }

  void setToneFilter(String? tone) {
    state = state.copyWith(toneFilter: tone, clearTone: tone == null);
    _loadFiltered();
  }

  void setHidePassed(bool v) {
    state = state.copyWith(hidePassed: v);
    _loadFiltered();
  }

  void setPrioritizeConnected(bool v) {
    state = state.copyWith(prioritizeConnected: v);
    _loadFiltered();
  }

  void setError(String message) => state = state.copyWith(error: message);

  // ── Create / Draft ──────────────────────────────────────────────────────

  Future<Post?> createNob({
    required String content,
    required String nobType,
    String? photoUrl,
    String? caption,
    bool isDraft = true,
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
        isDraft: isDraft,
      );
      if (!post.isDraft) {
        state = state.copyWith(posts: [post, ...state.posts], isSubmitting: false);
        // Trigger background quality score computation
        _repo.computeQualityScore(post.id);
      } else {
        state = state.copyWith(isSubmitting: false);
      }
      return post;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return null;
    }
  }

  Future<bool> publishDraft(String postId) async {
    try {
      final post = await _repo.publishDraft(postId);
      if (post != null) {
        state = state.copyWith(posts: [post, ...state.posts]);
      }
      return post != null;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // ── Pin / Archive / Delete ───────────────────────────────────────────────

  Future<void> togglePin(String postId, bool pin) async {
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return;
    await _repo.togglePin(postId, userId, pin);
    state = state.copyWith(
      posts: state.posts.map((p) {
        if (p.userId != userId) return p;
        if (p.id == postId) return p.copyWith(isPinned: pin);
        return p.copyWith(isPinned: false);
      }).toList(),
    );
  }

  Future<void> archivePost(String postId) async {
    await _repo.archivePost(postId);
    state = state.copyWith(
      posts: state.posts.where((p) => p.id != postId).toList(),
    );
  }

  Future<void> deletePost(String postId) async {
    await _repo.deletePost(postId);
    state = state.copyWith(
      posts: state.posts.where((p) => p.id != postId).toList(),
    );
  }

  // ── Reactions ────────────────────────────────────────────────────────────

  Future<void> react(String postId, String reactionType) async {
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return;

    final post = state.posts.where((p) => p.id == postId).firstOrNull;
    if (post == null) return;

    final existing = post.myReaction(userId);
    if (existing != null && existing.reactionType == reactionType) {
      await _repo.removeReaction(postId: postId, userId: userId);
      _updateReactions(
          postId, post.reactions.where((r) => r.userId != userId).toList());
    } else {
      await _repo.react(postId: postId, userId: userId, reactionType: reactionType);
      final updated = [
        ...post.reactions.where((r) => r.userId != userId),
        PostReaction(
          id: 'opt-${DateTime.now().millisecondsSinceEpoch}',
          postId: postId,
          userId: userId,
          reactionType: reactionType,
          createdAt: DateTime.now(),
        ),
      ];
      _updateReactions(postId, updated);
    }
  }

  void _updateReactions(String postId, List<PostReaction> reactions) {
    state = state.copyWith(
      posts: state.posts
          .map((p) => p.id == postId ? p.copyWith(reactions: reactions) : p)
          .toList(),
    );
  }

  // ── Limit check ──────────────────────────────────────────────────────────

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

// Drafts — loaded separately
final draftsProvider = FutureProvider.autoDispose<List<Post>>((ref) async {
  if (isMockMode) return [];
  final userId = ref.watch(authProvider).userId;
  if (userId == null) return [];
  final repo = ref.watch(postRepositoryProvider);
  return repo.fetchDrafts(userId);
});

// Archived
final archivedNobsProvider = FutureProvider.autoDispose<List<Post>>((ref) async {
  if (isMockMode) return [];
  final userId = ref.watch(authProvider).userId;
  if (userId == null) return [];
  final repo = ref.watch(postRepositoryProvider);
  return repo.fetchArchived(userId);
});

// Last nobs for a specific user (swipe card / profile)
final lastNobsProvider =
    FutureProvider.autoDispose.family<List<Post>, String>((ref, userId) async {
  final repo = ref.watch(postRepositoryProvider);
  return repo.fetchLastNobs(userId, limit: 3);
});

// Current user's nob tier
final nobTierProvider = FutureProvider<NobTier>((ref) async {
  if (isMockMode) return NobTier.noble;
  final userId = ref.watch(authProvider).userId;
  if (userId == null) return NobTier.observer;
  final row = await Supabase.instance.client
      .from('profiles')
      .select('nob_tier')
      .eq('id', userId)
      .maybeSingle();
  return NobTier.fromString(row?['nob_tier'] as String?);
});

// Whether current user is a Noble (can post) — kept for legacy compatibility
final isNobleProvider = FutureProvider<bool>((ref) async {
  final tier = await ref.watch(nobTierProvider.future);
  return tier == NobTier.noble;
});

// Whether current user is an admin
final isAdminProvider = FutureProvider<bool>((ref) async {
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
