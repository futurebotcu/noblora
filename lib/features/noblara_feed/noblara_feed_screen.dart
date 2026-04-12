import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/premium.dart';
import '../../core/utils/video_assets.dart';
import '../../data/models/post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';
import 'mood_map_screen.dart';
import 'my_nobs_screen.dart';
import 'nob_compose_screen.dart';
import 'nob_detail_screen.dart';
import 'notifications_screen.dart';

// ---------------------------------------------------------------------------
// NoblaraFeedScreen — Gallery-style community feed
// ---------------------------------------------------------------------------

class NoblaraFeedScreen extends ConsumerWidget {
  const NoblaraFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsState = ref.watch(postsProvider);
    final tierAsync = ref.watch(nobTierProvider);
    final currentUserId = ref.watch(authProvider).userId;

    final tier = tierAsync.when(
      data: (t) => t,
      loading: () => NobTier.observer,
      error: (_, __) => NobTier.observer,
    );
    // Noblara compose rights are tier-only — no photo or verification gate.
    // Backend rate-limits via check_nob_limit() per tier.
    final canCompose = tier == NobTier.noble || tier == NobTier.explorer;

    return Scaffold(
      backgroundColor: context.bgColor,
      floatingActionButton: canCompose
          ? _ComposeFab(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NobComposeScreen()),
                );
              },
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.emerald600,
          backgroundColor: context.surfaceColor,
          onRefresh: () => ref.read(postsProvider.notifier).refresh(),
          child: CustomScrollView(
            slivers: [
              // ── Gallery Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'THE GALLERY',
                              style: TextStyle(
                                color: context.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Community',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _TierBadge(tier: tier),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _HeaderIcon(
                                icon: Icons.public_rounded,
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const MoodMapScreen())),
                              ),
                              _NotificationsHeaderIcon(),
                              _HeaderIcon(
                                icon: Icons.person_outline_rounded,
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const MyNobsScreen())),
                              ),
                              _HeaderIcon(
                                icon: Icons.refresh_rounded,
                                onTap: () => ref.read(postsProvider.notifier).refresh(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Observer tier banner ──
              if (!canCompose)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(color: AppColors.emerald600, width: 2.5),
                        ),
                      ),
                      child: Text(
                        'Observer · Read and react only',
                        style: TextStyle(color: context.textMuted, fontSize: 12, letterSpacing: 0.2),
                      ),
                    ),
                  ),
                ),

              // ── Error banner ──
              if (postsState.error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                      ),
                      child: Text(postsState.error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                    ),
                  ),
                ),

              // ── Lane bar ──
              SliverToBoxAdapter(child: _LaneBar(state: postsState, ref: ref)),

              // ── Loading shimmer ──
              if (postsState.isLoading && postsState.posts.isEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => const _ShimmerCard(),
                    childCount: 4,
                  ),
                )
              else if (!postsState.isLoading && postsState.posts.isEmpty)
                const SliverFillRemaining(hasScrollBody: false, child: _EmptyState())

              // ── Posts ──
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final post = postsState.posts[i];
                      return _NobCard(
                        key: ValueKey(post.id),
                        post: post,
                        currentUserId: currentUserId,
                        onReact: (type) => ref.read(postsProvider.notifier).react(post.id, type),
                        onDelete: (currentUserId != null && currentUserId == post.userId)
                            ? () => ref.read(postsProvider.notifier).deletePost(post.id)
                            : null,
                        onEcho: () => ref.read(postsProvider.notifier).toggleEcho(post.id),
                        onMinorEdit: (currentUserId != null && currentUserId == post.userId && post.canMinorEdit)
                            ? () => _showMinorEditSheet(context, ref, post)
                            : null,
                        onSecondThought: (currentUserId != null && currentUserId == post.userId && post.canSecondThought)
                            ? () => _showSecondThoughtSheet(context, ref, post)
                            : null,
                      );
                    },
                    childCount: postsState.posts.length,
                  ),
                ),

              // ── Load more trigger ──
              if (postsState.posts.isNotEmpty && postsState.hasMore)
                SliverToBoxAdapter(
                  child: _LoadMoreTrigger(
                    isLoading: postsState.isLoadingMore,
                    onVisible: () => ref.read(postsProvider.notifier).loadMore(),
                  ),
                ),
              if (!postsState.hasMore && postsState.posts.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('You\'re all caught up', style: TextStyle(color: context.textMuted, fontSize: 12)),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header icon button
// ---------------------------------------------------------------------------

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: context.textMuted, size: 22),
      ),
    );
  }
}

/// Bell icon with an unread badge driven by [noblaraUnreadCountProvider].
class _NotificationsHeaderIcon extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(noblaraUnreadCountProvider).asData?.value ?? 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        HapticFeedback.selectionClick();
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        ref.invalidate(noblaraUnreadCountProvider);
      },
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.notifications_none_rounded,
                color: context.textMuted, size: 22),
            if (unread > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints:
                      const BoxConstraints(minWidth: 14, minHeight: 14),
                  decoration: BoxDecoration(
                    color: AppColors.emerald600,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.nobBackground, width: 1.5),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
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
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.emerald500, AppColors.emerald600],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
          boxShadow: Premium.emeraldGlow(intensity: 1.3),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined, size: 16, color: AppColors.textOnEmerald),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Write a Nob',
              style: TextStyle(
                color: AppColors.textOnEmerald,
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
// Empty state
// ---------------------------------------------------------------------------

class _LoadMoreTrigger extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onVisible;
  const _LoadMoreTrigger({required this.isLoading, required this.onVisible});

  @override
  State<_LoadMoreTrigger> createState() => _LoadMoreTriggerState();
}

class _LoadMoreTriggerState extends State<_LoadMoreTrigger> {
  @override
  void initState() {
    super.initState();
    if (!widget.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onVisible());
    }
  }

  @override
  void didUpdateWidget(_LoadMoreTrigger old) {
    super.didUpdateWidget(old);
    if (!widget.isLoading && old.isLoading) {
      widget.onVisible();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: widget.isLoading
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.emerald600))
            : const SizedBox.shrink(),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          decoration: Premium.emptyStateDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.emerald600.withValues(alpha: 0.10),
                      AppColors.emerald600.withValues(alpha: 0.03),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.emerald600.withValues(alpha: 0.12),
                    width: 0.5,
                  ),
                ),
                child: Icon(Icons.article_outlined,
                    color: AppColors.emerald600.withValues(alpha: 0.4), size: 28),
              ),
              const SizedBox(height: 24),
              Text(
                'No Nobs yet',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Be the first to share a thought\nwith the community.',
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
// Shimmer placeholder card
// ---------------------------------------------------------------------------

class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard();
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderSubtleColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [_shimmerBox(32, 32, circle: true), const SizedBox(width: 12), _shimmerBox(100, 12)]),
            const SizedBox(height: 16),
            _shimmerBox(double.infinity, 12),
            const SizedBox(height: 8),
            _shimmerBox(double.infinity, 12),
            const SizedBox(height: 8),
            _shimmerBox(160, 12),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox(double w, double h, {bool circle = false}) {
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        color: context.surfaceAltColor.withValues(alpha: _anim.value),
        borderRadius: circle ? BorderRadius.circular(999) : BorderRadius.circular(6),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tier badge
// ---------------------------------------------------------------------------

class _TierBadge extends StatelessWidget {
  final NobTier tier;
  const _TierBadge({required this.tier});

  Color get _color => switch (tier) {
    NobTier.noble => AppColors.nobNoble,
    NobTier.explorer => AppColors.nobExplorer,
    NobTier.observer => AppColors.nobObserver,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.18), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: _color.withValues(alpha: 0.06),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        tier.label.toUpperCase(),
        style: TextStyle(color: _color, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nob card — premium gallery card
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Minor Edit / Second Thought sheets
// ---------------------------------------------------------------------------

void _showMinorEditSheet(BuildContext context, WidgetRef ref, Post post) {
  final ctrl = TextEditingController(text: post.isThought ? post.content : post.caption ?? '');
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.nobSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_outlined, color: ctx.textSecondary, size: 16),
              const SizedBox(width: 8),
              Text('Minor Edit', style: TextStyle(color: ctx.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${3 - post.editCount} edits left',
                  style: TextStyle(color: ctx.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            maxLines: null,
            minLines: 3,
            maxLength: 300,
            autofocus: true,
            style: TextStyle(color: ctx.textPrimary, fontSize: 14, height: 1.5),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ctx.borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ctx.borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.emerald600)),
              contentPadding: const EdgeInsets.all(14),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.emerald600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final text = ctrl.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(ctx);
                final result = post.isThought
                    ? await ref.read(postsProvider.notifier).minorEdit(post.id, text)
                    : await ref.read(postsProvider.notifier).minorEdit(post.id, post.content, newCaption: text);
                if (!result.ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.error ?? 'Edit failed')),
                  );
                }
              },
              child: const Text('Save Edit'),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showSecondThoughtSheet(BuildContext context, WidgetRef ref, Post post) {
  final ctrl = TextEditingController(text: post.isThought ? post.content : post.caption ?? '');
  final reasonCtrl = TextEditingController();
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.nobSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_fix_high_rounded, color: AppColors.emerald600, size: 16),
                const SizedBox(width: 8),
                Text('Second Thought', style: TextStyle(color: AppColors.emerald600, fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Revise your thinking. The original will be preserved.',
                style: TextStyle(color: ctx.textMuted, fontSize: 12)),
            const SizedBox(height: 14),
            // Original content (read-only)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ctx.surfaceAltColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ctx.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Original', style: TextStyle(color: ctx.textMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text(
                    post.isThought ? post.content : (post.caption ?? ''),
                    style: TextStyle(color: ctx.textSecondary, fontSize: 13, height: 1.4, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // New content
            TextField(
              controller: ctrl,
              maxLines: null,
              minLines: 4,
              maxLength: 300,
              autofocus: true,
              style: TextStyle(color: ctx.textPrimary, fontSize: 14, height: 1.5),
              decoration: InputDecoration(
                hintText: 'Your revised thought...',
                hintStyle: TextStyle(color: ctx.textMuted.withValues(alpha: 0.5)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ctx.borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ctx.borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.emerald600)),
                contentPadding: const EdgeInsets.all(14),
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            // Reason (optional)
            TextField(
              controller: reasonCtrl,
              maxLength: 200,
              style: TextStyle(color: ctx.textSecondary, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Why the change? (optional)',
                hintStyle: TextStyle(color: ctx.textMuted.withValues(alpha: 0.4), fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ctx.borderColor.withValues(alpha: 0.5))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final text = ctrl.text.trim();
                  if (text.isEmpty) return;
                  final reason = reasonCtrl.text.trim();
                  Navigator.pop(ctx);
                  final result = post.isThought
                      ? await ref.read(postsProvider.notifier).secondThought(
                            post.id, text, reason: reason.isNotEmpty ? reason : null)
                      : await ref.read(postsProvider.notifier).secondThought(
                            post.id, post.content,
                            newCaption: text,
                            reason: reason.isNotEmpty ? reason : null);
                  if (!result.ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result.error ?? 'Could not save')),
                    );
                  }
                },
                child: const Text('Publish Second Thought'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NobCard extends StatelessWidget {
  final Post post;
  final String? currentUserId;
  final ValueChanged<String> onReact;
  final VoidCallback? onDelete;
  final VoidCallback? onEcho;
  final VoidCallback? onMinorEdit;
  final VoidCallback? onSecondThought;

  const _NobCard({
    super.key,
    required this.post, required this.currentUserId, required this.onReact,
    this.onDelete, this.onEcho, this.onMinorEdit, this.onSecondThought,
  });

  Color get _tierColor => switch (post.authorTier) {
    NobTier.noble => AppColors.nobNoble,
    NobTier.explorer => AppColors.nobExplorer,
    NobTier.observer => AppColors.nobObserver,
  };

  @override
  Widget build(BuildContext context) {
    final myReaction = currentUserId != null ? post.myReaction(currentUserId!) : null;
    final isOwn = currentUserId != null && currentUserId == post.userId;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: post.isPinned
              ? AppColors.emerald600.withValues(alpha: 0.30)
              : AppColors.borderLight.withValues(alpha: 0.5),
          width: post.isPinned ? 1 : 0.5,
        ),
        boxShadow: Premium.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Noble accent bar
          if (post.authorTier == NobTier.noble)
            Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.emerald600.withValues(alpha: 0.6),
                  AppColors.emerald600.withValues(alpha: 0),
                ]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),

          // ── Author row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              children: [
                // Avatar — abstract for anonymous, real for normal posts
                if (post.isAnonymous)
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _tierColor.withValues(alpha: 0.12),
                      border: Border.all(color: _tierColor.withValues(alpha: 0.25), width: 1),
                    ),
                    child: Icon(Icons.visibility_off_rounded, color: _tierColor.withValues(alpha: 0.6), size: 14),
                  )
                else
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _tierColor.withValues(alpha: 0.12),
                      border: Border.all(color: _tierColor.withValues(alpha: 0.25), width: 1),
                    ),
                    child: post.authorAvatarUrl != null
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: post.authorAvatarUrl!,
                              fit: BoxFit.cover,
                              width: 32,
                              height: 32,
                              memCacheWidth: 96,
                              errorWidget: (_, __, ___) => Center(
                                child: Text(
                                  (post.authorName ?? 'N')[0].toUpperCase(),
                                  style: TextStyle(color: _tierColor, fontWeight: FontWeight.w700, fontSize: 12),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              (post.authorName ?? 'N')[0].toUpperCase(),
                              style: TextStyle(color: _tierColor, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        post.isAnonymous ? 'Anonymous' : (post.authorName ?? (isOwn ? 'You' : 'Someone')),
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          fontStyle: post.isAnonymous ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: _tierColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              post.authorTier.label.toUpperCase(),
                              style: TextStyle(color: _tierColor, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _ago(post.publishedAt ?? post.createdAt),
                            style: TextStyle(color: context.textMuted, fontSize: 11),
                          ),
                          if (post.hasSecondThought) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.emerald600.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.emerald600.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_fix_high_rounded,
                                      color: AppColors.emerald600.withValues(alpha: 0.7), size: 9),
                                  const SizedBox(width: 3),
                                  Text('Second Thought',
                                      style: TextStyle(
                                        color: AppColors.emerald600.withValues(alpha: 0.8),
                                        fontSize: 8.5, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ] else if (post.isEdited) ...[
                            const SizedBox(width: 5),
                            Text('edited',
                                style: TextStyle(
                                  color: context.textMuted.withValues(alpha: 0.6),
                                  fontSize: 10, fontStyle: FontStyle.italic)),
                          ],
                          if (post.isFutureNob) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.schedule_rounded,
                                color: context.textMuted.withValues(alpha: 0.6), size: 12),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (isOwn)
                  _OwnerMenu(
                    post: post,
                    onDelete: onDelete,
                    onMinorEdit: onMinorEdit,
                    onSecondThought: onSecondThought,
                  ),
              ],
            ),
          ),

          // ── Content (tap → detail) ──
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => NobDetailScreen(post: post),
            )),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.isThought && post.content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Text(
                      post.content,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: post.content.length < 120 ? 18 : 15,
                        fontStyle: post.content.length < 120 ? FontStyle.italic : FontStyle.normal,
                        height: 1.6,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),

          if (post.isMoment) ...[
            if (post.photoUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _MomentMedia(photoUrl: post.photoUrl!),
                  ),
                ),
              ),
            if (post.caption != null && post.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(post.caption!, style: TextStyle(color: context.textPrimary, fontSize: 14, height: 1.5)),
              ),
          ],
              ],
            ),
          ),

          // ── Like + Reply + Echo ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                _ReactionBtn(
                  icon: Icons.waving_hand_outlined,
                  type: 'appreciate',
                  isActive: myReaction?.reactionType == 'appreciate',
                  onTap: () => onReact('appreciate'),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => NobDetailScreen(post: post),
                  )),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, color: context.textMuted, size: 16),
                      const SizedBox(width: 4),
                      Text(post.commentCount > 0 ? '${post.commentCount}' : 'Reply', style: TextStyle(color: context.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _EchoBtn(
                  count: post.echoCount,
                  isActive: post.hasEchoed,
                  onTap: onEcho,
                ),
                const Spacer(),
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
// Owner menu
// ---------------------------------------------------------------------------

class _OwnerMenu extends StatelessWidget {
  final Post post;
  final VoidCallback? onDelete;
  final VoidCallback? onMinorEdit;
  final VoidCallback? onSecondThought;
  const _OwnerMenu({required this.post, this.onDelete, this.onMinorEdit, this.onSecondThought});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz_rounded, color: context.textMuted, size: 18),
      color: context.surfaceAltColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: context.borderColor)),
      onSelected: (val) {
        if (val == 'delete' && onDelete != null) onDelete!();
        if (val == 'edit' && onMinorEdit != null) onMinorEdit!();
        if (val == 'second_thought' && onSecondThought != null) onSecondThought!();
      },
      itemBuilder: (_) => [
        if (post.canMinorEdit)
          PopupMenuItem(value: 'edit', child: Row(children: [
            Icon(Icons.edit_outlined, color: context.textSecondary, size: 15),
            const SizedBox(width: 8),
            Text('Edit', style: TextStyle(color: context.textSecondary, fontSize: 13)),
          ])),
        if (post.canSecondThought)
          PopupMenuItem(value: 'second_thought', child: Row(children: [
            Icon(Icons.auto_fix_high_rounded, color: AppColors.emerald600, size: 15),
            const SizedBox(width: 8),
            const Text('Second Thought', style: TextStyle(color: AppColors.emerald600, fontSize: 13)),
          ])),
        PopupMenuItem(value: 'delete', child: const Row(children: [
          Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 15),
          SizedBox(width: 8),
          Text('Delete', style: TextStyle(color: AppColors.error, fontSize: 13)),
        ])),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reaction button
// ---------------------------------------------------------------------------

class _ReactionBtn extends StatefulWidget {
  final IconData icon;
  final String type;
  final bool isActive;
  final VoidCallback onTap;
  const _ReactionBtn({required this.icon, required this.type, required this.isActive, required this.onTap});

  @override
  State<_ReactionBtn> createState() => _ReactionBtnState();
}

class _ReactionBtnState extends State<_ReactionBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.emerald600;
    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.forward(),
      onTapUp: (_) => _scaleCtrl.reverse(),
      onTapCancel: () => _scaleCtrl.reverse(),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isActive ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.isActive ? activeColor.withValues(alpha: 0.35) : context.borderSubtleColor),
          ),
          child: Icon(widget.icon, size: 16, color: widget.isActive ? activeColor : context.textMuted),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Echo button — Noblara's signature interaction (anonymous repost)
// ---------------------------------------------------------------------------

class _EchoBtn extends StatelessWidget {
  final int count;
  final bool isActive;
  final VoidCallback? onTap;
  const _EchoBtn({required this.count, required this.isActive, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.emerald600 : context.textMuted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.graphic_eq_rounded, color: color, size: 16),
          const SizedBox(width: 4),
          Text(count > 0 ? '$count' : 'Echo',
              style: TextStyle(color: color, fontSize: 12, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lane bar — fixed lanes (All, Near You, Country, Echoes) + dynamic mood lanes
// ---------------------------------------------------------------------------

class _LaneBar extends StatelessWidget {
  final PostsState state;
  final WidgetRef ref;
  const _LaneBar({required this.state, required this.ref});

  static String _moodLabel(String mood) {
    switch (mood) {
      case 'late_night':
        return 'Late Night';
      default:
        return mood[0].toUpperCase() + mood.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lanes = <_LaneOption>[
      const _LaneOption(id: 'all', label: 'All'),
      const _LaneOption(id: 'near_you', label: 'Near You'),
      const _LaneOption(id: 'country', label: 'Your Country'),
      const _LaneOption(id: 'echoes', label: 'Echoes'),
      for (final mood in state.dynamicMoodLanes)
        _LaneOption(id: 'mood:$mood', label: _moodLabel(mood), mood: mood),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
        itemCount: lanes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final lane = lanes[i];
          final isActive = lane.mood != null
              ? (state.activeLane == 'mood' && state.activeMood == lane.mood)
              : state.activeLane == lane.id;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              if (lane.mood != null) {
                ref.read(postsProvider.notifier).setLane('mood', mood: lane.mood);
              } else {
                ref.read(postsProvider.notifier).setLane(lane.id);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.emerald600.withValues(alpha: 0.14)
                    : context.surfaceAltColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? AppColors.emerald600.withValues(alpha: 0.5)
                      : context.borderSubtleColor,
                ),
              ),
              child: Center(
                child: Text(
                  lane.label,
                  style: TextStyle(
                    color: isActive ? AppColors.emerald350 : context.textMuted,
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LaneOption {
  final String id;
  final String label;
  final String? mood;
  const _LaneOption({required this.id, required this.label, this.mood});
}

// ---------------------------------------------------------------------------
// _MomentMedia — renders photo Nobs as image, video Nobs as thumbnail + play
// ---------------------------------------------------------------------------

class _MomentMedia extends StatelessWidget {
  final String photoUrl;
  const _MomentMedia({required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final isVideo = isVideoUrl(photoUrl);
    final imageUrl = isVideo ? videoThumbnailUrlFor(photoUrl) : photoUrl;
    final fallback = Container(
      color: context.surfaceAltColor,
      child: Center(
        child: Icon(
          isVideo
              ? Icons.play_circle_outline_rounded
              : Icons.image_not_supported_outlined,
          color: context.textMuted,
          size: 36,
        ),
      ),
    );

    final media = imageUrl == null
        ? fallback
        : CachedNetworkImage(
            imageUrl: imageUrl,
            width: double.infinity,
            fit: BoxFit.cover,
            memCacheWidth: 1080,
            errorWidget: (_, __, ___) => fallback,
          );

    if (!isVideo) return media;

    // Play overlay for video moments — keeps the media visible but signals
    // that tap goes to the player.
    return Stack(
      fit: StackFit.expand,
      children: [
        media,
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.15),
                Colors.black.withValues(alpha: 0.45),
              ],
            ),
          ),
        ),
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.55),
              border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
          ),
        ),
      ],
    );
  }
}
