import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/noble_mode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/feed_provider.dart';
import '../../providers/status_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/mode_provider.dart';
import '../../data/models/table_card.dart';
import '../../providers/table_provider.dart';
import '../../shared/widgets/mode_switcher.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../filters/filter_bottom_sheet.dart';
import '../match/match_found_screen.dart';
import '../match/mini_intro_screen.dart';
import '../social/group_chat_screen.dart';
import '../social/widgets/table_card_widget.dart';
import '../bff/bff_screen.dart';
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

    // Social mode → events feed
    if (mode == NobleMode.social) {
      return const SocialEventsScreen();
    }

    return Scaffold(
      backgroundColor: mode.bgTint,
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

class _Header extends StatelessWidget {
  final NobleMode mode;
  final int filterCount;

  const _Header({required this.mode, required this.filterCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            'N',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: mode.accentColor,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(child: ModeSwitcher()),
          const SizedBox(width: AppSpacing.sm),
          // Filter button with active badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                color: filterCount > 0 ? mode.accentColor : AppColors.textMuted,
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
                        style: const TextStyle(
                          color: AppColors.bg,
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
        child: SkeletonLoader(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.62,
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

  String get _message {
    switch (mode) {
      case NobleMode.date:
        return 'No more profiles today.\nCheck back tomorrow.';
      case NobleMode.bff:
        return 'You\'ve met everyone nearby.\nExpand your distance filter.';
      case NobleMode.social:
        return 'No events in your area right now.\nTry adjusting your filters.';
      case NobleMode.noblara:
        return 'No profiles to show.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mode.icon, color: mode.accentColor, size: 56),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
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

  void _onConnect(String cardId) {
    setState(() => _showHandshake = true);
    _hsCtrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _showHandshake = false);
    });
    ref.read(feedProvider.notifier).swipeRight(cardId);
  }

  @override
  Widget build(BuildContext context) {
    final topCard = widget.feed.cards.first;
    final mode = widget.mode;

    IconData centerIcon;
    switch (mode) {
      case NobleMode.date:
        centerIcon = Icons.favorite_rounded;
      case NobleMode.bff:
        centerIcon = Icons.handshake_rounded;
      case NobleMode.social:
        centerIcon = Icons.explore_rounded;
      case NobleMode.noblara:
        centerIcon = Icons.article_rounded;
    }

    final rewindsLeft =
        ref.watch(statusProvider).valueOrNull?.rewindsRemaining ?? 0;
    final canRewind =
        widget.feed.lastRemovedCard != null && rewindsLeft > 0;

    return Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Rewind
              Tooltip(
                message: rewindsLeft <= 0 ? 'No rewinds left' : '',
                child: _CircleButton(
                  icon: Icons.undo_rounded,
                  color: AppColors.warning,
                  size: 46,
                  onTap: canRewind
                      ? () => ref.read(feedProvider.notifier).rewind()
                      : null,
                ),
              ),
              // Pass
              _CircleButton(
                icon: Icons.close_rounded,
                color: AppColors.error,
                onTap: () =>
                    ref.read(feedProvider.notifier).swipeLeft(topCard.id),
              ),
              // Like / Connect
              _CircleButton(
                icon: centerIcon,
                color: mode.accentColor,
                size: 64,
                onTap: mode == NobleMode.bff
                    ? () => _onConnect(topCard.id)
                    : () =>
                        ref.read(feedProvider.notifier).swipeRight(topCard.id),
              ),
              // Signal (replaces Super Like)
              _CircleButton(
                icon: Icons.bolt_rounded,
                color: const Color(0xFF42A5F5),
                onTap: () => ref.read(feedProvider.notifier).sendSignal(topCard.id),
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
                    color: AppColors.gold,
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

// ---------------------------------------------------------------------------
// Social Table Feed
// ---------------------------------------------------------------------------

class _SocialFeed extends ConsumerStatefulWidget {
  final NobleMode mode;
  final int filterCount;

  const _SocialFeed({required this.mode, required this.filterCount});

  @override
  ConsumerState<_SocialFeed> createState() => _SocialFeedState();
}

class _SocialFeedState extends ConsumerState<_SocialFeed> {
  // Mock current user
  static const _userId = 'mock-golden-user-001';
  static const _userName = 'You';

  void _onJoin(String tableId) {
    final updated =
        ref.read(tableProvider.notifier).join(tableId, _userId, _userName);
    if (updated == null) {
      _showFullSheet(tableId);
      return;
    }
    // Navigate to group chat if 2+ members
    if (updated.currentCount >= 2) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GroupChatScreen(
            table: updated,
            currentUserId: _userId,
            currentUserName: _userName,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You joined "${updated.title}". Waiting for others… 🪑',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: widget.mode.accentColor,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showFullSheet(String tableId) {
    final tables = ref.read(tableProvider).tables;
    final table = tables.firstWhere(
      (t) => t.id == tableId,
      orElse: () => tables.first,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TableFullSheet(table: table, mode: widget.mode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tableState = ref.watch(tableProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(mode: widget.mode, filterCount: widget.filterCount),
            Expanded(
              child: tableState.isLoading
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xxxl),
                      child: SkeletonLoader(
                        width: double.infinity,
                        height: MediaQuery.of(context).size.height * 0.62,
                      ),
                    )
                  : _TableStack(
                      tables: tableState.tables,
                      userId: _userId,
                      onJoin: _onJoin,
                      onPass: (id) {}, // social pass = just skip, no action
                    ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _TableStack extends ConsumerStatefulWidget {
  final List<TableCard> tables;
  final String userId;
  final void Function(String) onJoin;
  final void Function(String) onPass;

  const _TableStack({
    required this.tables,
    required this.userId,
    required this.onJoin,
    required this.onPass,
  });

  @override
  ConsumerState<_TableStack> createState() => _TableStackState();
}

class _TableStackState extends ConsumerState<_TableStack> {
  int _topIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.tables.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(NobleMode.social.icon,
                color: NobleMode.social.accentColor, size: 56),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No tables tonight.\nCheck back soon.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    final visible = widget.tables
        .skip(_topIndex)
        .take(3)
        .toList()
        .reversed
        .toList();

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: visible.asMap().entries.map((entry) {
          final index = entry.key;
          final table = entry.value;
          final isTop = index == visible.length - 1;
          final scale = 1.0 - (visible.length - 1 - index) * 0.04;
          final yOffset = (visible.length - 1 - index) * -12.0;
          final tableCard = table;
          final hasJoined = ref
              .read(tableProvider.notifier)
              .hasJoined(tableCard.id, widget.userId);

          return Transform.translate(
            offset: Offset(0, yOffset),
            child: Transform.scale(
              scale: scale,
              child: SwipeableTableCard(
                table: tableCard,
                isTop: isTop,
                hasJoined: hasJoined,
                onJoin: () {
                  widget.onJoin(tableCard.id);
                  if (mounted) {
                    setState(() {
                      _topIndex =
                          (_topIndex + 1) % widget.tables.length;
                    });
                  }
                },
                onPass: () {
                  widget.onPass(tableCard.id);
                  if (mounted) {
                    setState(() {
                      _topIndex =
                          (_topIndex + 1) % widget.tables.length;
                    });
                  }
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TableFullSheet extends StatelessWidget {
  final TableCard table;
  final NobleMode mode;

  const _TableFullSheet({required this.table, required this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
        MediaQuery.of(context).padding.bottom + AppSpacing.xxl,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius:
                  BorderRadius.circular(AppSpacing.radiusCircle),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Icon(Icons.people_rounded, color: mode.accentColor, size: 48),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Table Full — Standing By',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: mode.accentColor,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This table is at capacity right now.\nIf a seat opens up, you\'ll be the first to know.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxxl),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: mode.accentColor,
              foregroundColor: AppColors.bg,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Browse Other Tables',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared circle button
// ---------------------------------------------------------------------------

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;

  const _CircleButton({
    required this.icon,
    required this.color,
    this.size = 52,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(
              color: disabled ? AppColors.border : color.withValues(alpha: 0.5)),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
        ),
        child: Icon(icon,
            color: disabled ? AppColors.textDisabled : color,
            size: size * 0.42),
      ),
    );
  }
}
