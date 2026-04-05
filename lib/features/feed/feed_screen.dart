import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/noble_mode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/premium.dart';
import '../../core/utils/mock_mode.dart';
import '../../providers/feed_provider.dart';
import '../../providers/interaction_gate_provider.dart';
import '../../providers/note_provider.dart';
import '../../providers/filter_provider.dart';
import '../../core/services/toast_service.dart';
import '../../providers/mode_provider.dart';
import '../../shared/widgets/mode_switcher.dart';
import '../../shared/widgets/premium_skeleton.dart';
import '../filters/filter_bottom_sheet.dart';
import '../match/match_found_screen.dart';
import '../match/mini_intro_screen.dart';
import '../bff/bff_screen.dart';
import '../../navigation/main_tab_navigator.dart';
import '../social/social_events_screen.dart';
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

    // BFF mode → dedicated BFF suggestion screen
    if (mode == NobleMode.bff) {
      return const BffScreen();
    }

    // Social mode → events feed (only when Social layer is enabled).
    // If the user's saved mode is 'social' but the feature is off, we fall
    // through to the default Date feed below.
    if (kSocialEnabled && mode == NobleMode.social) {
      return const SocialEventsScreen();
    }

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _Header(mode: mode, filterCount: filterCount),
            Expanded(
              child: _FeedBody(
                feed: feed,
                mode: mode,
                onSwipeRight: (id) =>
                    ref.read(feedProvider.notifier).swipeRight(id),
                onSwipeLeft: (id) =>
                    ref.read(feedProvider.notifier).swipeLeft(id),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Row(
        children: [
          const Text(
            'N',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.emerald600,
              fontFamily: 'serif',
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

  const _FeedBody({
    required this.feed,
    required this.mode,
    required this.onSwipeRight,
    required this.onSwipeLeft,
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
              const SizedBox(height: 28),
              PressEffect(
                onTap: () => MainTabNavigator.switchTab(1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.emerald600.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
                    border: Border.all(
                      color: AppColors.emerald600.withValues(alpha: 0.25),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_outlined,
                          color: AppColors.emerald600, size: 16),
                      const SizedBox(width: 8),
                      Text('Explore Nob Feed',
                          style: TextStyle(
                            color: AppColors.emerald600,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
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
  bool _showHandshake = false;

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
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              ref.read(noteInboxProvider.notifier).sendNote(
                receiverId: targetUserId,
                targetType: 'profile',
                targetId: targetUserId,
                content: text,
              );
              ToastService.show(context, message: 'Note sent', type: ToastType.success);
            },
            child: const Text('Send', style: TextStyle(color: AppColors.emerald600)),
          ),
        ],
      ),
    );
  }

  void _onConnect(String cardId) {
    setState(() => _showHandshake = true);
    _hsCtrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _showHandshake = false);
    });
    ref.read(feedProvider.notifier).swipeRight(cardId);
  }

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
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                    boxShadow: Premium.shadowMd,
                  ),
                  child: Icon(Icons.close_rounded,
                      color: AppColors.textSecondary, size: 24),
                ),
              ),
              // Signal / Note (GATED)
              PressEffect(
                onTap: () {
                  if (_checkGate(context, mode.name)) {
                    if (mode == NobleMode.date) {
                      _showNoteDialog(context, topCard.id);
                    } else {
                      ref.read(feedProvider.notifier).sendSignal(topCard.id);
                    }
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
                onTap: mode == NobleMode.bff
                    ? () { if (_checkGate(context, 'bff')) _onConnect(topCard.id); }
                    : () { if (_checkGate(context, 'date')) ref.read(feedProvider.notifier).swipeRight(topCard.id); },
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
