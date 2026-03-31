import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/gating_provider.dart';
import '../providers/verification_provider.dart';
import '../features/auth/welcome_screen.dart';
import '../features/onboarding/profile_basics_screen.dart';
import '../features/onboarding/gender_selection_screen.dart';
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
    debugPrint('[Router] bootstrap start — user $userId');

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
      debugPrint('[Router] zombie session detected — signing out');
      _bootstrapping = false;
      await ref.read(authProvider.notifier).signOut();
      return;
    }

    setState(() {
      _bootstrappedUserId = userId;
      _bootstrapping = false;
    });

    _logRoute();
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

  void _logRoute() {
    final auth = ref.read(authProvider);
    final profile = ref.read(profileProvider);
    final verif = ref.read(verificationProvider);
    final gating = ref.read(gatingProvider);
    debugPrint(
      '[Router] — '
      'userId=${auth.userId} '
      'profileFound=${profile.profile != null} '
      'displayName="${profile.profile?.displayName}" '
      'hasProfile=${profile.hasProfile} '
      'gender="${profile.profile?.gender}" '
      'hasGender=${profile.hasGender} '
      'verifStatus=${verif.verificationStatus.name} '
      'isEntryApproved=${gating.isEntryApproved}',
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── User-change listener ─────────────────────────────────────────────────
    // Clears ALL cached state and re-bootstraps whenever the logged-in user
    // changes (sign-out, sign-in as a different account, session expiry).
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.userId == next.userId) return;
      debugPrint('[Router] user changed ${prev?.userId} → ${next.userId}');
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

    // ── 5. Profile missing or incomplete ─────────────────────────────────────
    if (!profile.hasProfile) {
      return _withDiag(
        const ProfileBasicsScreen(),
        auth: auth, profile: profile, verif: verif, gating: gating,
        route: 'onboarding',
      );
    }

    // ── 6. Gender not declared ────────────────────────────────────────────────
    // Must come after hasProfile so profile row exists to update.
    if (!profile.hasGender) {
      return _withDiag(
        const GenderSelectionScreen(),
        auth: auth, profile: profile, verif: verif, gating: gating,
        route: 'gender_selection',
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
    return Stack(
      children: [
        child,
        Positioned(
          top: MediaQuery.of(context).padding.top + 4,
          right: 8,
          child: _DiagBadge(
            userId: auth.userId,
            profileFound: profile.profile != null,
            fullName: profile.profile?.displayName,
            profileError: profile.error,
            verifStatus: verif.verificationStatus.name,
            verifError: verif.error,
            isEntryApproved: gating.isEntryApproved,
            route: route,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Diagnostics badge — tap to expand; remove before shipping
// ---------------------------------------------------------------------------

class _DiagBadge extends StatefulWidget {
  final String? userId;
  final bool profileFound;
  final String? fullName;
  final String? profileError;
  final String verifStatus;
  final String? verifError;
  final bool isEntryApproved;
  final String route;

  const _DiagBadge({
    required this.userId,
    required this.profileFound,
    required this.fullName,
    required this.profileError,
    required this.verifStatus,
    required this.verifError,
    required this.isEntryApproved,
    required this.route,
  });

  @override
  State<_DiagBadge> createState() => _DiagBadgeState();
}

class _DiagBadgeState extends State<_DiagBadge> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: _expanded ? _expanded_() : _collapsed_(),
      ),
    );
  }

  Widget _collapsed_() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bug_report,
              color: AppColors.gold.withValues(alpha: 0.7), size: 13),
          const SizedBox(width: 4),
          Text('DBG',
              style: TextStyle(
                  color: AppColors.gold.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ],
      );

  Widget _expanded_() {
    final rows = <(String, String)>[
      ('session', widget.userId != null ? 'yes' : 'NO'),
      ('userId', _short(widget.userId)),
      ('profileFound', widget.profileFound ? 'yes' : 'NO'),
      ('fullName',
          widget.fullName?.isNotEmpty == true ? widget.fullName! : '(empty)'),
      if (widget.profileError != null) ('profileErr', widget.profileError!),
      ('verifStatus', widget.verifStatus),
      if (widget.verifError != null) ('verifError', widget.verifError!),
      ('entryApproved', widget.isEntryApproved ? 'yes' : 'NO'),
      ('→ route', widget.route),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bug_report, color: AppColors.gold, size: 12),
          const SizedBox(width: 4),
          const Text('ROUTER',
              style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        ...rows.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                  children: [
                    TextSpan(
                        text: '${r.$1}: ',
                        style: const TextStyle(color: AppColors.textMuted)),
                    TextSpan(
                        text: r.$2,
                        style: const TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  String _short(String? s) {
    if (s == null) return 'null';
    return s.length <= 8 ? s : '${s.substring(0, 8)}…';
  }
}
