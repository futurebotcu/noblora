import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';
import '../../providers/note_provider.dart';
import 'nob_compose_screen.dart';
import 'nob_drafts_screen.dart';
import 'note_inbox_screen.dart';

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
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
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
          IconButton(
            icon: Icon(Icons.mail_outline_rounded,
                color: context.textMuted, size: 20),
            tooltip: 'Notes',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NoteInboxScreen())),
          ),
          if (canCompose)
            IconButton(
              icon: Icon(Icons.drafts_outlined,
                  color: context.textMuted, size: 20),
              tooltip: 'Drafts',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NobDraftsScreen())),
            ),
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: context.textMuted, size: 20),
            onPressed: () => ref.read(postsProvider.notifier).refresh(),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: context.borderColor,
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
        backgroundColor: context.surfaceColor,
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

            // Filter bar
            SliverToBoxAdapter(child: _NobFilterBar(state: postsState, ref: ref)),

            // Loading shimmer
            if (postsState.isLoading && postsState.posts.isEmpty)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => const _ShimmerCard(),
                  childCount: 4,
                ),
              )
            else if (!postsState.isLoading && postsState.posts.isEmpty)
              const SliverFillRemaining(hasScrollBody: false, child: _EmptyState())

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
                      onSendNote: (receiverId, targetType, targetId, content) {
                        ref.read(noteInboxProvider.notifier).sendNote(
                          receiverId: receiverId,
                          targetType: targetType,
                          targetId: targetId,
                          content: content,
                        );
                      },
                      onSignal: (targetUserId) {
                        ref.read(postsProvider.notifier).sendSignalFromNob(targetUserId);
                      },
                      onReachOut: (targetUserId) {
                        ref.read(postsProvider.notifier).sendReachOutFromNob(targetUserId);
                      },
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined, size: 16, color: context.bgColor),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Write a Nob',
              style: TextStyle(
                color: context.bgColor,
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
        color: context.surfaceAltColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: context.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Observer — read and react only',
            style: TextStyle(
              color: context.textMuted,
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
              color: context.surfaceColor,
              shape: BoxShape.circle,
              border: Border.all(color: context.borderColor),
            ),
            child: Icon(Icons.article_outlined,
                color: context.textMuted, size: 24),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No Nobs yet.',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Be the first to share a thought.',
            style: TextStyle(color: context.textMuted, fontSize: 13),
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
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: context.borderColor),
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
        color: context.surfaceAltColor.withValues(alpha: _anim.value),
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
  final void Function(String receiverId, String targetType, String targetId, String content)? onSendNote;
  final void Function(String targetUserId)? onSignal;
  final void Function(String targetUserId)? onReachOut;

  const _NobCard({
    required this.post,
    required this.currentUserId,
    required this.onReact,
    this.onPin,
    this.onArchive,
    this.onDelete,
    this.onSendNote,
    this.onSignal,
    this.onReachOut,
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
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: post.isPinned
              ? AppColors.noblaraGold.withValues(alpha: 0.2)
              : context.borderSubtleColor,
          width: 0.5,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 2))],
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
                // Avatar — tap opens author profile
                GestureDetector(
                  onTap: isOwn ? null : () => _openAuthorProfile(context),
                  child: Container(
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
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: isOwn ? null : () => _openAuthorProfile(context),
                        child: Text(
                          post.authorName ?? 'Noblara',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _ago(post.publishedAt ?? post.createdAt),
                            style: TextStyle(
                                color: context.textMuted, fontSize: 10),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            width: 2,
                            height: 2,
                            decoration: BoxDecoration(
                              color: context.borderColor,
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
                style: TextStyle(
                  color: context.textPrimary,
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
                      color: context.surfaceAltColor,
                      child: Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            color: context.textMuted, size: 28),
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
                  style: TextStyle(
                    color: context.textPrimary,
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
                  emoji: '\u2715',
                  type: 'pass',
                  isActive: myReaction?.reactionType == 'pass',
                  isSubtle: true,
                  onTap: () => onReact('pass'),
                ),
                const Spacer(),
                // Note button (not for own posts)
                if (!isOwn)
                  GestureDetector(
                    onTap: () => _showNoteDialog(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.surfaceAltColor,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mail_outline_rounded, color: context.textMuted, size: 14),
                          const SizedBox(width: 4),
                          Text('Note', style: TextStyle(color: context.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Author-private reaction counts (own posts only)
          if (isOwn && post.ownCounts.isNotEmpty && (post.ownCounts['total'] ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
              child: Text(
                '${post.ownCounts['appreciate'] ?? 0} appreciate \u00B7 ${post.ownCounts['support'] ?? 0} support \u00B7 ${post.ownCounts['pass'] ?? 0} pass',
                style: TextStyle(color: context.textMuted.withValues(alpha: 0.6), fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  void _openAuthorProfile(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      isScrollControlled: true,
      builder: (_) => _AuthorProfileSheet(
        post: post,
        onSignal: onSignal,
        onReachOut: onReachOut,
        onSendNote: onSendNote,
      ),
    );
  }

  void _showNoteDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Send a Note', style: TextStyle(color: context.textPrimary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Private note to ${post.authorName ?? 'author'}', style: TextStyle(color: context.textMuted, fontSize: 12)),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: ctrl,
              maxLength: 280,
              maxLines: 3,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Write something thoughtful...',
                hintStyle: TextStyle(color: context.textMuted),
                filled: true,
                fillColor: context.bgColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: context.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('Send', style: TextStyle(color: AppColors.noblaraGold)),
          ),
        ],
      ),
    ).then((text) {
      if (text != null && text.toString().isNotEmpty && context.mounted) {
        _sendNote(context, text.toString());
      }
    });
  }

  void _sendNote(BuildContext context, String content) {
    if (onSendNote != null) {
      onSendNote!(post.userId, 'post', post.id, content);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note sent'), backgroundColor: AppColors.noblaraGold),
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
      icon: Icon(Icons.more_horiz_rounded,
          color: context.textMuted, size: 18),
      color: context.surfaceAltColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        side: BorderSide(color: context.borderColor),
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
                style: TextStyle(
                    color: context.textPrimary, fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'archive',
          child: Row(
            children: [
              Icon(Icons.archive_outlined,
                  color: context.textMuted, size: 15),
              const SizedBox(width: AppSpacing.sm),
              Text('Archive',
                  style: TextStyle(
                      color: context.textPrimary, fontSize: 13)),
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
        isSubtle ? context.textMuted : AppColors.noblaraGold;

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
                : context.borderColor,
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

// ---------------------------------------------------------------------------
// Nob Filter Bar
// ---------------------------------------------------------------------------

class _NobFilterBar extends StatelessWidget {
  final PostsState state;
  final WidgetRef ref;
  const _NobFilterBar({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, 0),
      child: Column(
        children: [
          // Type + Sort row
          Row(
            children: [
              _FilterChip(label: 'All', active: state.typeFilter == null,
                  onTap: () => ref.read(postsProvider.notifier).setTypeFilter(null)),
              const SizedBox(width: 6),
              _FilterChip(label: 'Thought', active: state.typeFilter == 'thought',
                  onTap: () => ref.read(postsProvider.notifier).setTypeFilter('thought')),
              const SizedBox(width: 6),
              _FilterChip(label: 'Moment', active: state.typeFilter == 'moment',
                  onTap: () => ref.read(postsProvider.notifier).setTypeFilter('moment')),
              const Spacer(),
              // Sort dropdown
              PopupMenuButton<String>(
                initialValue: state.sortMode,
                onSelected: (v) => ref.read(postsProvider.notifier).setSortMode(v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'newest', child: Text('Newest')),
                  const PopupMenuItem(value: 'trending', child: Text('Trending')),
                  const PopupMenuItem(value: 'ai_pick', child: Text('AI Pick')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.surfaceAltColor,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort_rounded, color: context.textMuted, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        state.sortMode == 'ai_pick' ? 'AI Pick' : state.sortMode[0].toUpperCase() + state.sortMode.substring(1),
                        style: TextStyle(color: context.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Tone filters + toggles
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final tone in ['reflective', 'grounded', 'curious', 'creative'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _FilterChip(
                      label: tone[0].toUpperCase() + tone.substring(1),
                      active: state.toneFilter == tone,
                      onTap: () => ref.read(postsProvider.notifier).setToneFilter(
                        state.toneFilter == tone ? null : tone,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => ref.read(postsProvider.notifier).setHidePassed(!state.hidePassed),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: state.hidePassed ? AppColors.noblaraGold.withValues(alpha: 0.15) : context.surfaceAltColor,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(color: state.hidePassed ? AppColors.noblaraGold.withValues(alpha: 0.4) : context.borderColor),
                    ),
                    child: Text('Hide passed', style: TextStyle(
                      color: state.hidePassed ? AppColors.noblaraGold : context.textMuted, fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => ref.read(postsProvider.notifier).setPrioritizeConnected(!state.prioritizeConnected),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: state.prioritizeConnected ? AppColors.noblaraGold.withValues(alpha: 0.15) : context.surfaceAltColor,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(color: state.prioritizeConnected ? AppColors.noblaraGold.withValues(alpha: 0.4) : context.borderColor),
                    ),
                    child: Text('Connected first', style: TextStyle(
                      color: state.prioritizeConnected ? AppColors.noblaraGold : context.textMuted, fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.noblaraGold.withValues(alpha: 0.15) : context.surfaceAltColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: active ? AppColors.noblaraGold.withValues(alpha: 0.4) : context.borderColor),
        ),
        child: Text(label, style: TextStyle(
          color: active ? AppColors.noblaraGold : context.textMuted,
          fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        )),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Author Profile Bottom Sheet
// ---------------------------------------------------------------------------

class _AuthorProfileSheet extends StatelessWidget {
  final Post post;
  final void Function(String)? onSignal;
  final void Function(String)? onReachOut;
  final void Function(String, String, String, String)? onSendNote;
  const _AuthorProfileSheet({required this.post, this.onSignal, this.onReachOut, this.onSendNote});

  @override
  Widget build(BuildContext context) {
    final tierColor = switch (post.authorTier) {
      NobTier.noble => AppColors.nobNoble,
      NobTier.explorer => AppColors.nobExplorer,
      NobTier.observer => AppColors.nobObserver,
    };

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.all(AppSpacing.xxl),
          children: [
            // Handle
            Center(
              child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(999))),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Avatar + Name + Tier
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: tierColor.withValues(alpha: 0.2),
                  backgroundImage: post.authorAvatarUrl != null ? NetworkImage(post.authorAvatarUrl!) : null,
                  child: post.authorAvatarUrl == null
                      ? Text((post.authorName ?? '?')[0].toUpperCase(),
                          style: TextStyle(color: tierColor, fontSize: 22, fontWeight: FontWeight.w600))
                      : null,
                ),
                const SizedBox(width: AppSpacing.lg),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.authorName ?? 'User',
                        style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(color: tierColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(post.authorTier.label,
                          style: TextStyle(color: tierColor, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xxxl),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: const Text('Signal'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      side: BorderSide(color: AppColors.gold.withValues(alpha: 0.4)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onSignal?.call(post.userId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Signal sent'), backgroundColor: AppColors.gold));
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.people_rounded, size: 16),
                    label: const Text('Reach Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF26C6DA),
                      side: BorderSide(color: const Color(0xFF26C6DA).withValues(alpha: 0.4)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onReachOut?.call(post.userId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reached out!'), backgroundColor: Color(0xFF26C6DA)));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.mail_outline_rounded, size: 16),
                label: const Text('Send Note'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.noblaraGold,
                  side: BorderSide(color: AppColors.noblaraGold.withValues(alpha: 0.4)),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
