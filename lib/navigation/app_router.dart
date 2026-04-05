import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/gating_provider.dart';
import '../providers/verification_provider.dart';
import '../features/auth/welcome_screen.dart';
import '../features/onboarding/onboarding_flow_screen.dart';
import 'main_tab_navigator.dart';

// ---------------------------------------------------------------------------
// AppRouter — single authoritative startup state machine
// ---------------------------------------------------------------------------
//
// Route order (evaluated top-to-bottom on every state change):
//
//  1. !auth.isInitialized                        → splash (Supabase init)
//  2. !auth.isAuthenticated                       → WelcomeScreen
//  3. bootstrap pending for this userId           → splash (loading data)
//  4. verifications still loading                 → splash (loading data)
//  5. profile missing OR display_name empty       → ProfileBasicsScreen
//  6. profile.gender not set                      → GenderSelectionScreen
//  7. all clear                                   → MainTabNavigator
//
// Access model:
//  • Noblara is the open expression layer — reachable once basic profile
//    (display_name + gender) is complete. Verification and entry-gate are
//    NOT blockers for Noblara.
//  • Dating / BFF / DM / Chats stay behind the existing security model:
//    MainTabNavigator guards the Discover & Chats tabs, redirecting to
//    VerificationHub / EntryGate when verification or entry approval is
//    still missing. See main_tab_navigator.dart.
//
// Key invariants:
//  • Bootstrap awaits profile + gating + verifications before routing
//  • User switch clears ALL three providers before re-bootstrapping
//  • verification + entry-gate state is still loaded, just enforced
//    per-surface inside MainTabNavigator instead of at router level
// ---------------------------------------------------------------------------

class AppRouter extends ConsumerStatefulWidget {
  const AppRouter({super.key});

  @override
  ConsumerState<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends ConsumerState<AppRouter> {
  String? _bootstrappedUserId;
  bool _bootstrapping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBootstrap());
  }

  Future<void> _maybeBootstrap() async {
    if (!mounted) return;
    if (_bootstrapping) return;

    final userId = ref.read(authProvider).userId;
    if (userId == null) return;
    if (_bootstrappedUserId == userId) return;

    _bootstrapping = true;
    // bootstrap start

    // Load all three data sources in parallel before making any route decision.
    await Future.wait([
      ref.read(profileProvider.notifier).loadProfile(),
      ref.read(gatingProvider.notifier).loadStatus(),
      ref.read(verificationProvider.notifier).load(),
    ]);

    if (!mounted) {
      _bootstrapping = false;
      return;
    }

    // ── Zombie Session Guard ──────────────────────────────────────────────────
    // If profile AND gating both failed with an auth-related error
    // (e.g. 401 / JWT expired / not authenticated), the session token is
    // broken.  Force sign-out so the user lands cleanly on WelcomeScreen.
    final profileErr = ref.read(profileProvider).error ?? '';
    final gatingErr  = ref.read(gatingProvider).error ?? '';
    final looksLikeAuthError = _isAuthError(profileErr) || _isAuthError(gatingErr);

    if (looksLikeAuthError &&
        ref.read(profileProvider).profile == null) {
      // zombie session — sign out
      _bootstrapping = false;
      await ref.read(authProvider.notifier).signOut();
      return;
    }

    setState(() {
      _bootstrappedUserId = userId;
      _bootstrapping = false;
    });

  }

  static bool _isAuthError(String msg) {
    final m = msg.toLowerCase();
    return m.contains('401') ||
        m.contains('403') ||
        m.contains('jwt') ||
        m.contains('not authenticated') ||
        m.contains('unauthorized') ||
        m.contains('invalid token');
  }

  @override
  Widget build(BuildContext context) {
    // ── User-change listener ─────────────────────────────────────────────────
    // Clears ALL cached state and re-bootstraps whenever the logged-in user
    // changes (sign-out, sign-in as a different account, session expiry).
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.userId == next.userId) return;
      // user changed
      setState(() {
        _bootstrappedUserId = null;
        _bootstrapping = false;
      });
      ref.read(profileProvider.notifier).clear();
      ref.read(gatingProvider.notifier).clear();
      ref.read(verificationProvider.notifier).clear();
      if (next.userId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBootstrap());
      }
    });

    final auth = ref.watch(authProvider);
    final profile = ref.watch(profileProvider);
    final verif = ref.watch(verificationProvider);

    // ── 1. Supabase initializing ─────────────────────────────────────────────
    if (!auth.isInitialized) {
      return _splash('initializing…');
    }

    // ── 2. No session ────────────────────────────────────────────────────────
    if (!auth.isAuthenticated) {
      return const WelcomeScreen();
    }

    // ── 3. Bootstrap pending ─────────────────────────────────────────────────
    if (_bootstrappedUserId != auth.userId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBootstrap());
      return _splash('loading…');
    }

    // ── 4. Verifications still loading (bootstrap fetch in flight) ───────────
    if (verif.isLoading) {
      return _splash('loading verifications…');
    }

    // ── 5+6. Profile not complete → full onboarding flow ───────────────────
    if (!profile.hasProfile || !profile.hasGender) {
      return const OnboardingFlowScreen();
    }

    // ── 7. All clear ─────────────────────────────────────────────────────────
    //
    // Verification and entry-gate are intentionally NOT blocking here.
    // Noblara is reachable once basic profile is complete; Discover / Chats
    // remain gated inside MainTabNavigator per the existing security model.
    return MainTabNavigator(key: MainTabNavigator.navigatorKey);
  }

  Widget _splash(String reason) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(reason,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

}