import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';
import 'nob_compose_screen.dart';
import 'nob_drafts_screen.dart';

// ---------------------------------------------------------------------------
// NoblaraFeedScreen
// ---------------------------------------------------------------------------

class NoblaraFeedScreen extends ConsumerWidget {
  const NoblaraFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsState = ref.watch(postsProvider);
    final tierAsync = ref.watch(nobTierProvider);
    final currentUserId = ref.watch(authProvider).userId;

    final tier = tierAsync.maybeWhen(data: (t) => t, orElse: () => NobTier.observer);
    final canCompose = tier == NobTier.noble || tier == NobTier.explorer;

    return Scaffold(
      backgroundColor: AppColors.nobBackground,
      appBar: AppBar(
        backgroundColor: AppColors.nobBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: AppSpacing.xxl,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text(
              'N O B L A R A',
              style: TextStyle(
                color: AppColors.noblaraGold,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _TierBadge(tier: tier),
          ],
        ),
        actions: [
          if (canCompose)
            IconButton(
              icon: const Icon(Icons.drafts_outlined,
                  color: AppColors.nobObserver, size: 20),
              tooltip: 'Drafts',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NobDraftsScreen())),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.nobObserver, size: 20),
            onPressed: () => ref.read(postsProvider.notifier).refresh(),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppColors.nobBorder,
          ),
        ),
      ),
      floatingActionButton: canCompose
          ? _ComposeFab(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NobComposeScreen()),
              ),
            )
          : null,
      body: RefreshIndicator(
        color: AppColors.noblaraGold,
        backgroundColor: AppColors.nobSurface,
        onRefresh: () => ref.read(postsProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            // Observer banner
            if (!canCompose)
              const SliverToBoxAdapter(child: _ObserverBanner()),

            // Error
            if (postsState.error != null)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(
                      AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.2)),
                  ),
                  child: Text(postsState.error!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 12)),
                ),
              ),

            // Loading shimmer
            if (postsState.isLoading && postsState.posts.isEmpty)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => const _ShimmerCard(),
                  childCount: 4,
                ),
              )
            else if (!postsState.isLoading && postsState.posts.isEmpty)
              const SliverFillRemaining(child: _EmptyState())

            // Posts
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final post = postsState.posts[i];
                    return _NobCard(
                      post: post,
                      currentUserId: currentUserId,
                      onReact: (type) =>
                          ref.read(postsProvider.notifier).react(post.id, type),
                      onPin: currentUserId == post.userId
                          ? () => ref
                              .read(postsProvider.notifier)
                              .togglePin(post.id, !post.isPinned)
                          : null,
                      onArchive: currentUserId == post.userId
                          ? () => ref
                              .read(postsProvider.notifier)
                              .archivePost(post.id)
                          : null,
                      onDelete: currentUserId == post.userId
                          ? () => ref
                              .read(postsProvider.notifier)
                              .deletePost(post.id)
                          : null,
                    );
                  },
                  childCount: postsState.posts.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compose FAB
// ---------------------------------------------------------------------------

class _ComposeFab extends StatelessWidget {
  final VoidCallback onTap;
  const _ComposeFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        decoration: BoxDecoration(
          color: AppColors.noblaraGold,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
          boxShadow: [
            BoxShadow(
              color: AppColors.noblaraGold.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined, size: 16, color: AppColors.nobBackground),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Write a Nob',
              style: TextStyle(
                color: AppColors.nobBackground,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Observer banner
// ---------------------------------------------------------------------------

class _ObserverBanner extends StatelessWidget {
  const _ObserverBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.nobSurfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.nobBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.nobObserver,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Text(
            'Observer — read and react only',
            style: TextStyle(
              color: AppColors.nobObserver,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.nobSurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.nobBorder),
            ),
            child: const Icon(Icons.article_outlined,
                color: AppColors.nobObserver, size: 24),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'No Nobs yet.',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Be the first to share a thought.',
            style: TextStyle(color: AppColors.nobObserver, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer placeholder card
// ---------------------------------------------------------------------------

class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard();

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.fromLTRB(
            AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: AppColors.nobSurface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.nobBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _shimmerBox(28, 28, circle: true),
                const SizedBox(width: AppSpacing.md),
                _shimmerBox(80, 10),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _shimmerBox(double.infinity, 10),
            const SizedBox(height: AppSpacing.sm),
            _shimmerBox(double.infinity, 10),
            const SizedBox(height: AppSpacing.sm),
            _shimmerBox(160, 10),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox(double w, double h, {bool circle = false}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.nobSurfaceAlt.withValues(alpha: _anim.value),
        borderRadius: circle
            ? BorderRadius.circular(AppSpacing.radiusCircle)
            : BorderRadius.circular(4),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tier badge (header)
// ---------------------------------------------------------------------------

class _TierBadge extends StatelessWidget {
  final NobTier tier;
  const _TierBadge({required this.tier});

  Color get _color {
    switch (tier) {
      case NobTier.noble:
        return AppColors.nobNoble;
      case NobTier.explorer:
        return AppColors.nobExplorer;
      case NobTier.observer:
        return AppColors.nobObserver;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _color.withValues(alpha: 0.25)),
      ),
      child: Text(
        tier.label.toUpperCase(),
        style: TextStyle(
          color: _color,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nob card
// ---------------------------------------------------------------------------

class _NobCard extends StatelessWidget {
  final Post post;
  final String? currentUserId;
  final ValueChanged<String> onReact;
  final VoidCallback? onPin;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  const _NobCard({
    required this.post,
    required this.currentUserId,
    required this.onReact,
    this.onPin,
    this.onArchive,
    this.onDelete,
  });

  Color get _tierColor {
    switch (post.authorTier) {
      case NobTier.noble:
        return AppColors.nobNoble;
      case NobTier.explorer:
        return AppColors.nobExplorer;
      case NobTier.observer:
        return AppColors.nobObserver;
    }
  }

  @override
  Widget build(BuildContext context) {
    final myReaction =
        currentUserId != null ? post.myReaction(currentUserId!) : null;
    final isOwn = currentUserId == post.userId;

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0),
      decoration: BoxDecoration(
        color: AppColors.nobSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: post.isPinned
              ? AppColors.noblaraGold.withValues(alpha: 0.35)
              : AppColors.nobBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Noble left accent bar
          if (post.authorTier == NobTier.noble)
            Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.noblaraGold.withValues(alpha: 0.8),
                    AppColors.noblaraGold.withValues(alpha: 0),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.radiusMd)),
              ),
            ),

          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.xs, 0),
            child: Row(
              children: [
                if (post.isPinned) ...[
                  const Icon(Icons.push_pin_rounded,
                      color: AppColors.noblaraGold, size: 11),
                  const SizedBox(width: AppSpacing.xs),
                ],
                // Avatar
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _tierColor.withValues(alpha: 0.15),
                    border: Border.all(
                        color: _tierColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: post.authorAvatarUrl != null
                      ? ClipOval(
                          child: Image.network(post.authorAvatarUrl!,
                              fit: BoxFit.cover))
                      : Center(
                          child: Text(
                            (post.authorName ?? 'N')[0].toUpperCase(),
                            style: TextStyle(
                              color: _tierColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName ?? 'Noblara',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          letterSpacing: 0.1,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _ago(post.publishedAt ?? post.createdAt),
                            style: const TextStyle(
                                color: AppColors.nobObserver, fontSize: 10),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            width: 2,
                            height: 2,
                            decoration: const BoxDecoration(
                              color: AppColors.nobBorder,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: _tierColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              post.authorTier.label.toUpperCase(),
                              style: TextStyle(
                                color: _tierColor,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isOwn)
                  _OwnerMenu(
                      post: post,
                      onPin: onPin,
                      onArchive: onArchive,
                      onDelete: onDelete),
              ],
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          if (post.isThought && post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
              child: Text(
                post.content,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  height: 1.65,
                  letterSpacing: 0.15,
                ),
              ),
            ),

          if (post.isMoment) ...[
            if (post.photoUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.lg),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: Image.network(
                    post.photoUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      color: AppColors.nobSurfaceAlt,
                      child: const Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            color: AppColors.nobObserver, size: 28),
                      ),
                    ),
                  ),
                ),
              ),
            if (post.caption != null && post.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                child: Text(
                  post.caption!,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.55,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
          ],

          // ── Reactions — no counts ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
            child: Row(
              children: [
                _ReactionBtn(
                  emoji: '👋',
                  type: 'appreciate',
                  isActive: myReaction?.reactionType == 'appreciate',
                  onTap: () => onReact('appreciate'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _ReactionBtn(
                  emoji: '🤝',
                  type: 'support',
                  isActive: myReaction?.reactionType == 'support',
                  onTap: () => onReact('support'),
                ),
                const SizedBox(width: AppSpacing.sm),
                _ReactionBtn(
                  emoji: '✕',
                  type: 'pass',
                  isActive: myReaction?.reactionType == 'pass',
                  isSubtle: true,
                  onTap: () => onReact('pass'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return DateFormat('d MMM').format(dt);
  }
}

// ---------------------------------------------------------------------------
// Owner context menu
// ---------------------------------------------------------------------------

class _OwnerMenu extends StatelessWidget {
  final Post post;
  final VoidCallback? onPin;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  const _OwnerMenu({
    required this.post,
    this.onPin,
    this.onArchive,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded,
          color: AppColors.nobObserver, size: 18),
      color: AppColors.nobSurfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        side: const BorderSide(color: AppColors.nobBorder),
      ),
      onSelected: (val) {
        if (val == 'pin' && onPin != null) onPin!();
        if (val == 'archive' && onArchive != null) onArchive!();
        if (val == 'delete' && onDelete != null) onDelete!();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'pin',
          child: Row(
            children: [
              Icon(
                post.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
                color: AppColors.noblaraGold,
                size: 15,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                post.isPinned ? 'Unpin' : 'Pin to top',
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'archive',
          child: const Row(
            children: [
              Icon(Icons.archive_outlined,
                  color: AppColors.nobObserver, size: 15),
              SizedBox(width: AppSpacing.sm),
              Text('Archive',
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: const Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  color: AppColors.error, size: 15),
              SizedBox(width: AppSpacing.sm),
              Text('Delete',
                  style: TextStyle(color: AppColors.error, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reaction button — emoji only, no count
// ---------------------------------------------------------------------------

class _ReactionBtn extends StatelessWidget {
  final String emoji;
  final String type;
  final bool isActive;
  final bool isSubtle;
  final VoidCallback onTap;

  const _ReactionBtn({
    required this.emoji,
    required this.type,
    required this.isActive,
    required this.onTap,
    this.isSubtle = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor =
        isSubtle ? AppColors.nobObserver : AppColors.noblaraGold;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.35)
                : AppColors.nobBorder,
          ),
        ),
        child: Text(
          emoji,
          style: TextStyle(
            fontSize: 14,
            color: isActive ? null : Colors.white.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }
}
