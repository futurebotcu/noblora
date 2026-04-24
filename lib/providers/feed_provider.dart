import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/enums/noble_mode.dart';
import '../core/utils/mock_mode.dart';
import '../data/models/filter_state.dart';
import '../data/models/match.dart';
import '../data/models/profile_card.dart';
import '../data/repositories/feed_repository.dart';
import '../data/repositories/signal_repository.dart';
import '../data/repositories/super_like_repository.dart';
import 'auth_provider.dart';
import 'filter_provider.dart';
import 'match_provider.dart';
import 'mode_provider.dart';
import 'status_provider.dart';

final signalRepositoryProvider = Provider<SignalRepository>((ref) {
  if (isMockMode) return SignalRepository();
  return SignalRepository(supabase: Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// Repository provider
// ---------------------------------------------------------------------------

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  if (isMockMode) return FeedRepository();
  return FeedRepository(supabase: Supabase.instance.client);
});

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class FeedState {
  final List<ProfileCard> cards;
  final bool isLoading;
  final String? error;
  final NobleMatch? newMatch;
  final ProfileCard? lastRemovedCard;
  final String? lastRemovedDirection;

  const FeedState({
    this.cards = const [],
    this.isLoading = false,
    this.error,
    this.newMatch,
    this.lastRemovedCard,
    this.lastRemovedDirection,
  });

  bool get isEmpty => cards.isEmpty && !isLoading;

  FeedState copyWith({
    List<ProfileCard>? cards,
    bool? isLoading,
    String? error,
    bool clearError = false,
    NobleMatch? newMatch,
    bool clearNewMatch = false,
    ProfileCard? lastRemovedCard,
    String? lastRemovedDirection,
    bool clearLastRemoved = false,
  }) {
    return FeedState(
      cards: cards ?? this.cards,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      newMatch: clearNewMatch ? null : (newMatch ?? this.newMatch),
      lastRemovedCard: clearLastRemoved ? null : (lastRemovedCard ?? this.lastRemovedCard),
      lastRemovedDirection: clearLastRemoved ? null : (lastRemovedDirection ?? this.lastRemovedDirection),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class FeedNotifier extends StateNotifier<FeedState> {
  final Ref _ref;

  FeedNotifier(this._ref) : super(const FeedState()) {
    // Wait for a valid userId before loading; re-trigger on auth changes.
    _ref.listen(authProvider, (prev, next) {
      final wasNull = prev?.userId == null;
      final hasUser = next.userId != null;
      if (wasNull && hasUser) loadFeed();
    });

    // Reload feed when filters change
    _ref.listen<FilterState>(filterProvider, (prev, next) {
      if (prev != next) loadFeed();
    });

    // Also load immediately if userId is already available.
    if (_ref.read(authProvider).userId != null) loadFeed();
  }

  Future<void> loadFeed([NobleMode? mode]) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final NobleMode resolved = mode ?? _ref.read(modeProvider);

    if (isMockMode) {
      state = state.copyWith(cards: [], isLoading: false);
      return;
    }

    final userId = _ref.read(authProvider).userId;
    if (userId == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    try {
      final swipeRepo = _ref.read(swipeRepositoryProvider);
      final swipedIds = await swipeRepo.fetchSwipedIds(userId, resolved.name);

      // Read current filters and pass to repository
      final filters = _ref.read(filterProvider);

      // Load blocked/hidden users to exclude from feed
      Set<String> blockedIds = {};
      Set<String> hiddenIds = {};
      try {
        final row = await Supabase.instance.client
            .from('profiles')
            .select('blocked_users, hidden_users')
            .eq('id', userId)
            .maybeSingle();
        if (row != null) {
          blockedIds = {for (final id in (row['blocked_users'] as List<dynamic>? ?? [])) id as String};
          hiddenIds = {for (final id in (row['hidden_users'] as List<dynamic>? ?? [])) id as String};
        }
      } catch (e) {
        debugPrint('[feed] blocked/hidden users fetch failed: $e');
        rethrow;
      }

      final feedRepo = _ref.read(feedRepositoryProvider);
      final cards = await feedRepo.fetchFeedProfiles(
        userId: userId,
        mode: resolved.name,
        excludeIds: swipedIds,
        filters: filters,
        blockedIds: blockedIds,
        hiddenIds: hiddenIds,
      );

      state = state.copyWith(cards: cards, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> swipeRight(String cardId) async {
    _removeCard(cardId, 'right');
    try {
      final mode = _ref.read(modeProvider);
      final match = await _ref.read(matchProvider.notifier).swipe(
            targetId: cardId,
            direction: 'right',
            mode: mode.name,
          );
      if (match != null) {
        state = state.copyWith(newMatch: match);
      }
    } catch (e) {
      _rollbackCard();
    }
  }

  Future<void> swipeLeft(String cardId) async {
    _removeCard(cardId, 'left');
    try {
      final mode = _ref.read(modeProvider);
      await _ref.read(matchProvider.notifier).swipe(
            targetId: cardId,
            direction: 'left',
            mode: mode.name,
          );
    } catch (e) {
      _rollbackCard();
    }
  }

  Future<void> sendSignal(String cardId) async {
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return;

    final signalRepo = _ref.read(signalRepositoryProvider);
    final canSend = await signalRepo.canSendSignal(userId);
    if (!canSend) return;

    await signalRepo.sendSignal(senderId: userId, receiverId: cardId);
  }

  Future<void> superLike(String cardId) async {
    await sendSignal(cardId);
  }

  Future<void> rewind() async {
    final card = state.lastRemovedCard;
    if (card == null) return;
    final statusData = _ref.read(statusProvider).valueOrNull;
    if (statusData != null && statusData.rewindsRemaining <= 0) return;

    final userId = _ref.read(authProvider).userId;
    if (userId != null && !isMockMode) {
      final repo = SuperLikeRepository(supabase: Supabase.instance.client);
      await repo.deleteSwipe(swiperId: userId, targetId: card.id);
      await Supabase.instance.client
          .rpc('decrement_rewinds', params: {'uid': userId});
    }
    state = state.copyWith(
      cards: [card, ...state.cards],
      clearLastRemoved: true,
    );
    _ref.read(statusProvider.notifier).decrementRewinds();
  }

  void clearNewMatch() {
    state = state.copyWith(clearNewMatch: true);
  }

  void clear() {
    state = const FeedState();
  }

  void _rollbackCard() {
    final card = state.lastRemovedCard;
    if (card == null) return;
    state = state.copyWith(
      cards: [card, ...state.cards],
      clearLastRemoved: true,
      error: 'Swipe failed — card restored',
    );
  }

  void _removeCard(String cardId, String direction) {
    final card = state.cards.where((c) => c.id == cardId).firstOrNull;
    final remaining = state.cards.where((c) => c.id != cardId).toList();
    state = state.copyWith(
      cards: remaining,
      lastRemovedCard: card,
      lastRemovedDirection: direction,
    );
    if (remaining.isEmpty) loadFeed();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  return FeedNotifier(ref);
});

