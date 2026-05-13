import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/noble_mode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/premium.dart';
import '../../core/utils/country_support.dart';
import '../../providers/feed_provider.dart';
import '../../providers/interaction_gate_provider.dart';
import '../../providers/note_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/profile_provider.dart';
import '../../core/services/toast_service.dart';
import '../../providers/mode_provider.dart';
import '../../shared/widgets/mode_switcher.dart';
import '../../shared/widgets/premium_skeleton.dart';
import '../../widgets/locked_swipe_banner.dart';
import '../profile/edit/sections/travel_mode_section.dart';
import '../filters/filter_bottom_sheet.dart';
import '../match/match_found_screen.dart';
import '../match/mini_intro_screen.dart';
import 'swipe_card_widget.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(modeProvider);
    final feed = ref.watch(feedProvider);

    // Reload feed when mode changes
    ref.listen<NobleMode>(modeProvider, (prev, next) {
      if (prev != next) ref.read(feedProvider.notifier).loadFeed(next);
    });

    // Show match found overlay when a new match is detected
    if (feed.newMatch != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(feedProvider.notifier).clearNewMatch();
        final match = feed.newMatch!;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchFoundScreen(
              match: match,
              onContinue: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MiniIntroScreen(match: match),
                  ),
                );
              },
            ),
          ),
        );
      });
    }
    final filterCount =
        ref.watch(filterProvider.select((f) => f.activeCount(mode)));

    // R18 — BFF dedicated screen branch removed (BFF pulled from V1).

    // R13 — country gate state for the locked-swipe banner. The same
    // predicate is mirrored on the backend in `create_swipe_with_gate`
    // (migration 20260510000004); changes to one must be reflected in
    // the other (drift = silent UX desync).
    final profile = ref.watch(profileProvider).profile;
    final canRegion = CountrySupport.isUserActiveInRegion(
      country: profile?.country,
      travelMode: profile?.travelMode ?? false,
      travelCountry: profile?.travelCountry,
    );

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _Header(mode: mode, filterCount: filterCount),
            if (!canRegion)
              LockedSwipeBanner(
                onActivate: () {
                  // R13 — open the Travel Mode section directly so the
                  // user can flip the toggle + pick a TH/VN/PH city
                  // without hunting through Edit Profile sections.
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TravelModeSection(),
                    ),
                  );
                },
              ),
            Expanded(
              child: _FeedBody(
                feed: feed,
                mode: mode,
                onSwipeRight: (id) {
                  final gate = ref.read(interactionGateProvider).valueOrNull ?? InteractionGate.loading;
                  if (!gate.canInteract(mode.name)) return;
                  // R13 — country gate (right-swipe only; left-swipe is
                  // a pass and unaffected). Mirrors backend RPC logic.
                  if (!canRegion) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Activate travel mode to like profiles',
                        ),
                      ),
                    );
                    return;
                  }
                  ref.read(feedProvider.notifier).swipeRight(id);
                },
                onSwipeLeft: (id) =>
                    ref.read(feedProvider.notifier).swipeLeft(id),
                onRetry: () =>
                    ref.read(feedProvider.notifier).loadFeed(),
              ),
            ),
            if (feed.cards.isNotEmpty)
              _ActionRow(feed: feed, mode: mode),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends ConsumerWidget {
  final NobleMode mode;
  final int filterCount;

  const _Header({required this.mode, required this.filterCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.burgundy600,
              shape: BoxShape.circle,
              boxShadow: Premium.shadowSm,
            ),
            alignment: Alignment.center,
            child: const Text(
              'N',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: ModeSwitcher()),
          // Filter button with active badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                color: filterCount > 0 ? mode.accentColor : context.textMuted,
                onPressed: () => FilterBottomSheet.show(context),
                style: IconButton.styleFrom(
                  backgroundColor:
                      filterCount > 0 ? mode.accentLight : Colors.transparent,
                ),
              ),
              if (filterCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: mode.accentColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$filterCount',
                        style: TextStyle(
                          color: context.bgColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feed body
// ---------------------------------------------------------------------------

class _FeedBody extends StatelessWidget {
  final FeedState feed;
  final NobleMode mode;
  final void Function(String) onSwipeRight;
  final void Function(String) onSwipeLeft;
  final VoidCallback? onRetry;

  const _FeedBody({
    required this.feed,
    required this.mode,
    required this.onSwipeRight,
    required this.onSwipeLeft,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (feed.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: PremiumSkeleton(
          height: MediaQuery.of(context).size.height * 0.66,
          radius: AppSpacing.radiusXl,
        ),
      );
    }

    if (feed.error != null && feed.cards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48, color: context.textDisabled),
              const SizedBox(height: AppSpacing.lg),
              Text('Could not load profiles',
                  style: TextStyle(color: context.textMuted, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.sm),
              Text('Check your connection and try again',
                  style: TextStyle(color: context.textDisabled, fontSize: 13)),
              const SizedBox(height: AppSpacing.xxl),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: TextButton.styleFrom(foregroundColor: AppColors.emerald500),
              ),
            ],
          ),
        ),
      );
    }

    if (feed.isEmpty) {
      return _EmptyDeck(mode: mode);
    }

    final visible = feed.cards.take(3).toList().reversed.toList();

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: visible.asMap().entries.map((entry) {
          final index = entry.key;
          final card = entry.value;
          final isTop = index == visible.length - 1;
          final scale = 1.0 - (visible.length - 1 - index) * 0.04;
          final yOffset = (visible.length - 1 - index) * -12.0;

          return Transform.translate(
            offset: Offset(0, yOffset),
            child: Transform.scale(
              scale: scale,
              child: SwipeCardWidget(
                card: card,
                isTop: isTop,
                mode: mode,
                onSwipeRight: () => onSwipeRight(card.id),
                onSwipeLeft: () => onSwipeLeft(card.id),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyDeck extends StatelessWidget {
  final NobleMode mode;
  const _EmptyDeck({required this.mode});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          decoration: Premium.emptyStateDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.emerald600.withValues(alpha: 0.12),
                      AppColors.emerald600.withValues(alpha: 0.04),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.emerald600.withValues(alpha: 0.15),
                    width: 0.5,
                  ),
                ),
                child: Icon(Icons.favorite_outline_rounded,
                    color: AppColors.emerald600.withValues(alpha: 0.5), size: 28),
              ),
              const SizedBox(height: 24),
              Text('All caught up',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  )),
              const SizedBox(height: 8),
              Text(
                'Check back soon — new people\njoin every day',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action row (swipe buttons) — BFF mode shows handshake animation on connect
// ---------------------------------------------------------------------------

class _ActionRow extends ConsumerStatefulWidget {
  final FeedState feed;
  final NobleMode mode;

  const _ActionRow({required this.feed, required this.mode});

  @override
  ConsumerState<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends ConsumerState<_ActionRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _hsCtrl;
  late Animation<double> _hsScale;
  late Animation<double> _hsFade;
  // R18 — `_showHandshake` is only set in the deleted `_onConnect`
  // (BFF action). With BFF removed, the handshake animation never
  // triggers; kept as `final false` to avoid touching the renderer
  // (which still has an `if (_showHandshake)` gated AnimatedBuilder).
  // Dead-render cleanup is V1.x refactor scope.
  final bool _showHandshake = false;

  @override
  void initState() {
    super.initState();
    _hsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
    _hsScale = Tween<double>(begin: 0.4, end: 2.2).animate(
      CurvedAnimation(parent: _hsCtrl, curve: Curves.easeOut),
    );
    _hsFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _hsCtrl,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _hsCtrl.dispose();
    super.dispose();
  }

  void _showNoteDialog(BuildContext context, String targetUserId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: Premium.dialogShape(),
        title: Text('Send a Note', style: TextStyle(color: context.textPrimary, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          maxLength: 280,
          maxLines: 3,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            hintText: 'Write something thoughtful...',
            hintStyle: TextStyle(color: context.textMuted),
            filled: true, fillColor: context.bgColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: context.textMuted))),
          TextButton(
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ref.read(noteInboxProvider.notifier).sendNote(
                  receiverId: targetUserId,
                  targetType: 'profile',
                  targetId: targetUserId,
                  content: text,
                );
                if (ctx.mounted) ToastService.show(ctx, message: 'Note sent', type: ToastType.success);
              } catch (e) {
                if (ctx.mounted) ToastService.show(ctx, message: 'Could not send note', type: ToastType.error);
              }
            },
            child: const Text('Send', style: TextStyle(color: AppColors.emerald600)),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }

  // R18 — `_onConnect` removed (was BFF-only swipe-right action). Date
  // swipe right goes through `feedProvider.swipeRight` directly in
  // `_ActionRow.onTap`.

  /// Check gating before allowing an interaction action
  bool _checkGate(BuildContext context, String mode) {
    final gate = ref.read(interactionGateProvider).valueOrNull ?? InteractionGate.loading;
    if (gate.canInteract(mode)) return true;
    showGatingPopup(context, 'Add a photo first',
        'Upload at least one photo to start connecting with people.');
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.feed.cards.isEmpty) return const SizedBox.shrink();
    final topCard = widget.feed.cards.first;
    final mode = widget.mode;

    return Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Pass
              PressEffect(
                onTap: () =>
                    ref.read(feedProvider.notifier).swipeLeft(topCard.id),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.borderStrong,
                      width: 1.0,
                    ),
                    boxShadow: Premium.shadowMd,
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary, size: 24),
                ),
              ),
              // Note (GATED) — R23: Signal else branch was unreachable in V1
              // (only NobleMode.date is constructible) so the `else` arm and
              // its sendSignal call were removed along with the Signal feature.
              PressEffect(
                onTap: () {
                  if (_checkGate(context, mode.name)) {
                    _showNoteDialog(context, topCard.id);
                  }
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.emerald500.withValues(alpha: 0.20),
                      width: 0.5,
                    ),
                    boxShadow: [
                      ...Premium.shadowMd,
                      BoxShadow(
                        color: AppColors.emerald500.withValues(alpha: 0.06),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      color: AppColors.emerald500, size: 22),
                ),
              ),
              // Connect / Like (GATED) — HERO CTA
              PressEffect(
                scale: 0.92,
                // R18 — BFF connect branch removed; date swipe is the
                // only Discover action.
                onTap: () { if (_checkGate(context, 'date')) ref.read(feedProvider.notifier).swipeRight(topCard.id); },
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.emerald500,
                        AppColors.emerald600,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: Premium.emeraldGlow(intensity: 1.2),
                  ),
                  child: const Icon(Icons.favorite_rounded,
                      color: AppColors.textOnEmerald, size: 28),
                ),
              ),
            ],
          ),
        ),
        // Gold handshake burst — BFF connect animation
        if (_showHandshake)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _hsCtrl,
              builder: (_, __) => Opacity(
                opacity: _hsFade.value,
                child: Transform.scale(
                  scale: _hsScale.value,
                  child: const Icon(
                    Icons.handshake_rounded,
                    color: AppColors.emerald600,
                    size: 52,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
