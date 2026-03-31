import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart';
import '../data/models/bff_suggestion.dart';
import '../data/models/bff_plan.dart';
import '../data/models/filter_state.dart';
import '../data/repositories/bff_suggestion_repository.dart';
import 'auth_provider.dart';
import 'filter_provider.dart';

// ─── State ─────────────────────────────────────────────────────────

class BffState {
  final List<BffSuggestion> suggestions;
  final List<Map<String, dynamic>> reachOuts;
  final bool isLoading;
  final String? error;

  const BffState({
    this.suggestions = const [],
    this.reachOuts = const [],
    this.isLoading = false,
    this.error,
  });

  BffState copyWith({
    List<BffSuggestion>? suggestions,
    List<Map<String, dynamic>>? reachOuts,
    bool? isLoading,
    String? error,
  }) =>
      BffState(
        suggestions: suggestions ?? this.suggestions,
        reachOuts: reachOuts ?? this.reachOuts,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ─── Repository provider ───────────────────────────────────────────

final bffRepositoryProvider = Provider<BffSuggestionRepository>((ref) {
  if (isMockMode) return BffSuggestionRepository();
  return BffSuggestionRepository(
    supabase: Supabase.instance.client,
  );
});

// ─── Notifier ──────────────────────────────────────────────────────

class BffNotifier extends StateNotifier<BffState> {
  final Ref _ref;

  BffNotifier(this._ref) : super(const BffState()) {
    // Reload when filters change
    _ref.listen<FilterState>(filterProvider, (_, __) => load());
  }

  String? get _userId => _ref.read(authProvider).userId;

  List<BffSuggestion> _applyFilters(List<BffSuggestion> suggestions, FilterState f) {
    if (f.trustShieldEnabled) {
      // Trust Shield: would need tier info on suggestion — skip unverified
    }
    // Age filter (if suggestion had age — currently not in model, skip gracefully)
    // Interests/vibes: boost matching suggestions to top
    if (f.interests.isNotEmpty) {
      suggestions.sort((a, b) {
        final aMatch = a.otherUserNobPosts.where((p) => f.interests.any((i) => p.toLowerCase().contains(i.toLowerCase()))).length;
        final bMatch = b.otherUserNobPosts.where((p) => f.interests.any((i) => p.toLowerCase().contains(i.toLowerCase()))).length;
        return bMatch.compareTo(aMatch);
      });
    }
    return suggestions;
  }

  Future<void> load() async {
    final uid = _userId;
    if (uid == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = _ref.read(bffRepositoryProvider);
      var suggestions = await repo.fetchSuggestions(uid);
      final reachOuts = await repo.fetchReachOutsReceived(uid);

      // Apply BFF filters client-side to suggestions
      final filters = _ref.read(filterProvider);
      suggestions = _applyFilters(suggestions, filters);

      state = state.copyWith(
        suggestions: suggestions,
        reachOuts: reachOuts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String> actOnSuggestion(String suggestionId, String action) async {
    final uid = _userId;
    if (uid == null) return 'error';

    final repo = _ref.read(bffRepositoryProvider);
    final result = await repo.actOnSuggestion(
      suggestionId: suggestionId,
      userId: uid,
      action: action,
    );

    // Remove from list
    state = state.copyWith(
      suggestions: state.suggestions.where((s) => s.id != suggestionId).toList(),
    );

    return result['result'] as String? ?? 'error';
  }

  Future<bool> sendReachOut(String receiverId) async {
    final uid = _userId;
    if (uid == null) return false;

    final repo = _ref.read(bffRepositoryProvider);
    final canSend = await repo.canReachOut(uid);
    if (!canSend) return false;

    await repo.sendReachOut(senderId: uid, receiverId: receiverId);
    return true;
  }

  /// Triggers real server-side suggestion generation
  Future<void> generateSuggestions() async {
    final uid = _userId;
    if (uid == null) return;

    final repo = _ref.read(bffRepositoryProvider);
    await repo.generateSuggestions(uid);
    await load(); // reload to show new suggestions
  }

  Future<List<BffPlan>> fetchPlans(String conversationId) async {
    final repo = _ref.read(bffRepositoryProvider);
    return repo.fetchPlans(conversationId);
  }

  Future<BffPlan?> createPlan({
    required String conversationId,
    required String planType,
    String? location,
    required DateTime scheduledAt,
  }) async {
    final uid = _userId;
    if (uid == null) return null;

    final repo = _ref.read(bffRepositoryProvider);
    return repo.createPlan(
      conversationId: conversationId,
      createdBy: uid,
      planType: planType,
      location: location,
      scheduledAt: scheduledAt,
    );
  }
}

// ─── Provider ──────────────────────────────────────────────────────

final bffProvider = StateNotifierProvider<BffNotifier, BffState>((ref) {
  return BffNotifier(ref);
});
