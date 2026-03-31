import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';
import '../data/repositories/super_like_repository.dart';
import 'auth_provider.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class StatusData {
  final int profileViews;
  final int matchCount;
  final int reactionCount;
  final bool isNoble;
  final int superLikesRemaining;
  final int rewindsRemaining;
  final DateTime? boostActiveUntil;
  final List<WhoLikedItem> likedMe;
  final List<WhoLikedItem> iLiked;
  final List<WhoLikedItem> superLikesReceived;
  // Noble-only stats
  final int myPostsCount;
  final int myReactionsReceived;

  const StatusData({
    this.profileViews = 0,
    this.matchCount = 0,
    this.reactionCount = 0,
    this.isNoble = false,
    this.superLikesRemaining = 3,
    this.rewindsRemaining = 3,
    this.boostActiveUntil,
    this.likedMe = const [],
    this.iLiked = const [],
    this.superLikesReceived = const [],
    this.myPostsCount = 0,
    this.myReactionsReceived = 0,
  });

  bool get isBoostActive =>
      boostActiveUntil != null &&
      boostActiveUntil!.isAfter(DateTime.now());
}

// ---------------------------------------------------------------------------
// Notifier — wraps boost activation + data loading
// ---------------------------------------------------------------------------

class StatusNotifier extends StateNotifier<AsyncValue<StatusData>> {
  final Ref _ref;

  StatusNotifier(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _fetchData());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _load();

  /// Activate a 30-minute boost (free, one use).
  Future<void> activateBoost() async {
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return;
    final until = DateTime.now().add(const Duration(minutes: 30));
    if (!isMockMode) {
      await Supabase.instance.client
          .from('profiles')
          .update({'boost_active_until': until.toIso8601String()})
          .eq('id', userId);
    }
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(StatusData(
        profileViews: current.profileViews,
        matchCount: current.matchCount,
        reactionCount: current.reactionCount,
        isNoble: current.isNoble,
        superLikesRemaining: current.superLikesRemaining,
        rewindsRemaining: current.rewindsRemaining,
        boostActiveUntil: until,
        likedMe: current.likedMe,
        iLiked: current.iLiked,
        superLikesReceived: current.superLikesReceived,
        myPostsCount: current.myPostsCount,
        myReactionsReceived: current.myReactionsReceived,
      ));
    }
  }

  /// Called after a super like is sent — decrements local counter.
  void decrementSuperLikes() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(StatusData(
      profileViews: current.profileViews,
      matchCount: current.matchCount,
      reactionCount: current.reactionCount,
      isNoble: current.isNoble,
      superLikesRemaining: (current.superLikesRemaining - 1).clamp(0, 99),
      rewindsRemaining: current.rewindsRemaining,
      boostActiveUntil: current.boostActiveUntil,
      likedMe: current.likedMe,
      iLiked: current.iLiked,
      superLikesReceived: current.superLikesReceived,
      myPostsCount: current.myPostsCount,
      myReactionsReceived: current.myReactionsReceived,
    ));
  }

  /// Called after a rewind — decrements local counter.
  void decrementRewinds() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(StatusData(
      profileViews: current.profileViews,
      matchCount: current.matchCount,
      reactionCount: current.reactionCount,
      isNoble: current.isNoble,
      superLikesRemaining: current.superLikesRemaining,
      rewindsRemaining: (current.rewindsRemaining - 1).clamp(0, 99),
      boostActiveUntil: current.boostActiveUntil,
      likedMe: current.likedMe,
      iLiked: current.iLiked,
      superLikesReceived: current.superLikesReceived,
      myPostsCount: current.myPostsCount,
      myReactionsReceived: current.myReactionsReceived,
    ));
  }

  Future<StatusData> _fetchData() async {
    if (isMockMode) {
      return StatusData(
        profileViews: 47,
        matchCount: 3,
        reactionCount: 12,
        isNoble: false,
        superLikesRemaining: 3,
        rewindsRemaining: 3,
        likedMe: const [
          WhoLikedItem(userId: 'm1', name: 'Emma', mode: 'date'),
          WhoLikedItem(userId: 'm2', name: 'Sofia', mode: 'bff'),
        ],
        iLiked: const [
          WhoLikedItem(userId: 'm3', name: 'Mia', mode: 'date'),
        ],
        superLikesReceived: const [],
      );
    }

    final userId = _ref.read(authProvider).userId;
    if (userId == null) return const StatusData();
    final client = Supabase.instance.client;

    // Profile row
    final profileRow = await client
        .from('profiles')
        .select('profile_views, is_noble, super_likes_remaining, rewinds_remaining, boost_active_until')
        .eq('id', userId)
        .maybeSingle();

    final profileViews = profileRow?['profile_views'] as int? ?? 0;
    final isNoble = profileRow?['is_noble'] as bool? ?? false;
    final superLikesRemaining = profileRow?['super_likes_remaining'] as int? ?? 3;
    final rewindsRemaining = profileRow?['rewinds_remaining'] as int? ?? 3;
    final boostStr = profileRow?['boost_active_until'] as String?;
    final boostActiveUntil =
        boostStr != null ? DateTime.tryParse(boostStr) : null;

    // Match count
    final matchRows = await client
        .from('matches')
        .select('id')
        .or('user1_id.eq.$userId,user2_id.eq.$userId');
    final matchCount = matchRows.length;

    // Reaction count on my posts
    final myPosts = await client
        .from('posts')
        .select('id')
        .eq('user_id', userId);
    final postIds = myPosts.map((r) => r['id'] as String).toList();
    int reactionCount = 0;
    int myPostsCount = myPosts.length;
    int myReactionsReceived = 0;
    if (postIds.isNotEmpty) {
      final reactions = await client
          .from('post_reactions')
          .select('id')
          .inFilter('post_id', postIds);
      reactionCount = reactions.length;
      myReactionsReceived = reactions.length;
    }

    // Who liked me
    final repo = SuperLikeRepository(supabase: client);
    final likedMe = await repo.fetchWhoLikedMe(userId);
    final iLiked = await repo.fetchILiked(userId);
    final superLikesReceived = await repo.fetchSuperLikesReceived(userId);

    return StatusData(
      profileViews: profileViews,
      matchCount: matchCount,
      reactionCount: reactionCount,
      isNoble: isNoble,
      superLikesRemaining: superLikesRemaining,
      rewindsRemaining: rewindsRemaining,
      boostActiveUntil: boostActiveUntil,
      likedMe: likedMe,
      iLiked: iLiked,
      superLikesReceived: superLikesReceived,
      myPostsCount: myPostsCount,
      myReactionsReceived: myReactionsReceived,
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final statusProvider =
    StateNotifierProvider<StatusNotifier, AsyncValue<StatusData>>((ref) {
  return StatusNotifier(ref);
});
