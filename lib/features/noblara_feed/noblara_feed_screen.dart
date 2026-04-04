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
import '../../providers/interaction_gate_provider.dart';
import 'nob_compose_screen.dart';
import 'nob_drafts_screen.dart';
import 'note_inbox_screen.dart';

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
    final gate = ref.watch(interactionGateProvider).valueOrNull ?? InteractionGate.loading;
    final tierCanCompose = tier == NobTier.noble || tier == NobTier.explorer;
    final canCompose = tierCanCompose && gate.canPostNob;

    return Scaffold(
      backgroundColor: context.bgColor,
      floatingActionButton: tierCanCompose
          ? _ComposeFab(
              onTap: () {
                if (!gate.canPostNob) {
                  showGatingPopup(context, 'Add a photo first',
                      'Upload a photo to share your thoughts with the community.');
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NobComposeScreen()),
                );
              },
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.noblaraGold,
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
                                icon: Icons.mail_outline_rounded,
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const NoteInboxScreen())),
                              ),
                              if (canCompose)
                                _HeaderIcon(
                                  icon: Icons.drafts_outlined,
                                  onTap: () => Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => const NobDraftsScreen())),
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
                          left: BorderSide(color: AppColors.noblaraGold, width: 2.5),
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

              // ── Filter chips ──
              SliverToBoxAdapter(child: _NobFilterBar(state: postsState, ref: ref)),

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
                        post: post,
                        currentUserId: currentUserId,
                        onReact: (type) => ref.read(postsProvider.notifier).react(post.id, type),
                        onPin: currentUserId == post.userId
                            ? () => ref.read(postsProvider.notifier).togglePin(post.id, !post.isPinned)
                            : null,
                        onArchive: currentUserId == post.userId
                            ? () => ref.read(postsProvider.notifier).archivePost(post.id)
                            : null,
                        onDelete: currentUserId == post.userId
                            ? () => ref.read(postsProvider.notifier).deletePost(post.id)
                            : null,
                        onSendNote: (receiverId, targetType, targetId, content) {
                          ref.read(noteInboxProvider.notifier).sendNote(
                            receiverId: receiverId, targetType: targetType,
                            targetId: targetId, content: content,
                          );
                        },
                        onSignal: (targetUserId) => ref.read(postsProvider.notifier).sendSignalFromNob(targetUserId),
                        onReachOut: (targetUserId) => ref.read(postsProvider.notifier).sendReachOutFromNob(targetUserId),
                      );
                    },
                    childCount: postsState.posts.length,
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
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: context.textMuted, size: 22),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: context.surfaceColor,
              shape: BoxShape.circle,
              border: Border.all(color: context.borderColor),
            ),
            child: Icon(Icons.article_outlined, color: context.textMuted, size: 32),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'No Nobs yet.',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Be the first to share a thought.',
            style: TextStyle(color: context.textMuted, fontSize: 14),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withValues(alpha: 0.25)),
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

class _NobCard extends StatelessWidget {
  final Post post;
  final String? currentUserId;
  final ValueChanged<String> onReact;
  final VoidCallback? onPin;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  final void Function(String, String, String, String)? onSendNote;
  final void Function(String)? onSignal;
  final void Function(String)? onReachOut;

  const _NobCard({
    required this.post, required this.currentUserId, required this.onReact,
    this.onPin, this.onArchive, this.onDelete, this.onSendNote, this.onSignal, this.onReachOut,
  });

  Color get _tierColor => switch (post.authorTier) {
    NobTier.noble => AppColors.nobNoble,
    NobTier.explorer => AppColors.nobExplorer,
    NobTier.observer => AppColors.nobObserver,
  };

  @override
  Widget build(BuildContext context) {
    final myReaction = currentUserId != null ? post.myReaction(currentUserId!) : null;
    final isOwn = currentUserId == post.userId;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: post.isPinned ? AppColors.noblaraGold.withValues(alpha: 0.3) : AppColors.borderLight,
          width: post.isPinned ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: const Color(0x38000000), blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: const Color(0x20000000), blurRadius: 32, offset: const Offset(0, 12)),
        ],
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
                  AppColors.noblaraGold.withValues(alpha: 0.8),
                  AppColors.noblaraGold.withValues(alpha: 0),
                ]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),

          // ── Author row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                if (post.isPinned) ...[
                  const Icon(Icons.push_pin_rounded, color: AppColors.noblaraGold, size: 12),
                  const SizedBox(width: 6),
                ],
                GestureDetector(
                  onTap: isOwn ? null : () => _openAuthorProfile(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _tierColor.withValues(alpha: 0.12),
                      border: Border.all(color: _tierColor.withValues(alpha: 0.25), width: 1),
                    ),
                    child: post.authorAvatarUrl != null
                        ? ClipOval(child: Image.network(post.authorAvatarUrl!, fit: BoxFit.cover))
                        : Center(child: Text((post.authorName ?? 'N')[0].toUpperCase(), style: TextStyle(color: _tierColor, fontWeight: FontWeight.w700, fontSize: 12))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: isOwn ? null : () => _openAuthorProfile(context),
                        child: Text(post.authorName ?? 'Noblara', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                      const SizedBox(height: 2),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: _tierColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(post.authorTier.label.toUpperCase(), style: TextStyle(color: _tierColor, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                        ),
                        const SizedBox(width: 6),
                        Text(_ago(post.publishedAt ?? post.createdAt), style: TextStyle(color: context.textMuted, fontSize: 11)),
                      ]),
                    ],
                  ),
                ),
                if (isOwn)
                  _OwnerMenu(post: post, onPin: onPin, onArchive: onArchive, onDelete: onDelete),
              ],
            ),
          ),

          // ── Content ──
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
                    child: Image.network(
                      post.photoUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: context.surfaceAltColor,
                        child: Center(child: Icon(Icons.image_not_supported_outlined, color: context.textMuted, size: 28)),
                      ),
                    ),
                  ),
                ),
              ),
            if (post.caption != null && post.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(post.caption!, style: TextStyle(color: context.textPrimary, fontSize: 14, height: 1.5)),
              ),
          ],

          // ── Reactions ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                _ReactionBtn(emoji: '👋', type: 'appreciate', isActive: myReaction?.reactionType == 'appreciate', onTap: () => onReact('appreciate')),
                const SizedBox(width: 8),
                _ReactionBtn(emoji: '🤝', type: 'support', isActive: myReaction?.reactionType == 'support', onTap: () => onReact('support')),
                const SizedBox(width: 8),
                _ReactionBtn(emoji: '\u2715', type: 'pass', isActive: myReaction?.reactionType == 'pass', isSubtle: true, onTap: () => onReact('pass')),
                const Spacer(),
                if (!isOwn)
                  GestureDetector(
                    onTap: () => _showNoteDialog(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: context.surfaceAltColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.borderSubtleColor),
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

          // Owner-only counts
          if (isOwn && post.ownCounts.isNotEmpty && (post.ownCounts['total'] ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                '${post.ownCounts['appreciate'] ?? 0} appreciate · ${post.ownCounts['support'] ?? 0} support · ${post.ownCounts['pass'] ?? 0} pass',
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
      builder: (_) => _AuthorProfileSheet(post: post, onSignal: onSignal, onReachOut: onReachOut, onSendNote: onSendNote),
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
            const SizedBox(height: 10),
            TextField(
              controller: ctrl, maxLength: 280, maxLines: 3,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Write something thoughtful...',
                hintStyle: TextStyle(color: context.textMuted),
                filled: true, fillColor: context.bgColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: context.textMuted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Send', style: TextStyle(color: AppColors.noblaraGold)),
          ),
        ],
      ),
    ).then((text) {
      if (text != null && text.toString().isNotEmpty && context.mounted) {
        onSendNote?.call(post.userId, 'post', post.id, text.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note sent'), backgroundColor: AppColors.noblaraGold),
        );
      }
    });
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
  final VoidCallback? onPin;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  const _OwnerMenu({required this.post, this.onPin, this.onArchive, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz_rounded, color: context.textMuted, size: 18),
      color: context.surfaceAltColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: context.borderColor)),
      onSelected: (val) {
        if (val == 'pin' && onPin != null) onPin!();
        if (val == 'archive' && onArchive != null) onArchive!();
        if (val == 'delete' && onDelete != null) onDelete!();
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'pin', child: Row(children: [
          Icon(post.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, color: AppColors.noblaraGold, size: 15),
          const SizedBox(width: 8),
          Text(post.isPinned ? 'Unpin' : 'Pin to top', style: TextStyle(color: context.textPrimary, fontSize: 13)),
        ])),
        PopupMenuItem(value: 'archive', child: Row(children: [
          Icon(Icons.archive_outlined, color: context.textMuted, size: 15),
          const SizedBox(width: 8),
          Text('Archive', style: TextStyle(color: context.textPrimary, fontSize: 13)),
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

class _ReactionBtn extends StatelessWidget {
  final String emoji;
  final String type;
  final bool isActive;
  final bool isSubtle;
  final VoidCallback onTap;
  const _ReactionBtn({required this.emoji, required this.type, required this.isActive, required this.onTap, this.isSubtle = false});

  @override
  Widget build(BuildContext context) {
    final activeColor = isSubtle ? context.textMuted : AppColors.noblaraGold;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? activeColor.withValues(alpha: 0.35) : context.borderSubtleColor),
        ),
        child: Text(emoji, style: TextStyle(fontSize: 14, color: isActive ? null : context.textMuted)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter bar — horizontal scroll, no overflow
// ---------------------------------------------------------------------------

class _NobFilterBar extends StatelessWidget {
  final PostsState state;
  final WidgetRef ref;
  const _NobFilterBar({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 0, 0),
      child: Column(
        children: [
          // Type + Sort row
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(label: 'All', active: state.typeFilter == null,
                          onTap: () => ref.read(postsProvider.notifier).setTypeFilter(null)),
                      const SizedBox(width: 6),
                      _FilterChip(label: 'Thought', active: state.typeFilter == 'thought',
                          onTap: () => ref.read(postsProvider.notifier).setTypeFilter('thought')),
                      const SizedBox(width: 6),
                      _FilterChip(label: 'Moment', active: state.typeFilter == 'moment',
                          onTap: () => ref.read(postsProvider.notifier).setTypeFilter('moment')),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: PopupMenuButton<String>(
                    initialValue: state.sortMode,
                    onSelected: (v) => ref.read(postsProvider.notifier).setSortMode(v),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'newest', child: Text('Newest')),
                      const PopupMenuItem(value: 'trending', child: Text('Trending')),
                      const PopupMenuItem(value: 'ai_pick', child: Text('AI Pick')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: context.surfaceAltColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.borderSubtleColor),
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Tone + toggles — horizontal scroll
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final tone in ['reflective', 'grounded', 'curious', 'creative'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _FilterChip(
                      label: tone[0].toUpperCase() + tone.substring(1),
                      active: state.toneFilter == tone,
                      onTap: () => ref.read(postsProvider.notifier).setToneFilter(state.toneFilter == tone ? null : tone),
                    ),
                  ),
                const SizedBox(width: 8),
                _ToggleChip(label: 'Hide passed', active: state.hidePassed,
                    onTap: () => ref.read(postsProvider.notifier).setHidePassed(!state.hidePassed)),
                const SizedBox(width: 6),
                _ToggleChip(label: 'Connected first', active: state.prioritizeConnected,
                    onTap: () => ref.read(postsProvider.notifier).setPrioritizeConnected(!state.prioritizeConnected)),
                const SizedBox(width: 20),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.emerald900 : context.surfaceAltColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.emerald600.withValues(alpha: 0.5) : context.borderSubtleColor),
        ),
        child: Text(label, style: TextStyle(
          color: active ? AppColors.emerald500 : context.textMuted,
          fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        )),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.emerald900 : context.surfaceAltColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.emerald600.withValues(alpha: 0.5) : context.borderSubtleColor),
        ),
        child: Text(label, style: TextStyle(
          color: active ? AppColors.emerald500 : context.textMuted, fontSize: 11,
        )),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Author Profile Sheet
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
      initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.85, expand: false,
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.all(24),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 24),
            Row(children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: tierColor.withValues(alpha: 0.2),
                backgroundImage: post.authorAvatarUrl != null ? NetworkImage(post.authorAvatarUrl!) : null,
                child: post.authorAvatarUrl == null
                    ? Text((post.authorName ?? '?')[0].toUpperCase(), style: TextStyle(color: tierColor, fontSize: 22, fontWeight: FontWeight.w600))
                    : null,
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(post.authorName ?? 'User', style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tierColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(post.authorTier.label, style: TextStyle(color: tierColor, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ]),
            ]),
            const SizedBox(height: 32),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                icon: const Icon(Icons.bolt_rounded, size: 16), label: const Text('Signal'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.gold, side: BorderSide(color: AppColors.gold.withValues(alpha: 0.4))),
                onPressed: () { Navigator.pop(context); onSignal?.call(post.userId); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signal sent'), backgroundColor: AppColors.gold)); },
              )),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(
                icon: const Icon(Icons.people_rounded, size: 16), label: const Text('Reach Out'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.teal, side: BorderSide(color: AppColors.teal.withValues(alpha: 0.4))),
                onPressed: () { Navigator.pop(context); onReachOut?.call(post.userId); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Reached out!'), backgroundColor: AppColors.teal)); },
              )),
            ]),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              icon: const Icon(Icons.mail_outline_rounded, size: 16), label: const Text('Send Note'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.noblaraGold, side: BorderSide(color: AppColors.noblaraGold.withValues(alpha: 0.4))),
              onPressed: () => Navigator.pop(context),
            )),
          ],
        ),
      ),
    );
  }
}
