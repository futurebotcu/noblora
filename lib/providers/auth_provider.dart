import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/mock_mode.dart' show isMockMode, isDevMode;
import '../data/repositories/auth_repository.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class AuthState {
  final String? userId;
  final String? email;
  final bool isInitialized;
  final bool isLoading;
  final String? error;
  /// True when signUp succeeded but Supabase requires email confirmation.
  /// The user exists but has no active session yet.
  final bool needsEmailConfirmation;

  const AuthState({
    this.userId,
    this.email,
    this.isInitialized = false,
    this.isLoading = false,
    this.error,
    this.needsEmailConfirmation = false,
  });

  bool get isAuthenticated => userId != null;

  AuthState copyWith({
    String? userId,
    String? email,
    bool? isInitialized,
    bool? isLoading,
    String? error,
    bool clearUserId = false,
    bool clearError = false,
    bool? needsEmailConfirmation,
  }) {
    return AuthState(
      userId: clearUserId ? null : (userId ?? this.userId),
      email: clearUserId ? null : (email ?? this.email),
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      needsEmailConfirmation:
          needsEmailConfirmation ?? this.needsEmailConfirmation,
    );
  }
}

// ---------------------------------------------------------------------------
// Error mapping — turns raw Supabase exceptions into readable messages
// ---------------------------------------------------------------------------

String _friendlyError(Object e) {
  final raw = e.toString().toLowerCase();
  if (raw.contains('already registered') ||
      raw.contains('already exists') ||
      raw.contains('user_already_exists')) {
    return 'already_registered';
  }
  if (raw.contains('invalid login') ||
      raw.contains('invalid credentials') ||
      raw.contains('invalid email or password')) {
    return 'Email or password is incorrect.';
  }
  if (raw.contains('email') && raw.contains('invalid')) {
    return 'Please enter a valid email address.';
  }
  if (raw.contains('password') &&
      (raw.contains('short') || raw.contains('weak') || raw.contains('6'))) {
    return 'Password must be at least 6 characters.';
  }
  if (raw.contains('rate limit') || raw.contains('too many')) {
    return 'Too many attempts. Please wait a moment and try again.';
  }
  if (raw.contains('email') && raw.contains('disabled')) {
    return 'Email sign-up is currently unavailable.';
  }
  if (raw.contains('network') || raw.contains('socket')) {
    return 'Network error. Check your connection and try again.';
  }
  return e.toString();
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  StreamSubscription<dynamic>? _authSub;
  Timer? _refreshTimer;

  AuthNotifier(this._repo) : super(const AuthState()) {
    initialize();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    try {
      final id = await _repo.getCurrentUserId();
      final email = await _repo.getCurrentUserEmail();
      state = AuthState(
        userId: id,
        email: email,
        isInitialized: true,
        isLoading: false,
      );
      // Update last active + trigger maturity score recalculation
      if (!isMockMode && id != null) {
        Supabase.instance.client.rpc('update_last_active', params: {'p_user_id': id}).ignore();
        Supabase.instance.client.rpc('calculate_maturity_score', params: {'p_user_id': id}).ignore();
      }
      // Periodic session refresh — keeps JWT fresh, prevents stale tokens
      if (!isMockMode && id != null) {
        _refreshTimer?.cancel();
        _refreshTimer = Timer.periodic(const Duration(minutes: 30), (_) async {
          try {
            await Supabase.instance.client.auth.refreshSession();
          } catch (e) {
            debugPrint('[auth] Session refresh failed: $e');
          }
        });
      }
      if (!isMockMode) {
        _authSub = _repo.authStateChanges.listen((authState) {
          final event = authState.event;
          final user = authState.session?.user;
          // Only clear auth state on explicit sign-out.
          // Ignore intermediate null sessions from token refresh (PKCE web issue).
          if (event == AuthChangeEvent.signedOut) {
            state = state.copyWith(
              clearUserId: true,
              isInitialized: true,
              isLoading: false,
              needsEmailConfirmation: false,
            );
          } else if (user != null) {
            state = state.copyWith(
              userId: user.id,
              email: user.email,
              isLoading: false,
            );
          }
        });
      }
    } catch (e) {
      // Initialization failed — clear any stale session and go to login.
      try {
        await _repo.signOut();
      } catch (_) { /* Intentional: best-effort cleanup on init failure */ }
      state = AuthState(
        isInitialized: true,
        isLoading: false,
        error: _friendlyError(e),
      );
    }
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      needsEmailConfirmation: false,
    );
    try {
      await _repo.signIn(email: email, password: password);
      final id = await _repo.getCurrentUserId();
      final userEmail = await _repo.getCurrentUserEmail();
      state = AuthState(
        userId: id,
        email: userEmail,
        isInitialized: true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
    }
  }

  Future<void> signUp(String email, String password) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      needsEmailConfirmation: false,
    );
    try {
      final response = await _repo.signUp(email: email, password: password);

      if (response.session != null && response.user != null) {
        // Email confirmation disabled — user is immediately signed in.
        // On localhost: auto-verify so the gating flow is skipped in dev.
        if (isDevMode) {
          try { await _repo.devAutoVerify(); } catch (_) { /* Dev-only auto-verify, non-critical */ }
        }
        state = AuthState(
          userId: response.user!.id,
          email: response.user!.email,
          isInitialized: true,
          isLoading: false,
        );
        return;
      }

      if (response.user != null && response.session == null) {
        // Email confirmation required — account created but not active yet.
        state = state.copyWith(
          isLoading: false,
          needsEmailConfirmation: true,
          clearError: true,
        );
        return;
      }

      // Supabase returned neither user nor session (unusual — treat as error).
      state = state.copyWith(
        isLoading: false,
        error: 'Sign-up failed. Please try again.',
      );
    } catch (e) {
      final msg = _friendlyError(e);
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.signOut();
      state = const AuthState(isInitialized: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (isMockMode) return AuthRepository();
  return AuthRepository(supabase: Supabase.instance.client);
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});
