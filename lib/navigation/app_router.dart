import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/gating_provider.dart';
import '../providers/verification_provider.dart';
import '../features/auth/welcome_screen.dart';
import '../features/onboarding/onboarding_flow_screen.dart';
import '../features/verification/verification_hub_screen.dart';
import '../features/entry_gate/entry_gate_screen.dart';
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
//  7. verif ≠ approved                            → VerificationHubScreen
//       • idle / rejected / error → upload UI (shown by hub internally)
//       • manualReview / pending  → under-review UI (shown by hub internally)
//  8. !gating.isEntryApproved                     → EntryGateScreen
//  9. all clear                                   → MainTabNavigator
//
// Key invariants:
//  • gating.isVerified is NOT used — photo_verifications is the authority
//  • Bootstrap awaits profile + gating + verifications before routing
//  • User switch clears ALL three providers before re-bootstrapping
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
    final gating = ref.watch(gatingProvider);

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
      return _withDiag(
        const OnboardingFlowScreen(),
        auth: auth, profile: profile, verif: verif, gating: gating,
        route: 'onboarding',
      );
    }

    // ── 7. Verification (authoritative: photo_verifications table) ───────────
    //
    // approved         → fall through to entry gate / main app
    // manualReview     → VerificationHubScreen shows under-review UI
    // idle/rejected    → VerificationHubScreen shows upload UI
    // error            → VerificationHubScreen shows error + retry
    final verifStatus = verif.verificationStatus;
    if (verifStatus != VerificationStatus.approved) {
      return _withDiag(
        const VerificationHubScreen(),
        auth: auth, profile: profile, verif: verif, gating: gating,
        route: 'verification:${verifStatus.name}',
      );
    }

    // ── 8. Entry gate ────────────────────────────────────────────────────────
    if (!gating.isEntryApproved) {
      return _withDiag(
        const EntryGateScreen(),
        auth: auth, profile: profile, verif: verif, gating: gating,
        route: 'entry_gate',
      );
    }

    // ── 9. All clear ─────────────────────────────────────────────────────────
    return const MainTabNavigator();
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

  Widget _withDiag(
    Widget child, {
    required AuthState auth,
    required ProfileState profile,
    required VerificationState verif,
    required GatingState gating,
    required String route,
  }) {
    return child;
  }
}