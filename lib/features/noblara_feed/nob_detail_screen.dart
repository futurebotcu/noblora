import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/video_assets.dart';
import '../../data/models/post.dart';
import '../../data/models/post_comment.dart';
import '../../data/models/post_revision.dart';
import '../../providers/auth_provider.dart';
import '../../providers/comment_provider.dart';
import '../../providers/posts_provider.dart';

// ---------------------------------------------------------------------------
// NobDetailScreen — Twitter/X-style post detail with threaded comments
// ---------------------------------------------------------------------------

class NobDetailScreen extends ConsumerStatefulWidget {
  final Post post;
  const NobDetailScreen({super.key, required this.post});

  @override
  ConsumerState<NobDetailScreen> createState() => _NobDetailScreenState();
}

class _NobDetailScreenState extends ConsumerState<NobDetailScreen> {
  final _commentCtrl = TextEditingController();
  final _commentFocus = FocusNode();
  String? _replyToId;
  String? _replyToName;
  bool _sending = false;
  bool _chainMode = false; // Soul Chain — "Continue the thought"

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _focusReplyInput() {
    _commentFocus.requestFocus();
  }

  void _setReplyTo(String commentId, String authorName) {
    setState(() {
      _replyToId = commentId;
      _replyToName = authorName;
      _chainMode = false; // replying to someone resets chain mode
    });
    _commentCtrl.clear();
    _focusReplyInput();
  }

  void _clearReply() {
    setState(() {
      _replyToId = null;
      _replyToName = null;
    });
  }

  void _toggleChainMode() {
    HapticFeedback.selectionClick();
    setState(() {
      _chainMode = !_chainMode;
      if (_chainMode) {
        // Chains aren't a reply to a specific comment — they continue the post.
        _replyToId = null;
        _replyToName = null;
      }
    });
    _focusReplyInput();
  }

  Future<void> _send() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await ref
        .read(commentsProvider(widget.post.id).notifier)
        .add(
          text,
          parentId: _chainMode ? null : _replyToId,
          chainType: _chainMode ? 'chain' : 'reply',
        );
    if (mounted) {
      setState(() => _sending = false);
      if (ok) {
        _commentCtrl.clear();
        _clearReply();
        // Keep chain mode on so the user can keep adding links — feels like
        // a chain of thoughts. They tap the toggle off when done.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read the live post from the feed provider so reactions/counts stay in sync.
    // Falls back to the snapshot passed in if the post isn't currently loaded in the feed.
    final feedPosts = ref.watch(postsProvider).posts;
    final post = feedPosts.firstWhere(
      (p) => p.id == widget.post.id,
      orElse: () => widget.post,
    );
    final currentUserId = ref.watch(authProvider).userId;
    final commentsState = ref.watch(commentsProvider(post.id));
    final myReaction = currentUserId != null ? post.myReaction(currentUserId) : null;

    return Scaffold(
      backgroundColor: AppColors.nobBackground,
      appBar: AppBar(
        backgroundColor: AppColors.nobBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: Text('Nob', style: TextStyle(color: context.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
              children: [
                // ── Post content ──
                _PostSection(post: post),

                // ── Interaction bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: context.borderSubtleColor),
                        bottom: BorderSide(color: context.borderSubtleColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        _StatChip(
                          icon: Icons.waving_hand_outlined,
                          count: post.appreciateCount,
                          label: 'Appreciate',
                        ),
                        const SizedBox(width: 20),
                        _StatChip(
                          icon: Icons.chat_bubble_outline_rounded,
                          count: commentsState.totalCount,
                          label: 'Replies',
                        ),
                        const SizedBox(width: 20),
                        _StatChip(
                          icon: Icons.graphic_eq_rounded,
                          count: post.echoCount,
                          label: 'Echo',
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Reaction buttons ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ActionBtn(
                        icon: Icons.waving_hand_outlined,
                        label: 'Appreciate',
                        isActive: myReaction?.reactionType == 'appreciate',
                        onTap: () => ref.read(postsProvider.notifier).react(post.id, 'appreciate'),
                      ),
                      _ActionBtn(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Reply',
                        isActive: false,
                        onTap: _focusReplyInput,
                      ),
                      _ActionBtn(
                        icon: Icons.graphic_eq_rounded,
                        label: post.hasEchoed ? 'Echoed' : 'Echo',
                        isActive: post.hasEchoed,
                        onTap: () => ref.read(postsProvider.notifier).toggleEcho(post.id),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                Divider(color: context.borderSubtleColor, height: 1, indent: 20, endIndent: 20),

                // ── Comments section ──
                if (commentsState.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.emerald600)),
                  )
                else ...[
                  // Soul Chain — continuation thread, distinct from replies
                  if (commentsState.chains.isNotEmpty)
                    _SoulChainSection(
                      chains: commentsState.chains,
                      currentUserId: currentUserId,
                      onDelete: (id) =>
                          ref.read(commentsProvider(post.id).notifier).delete(id),
                    ),

                  // Replies (regular threaded comments)
                  if (commentsState.comments.isEmpty &&
                      commentsState.chains.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                      child: Center(
                        child: Text('No replies yet. Start the conversation.',
                            style: TextStyle(color: context.textMuted, fontSize: 13)),
                      ),
                    )
                  else if (commentsState.comments.isNotEmpty) ...[
                    if (commentsState.chains.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                        child: Text(
                          'REPLIES',
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 10,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ...commentsState.comments.map((c) => _CommentThread(
                          comment: c,
                          currentUserId: currentUserId,
                          onReply: (name) => _setReplyTo(c.id, name),
                          onDelete: (id) => ref
                              .read(commentsProvider(post.id).notifier)
                              .delete(id),
                          onEdit: (comment) => _showCommentEditSheet(
                              context, ref, post.id, comment),
                        )),
                  ],
                ],
              ],
            ),
          ),

          // ── Reply input ──
          _CommentInput(
            controller: _commentCtrl,
            focusNode: _commentFocus,
            replyToName: _replyToName,
            onClearReply: _clearReply,
            onSend: _send,
            isSending: _sending,
            chainMode: _chainMode,
            onToggleChain: _toggleChainMode,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Post section
// ---------------------------------------------------------------------------

class _PostSection extends StatelessWidget {
  final Post post;
  const _PostSection({required this.post});

  Color get _tierColor => switch (post.authorTier) {
    NobTier.noble => AppColors.nobNoble,
    NobTier.explorer => AppColors.nobExplorer,
    NobTier.observer => AppColors.nobObserver,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row — anonymous or normal based on post.isAnonymous
          Row(
            children: [
              if (post.isAnonymous)
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _tierColor.withValues(alpha: 0.12),
                    border: Border.all(color: _tierColor.withValues(alpha: 0.25)),
                  ),
                  child: Icon(Icons.visibility_off_rounded, color: _tierColor.withValues(alpha: 0.6), size: 20),
                )
              else
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _tierColor.withValues(alpha: 0.12),
                    border: Border.all(color: _tierColor.withValues(alpha: 0.25)),
                  ),
                  child: post.authorAvatarUrl != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: post.authorAvatarUrl!,
                            fit: BoxFit.cover,
                            width: 44, height: 44,
                          ),
                        )
                      : Center(
                          child: Text(
                            (post.authorName ?? 'N')[0].toUpperCase(),
                            style: TextStyle(color: _tierColor, fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.isAnonymous ? 'Anonymous' : (post.authorName ?? 'Noblara'),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        fontStyle: post.isAnonymous ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _tierColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            post.authorTier.label.toUpperCase(),
                            style: TextStyle(color: _tierColor, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(post.publishedAt ?? post.createdAt),
                          style: TextStyle(color: context.textMuted, fontSize: 12),
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
                            child: const Text('Revised',
                                style: TextStyle(color: AppColors.emerald600, fontSize: 9, fontWeight: FontWeight.w600)),
                          ),
                        ] else if (post.isEdited) ...[
                          const SizedBox(width: 5),
                          Text('edited',
                              style: TextStyle(color: context.textMuted.withValues(alpha: 0.6), fontSize: 10, fontStyle: FontStyle.italic)),
                        ],
                        if (post.editCount > 0) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _showRevisionHistory(context, post.id),
                            child: Text('${post.editCount} ${post.editCount == 1 ? 'revision' : 'revisions'}',
                                style: TextStyle(color: AppColors.emerald600.withValues(alpha: 0.6), fontSize: 10, decoration: TextDecoration.underline)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Original content (shown when Second Thought exists) ──
          if (post.hasSecondThought && post.originalContent != null && post.originalContent!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.surfaceAltColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderColor.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history_rounded, color: context.textMuted, size: 12),
                      const SizedBox(width: 5),
                      Text('Original Thought',
                          style: TextStyle(color: context.textMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post.originalContent!,
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 14,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: context.textMuted.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.auto_fix_high_rounded, color: AppColors.emerald600.withValues(alpha: 0.7), size: 13),
                const SizedBox(width: 5),
                Text('Second Thought',
                    style: TextStyle(color: AppColors.emerald600.withValues(alpha: 0.8), fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                if (post.secondThoughtReason != null && post.secondThoughtReason!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text('— ${post.secondThoughtReason}',
                      style: TextStyle(color: context.textMuted, fontSize: 10.5, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Content
          if (post.isThought && post.content.isNotEmpty)
            Text(
              post.content,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: post.content.length < 120 ? 20 : 16,
                fontStyle: post.content.length < 120 ? FontStyle.italic : FontStyle.normal,
                height: 1.6,
                letterSpacing: 0.1,
              ),
            ),

          if (post.isMoment) ...[
            if (post.photoUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _DetailMomentMedia(photoUrl: post.photoUrl!),
                ),
              ),
            if (post.caption != null && post.caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(post.caption!, style: TextStyle(color: context.textPrimary, fontSize: 15, height: 1.5)),
              ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ---------------------------------------------------------------------------
// _DetailMomentMedia — image for photo, thumbnail + play overlay for video
// ---------------------------------------------------------------------------

class _DetailMomentMedia extends StatelessWidget {
  final String photoUrl;
  const _DetailMomentMedia({required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final isVideo = isVideoUrl(photoUrl);
    final imageUrl = isVideo ? videoThumbnailUrlFor(photoUrl) : photoUrl;
    final fallback = AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: context.surfaceAltColor,
        child: Center(
          child: Icon(
            isVideo
                ? Icons.play_circle_outline_rounded
                : Icons.image_not_supported_outlined,
            color: context.textMuted,
            size: 40,
          ),
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
    return Stack(
      alignment: Alignment.center,
      children: [
        media,
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.55),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
          ),
          child: const Icon(Icons.play_arrow_rounded,
              color: Colors.white, size: 36),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stat chip (reactions count, comments count)
// ---------------------------------------------------------------------------

class _StatChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  const _StatChip({required this.icon, required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: context.textMuted, size: 16),
        const SizedBox(width: 4),
        Text('$count', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: context.textMuted, fontSize: 12)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Action button (reaction in detail view)
// ---------------------------------------------------------------------------

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.emerald600 : context.textMuted;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comment thread (top-level comment + nested replies)
// ---------------------------------------------------------------------------

class _CommentThread extends StatelessWidget {
  final PostComment comment;
  final String? currentUserId;
  final void Function(String authorName) onReply;
  final void Function(String commentId) onDelete;
  final void Function(PostComment comment) onEdit;

  const _CommentThread({
    required this.comment,
    required this.currentUserId,
    required this.onReply,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentRow(
            comment: comment,
            isOwn: comment.userId == currentUserId,
            onReply: () => onReply(comment.authorName ?? 'User'),
            onDelete: () => onDelete(comment.id),
            onEdit: comment.canEdit && comment.userId == currentUserId
                ? () => onEdit(comment) : null,
          ),
          // Replies (indented)
          if (comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Column(
                children: comment.replies.map((r) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _CommentRow(
                    comment: r,
                    isOwn: r.userId == currentUserId,
                    onDelete: () => onDelete(r.id),
                    onEdit: r.canEdit && r.userId == currentUserId
                        ? () => onEdit(r) : null,
                    isReply: true,
                  ),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single comment row
// ---------------------------------------------------------------------------

class _CommentRow extends StatelessWidget {
  final PostComment comment;
  final bool isOwn;
  final VoidCallback? onReply;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final bool isReply;

  const _CommentRow({
    required this.comment,
    required this.isOwn,
    required this.onDelete,
    this.onReply,
    this.onEdit,
    this.isReply = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Comment author avatar (replies always show real identity)
        CircleAvatar(
          radius: isReply ? 12 : 16,
          backgroundColor: AppColors.emerald600.withValues(alpha: 0.12),
          backgroundImage: comment.authorAvatarUrl != null ? NetworkImage(comment.authorAvatarUrl!) : null,
          child: comment.authorAvatarUrl == null
              ? Text(
                  (comment.authorName ?? '?')[0].toUpperCase(),
                  style: TextStyle(color: AppColors.emerald600, fontSize: isReply ? 9 : 11, fontWeight: FontWeight.w600),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    comment.authorName ?? 'User',
                    style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  Text(_ago(comment.createdAt), style: TextStyle(color: context.textMuted, fontSize: 10)),
                  if (comment.isEdited) ...[
                    const SizedBox(width: 4),
                    Text('edited', style: TextStyle(color: context.textMuted.withValues(alpha: 0.5), fontSize: 9, fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(comment.content, style: TextStyle(color: context.textPrimary, fontSize: 14, height: 1.4)),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (onReply != null)
                    GestureDetector(
                      onTap: onReply,
                      child: Text('Reply', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  if (isOwn && comment.canEdit && onEdit != null) ...[
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: onEdit,
                      child: Text('Edit', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  if (isOwn) ...[
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: onDelete,
                      child: Text('Delete', style: TextStyle(color: AppColors.error.withValues(alpha: 0.7), fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}

// ---------------------------------------------------------------------------
// Comment input bar
// ---------------------------------------------------------------------------

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? replyToName;
  final VoidCallback onClearReply;
  final VoidCallback onSend;
  final bool isSending;
  final bool chainMode;
  final VoidCallback onToggleChain;

  const _CommentInput({
    required this.controller,
    required this.focusNode,
    required this.replyToName,
    required this.onClearReply,
    required this.onSend,
    required this.isSending,
    required this.chainMode,
    required this.onToggleChain,
  });

  @override
  Widget build(BuildContext context) {
    final hint = chainMode
        ? 'Continue the thought…'
        : (replyToName != null ? 'Write a reply…' : 'Write a reply…');

    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 8, 8 + MediaQuery.of(context).viewPadding.bottom),
      decoration: BoxDecoration(
        color: AppColors.nobSurface,
        border: Border(top: BorderSide(color: context.borderSubtleColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chainMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.link_rounded, color: AppColors.emerald350, size: 14),
                  const SizedBox(width: 4),
                  Text('Adding to the Soul Chain',
                      style: TextStyle(
                        color: AppColors.emerald350,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      )),
                  const Spacer(),
                  GestureDetector(
                    onTap: onToggleChain,
                    child: Icon(Icons.close, color: context.textMuted, size: 16),
                  ),
                ],
              ),
            )
          else if (replyToName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.reply_rounded, color: AppColors.emerald600, size: 14),
                  const SizedBox(width: 4),
                  Text('Replying to $replyToName', style: TextStyle(color: AppColors.emerald600, fontSize: 12)),
                  const Spacer(),
                  GestureDetector(
                    onTap: onClearReply,
                    child: Icon(Icons.close, color: context.textMuted, size: 16),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              // Soul Chain toggle — only shown when not actively replying to a comment
              if (replyToName == null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: onToggleChain,
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: chainMode
                            ? AppColors.emerald600.withValues(alpha: 0.18)
                            : Colors.transparent,
                        border: Border.all(
                          color: chainMode
                              ? AppColors.emerald600.withValues(alpha: 0.55)
                              : context.borderSubtleColor,
                        ),
                      ),
                      child: Icon(
                        Icons.link_rounded,
                        size: 18,
                        color: chainMode ? AppColors.emerald350 : context.textMuted,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLength: 280,
                  maxLengthEnforcement:
                      MaxLengthEnforcement.truncateAfterCompositionEnds,
                  maxLines: 3,
                  minLines: 1,
                  style: TextStyle(color: context.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: context.textMuted, fontSize: 14),
                    counterText: '',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: context.bgColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: isSending ? null : onSend,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.emerald600,
                  ),
                  child: isSending
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                        )
                      : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
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
// Soul Chain section — flat, vertically connected continuation thread
// ---------------------------------------------------------------------------

class _SoulChainSection extends StatelessWidget {
  final List<PostComment> chains;
  final String? currentUserId;
  final void Function(String commentId) onDelete;

  const _SoulChainSection({
    required this.chains,
    required this.currentUserId,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded,
                  color: AppColors.emerald350, size: 14),
              const SizedBox(width: 6),
              Text(
                'SOUL CHAIN',
                style: TextStyle(
                  color: AppColors.emerald350,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${chains.length} ${chains.length == 1 ? 'thought' : 'thoughts'}',
                style: TextStyle(color: context.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'A chain of continued thoughts on this Nob.',
            style: TextStyle(color: context.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          // Chain links — vertical thread connector
          for (int i = 0; i < chains.length; i++)
            _ChainLink(
              comment: chains[i],
              isFirst: i == 0,
              isLast: i == chains.length - 1,
              isOwn: chains[i].userId == currentUserId,
              onDelete: () => onDelete(chains[i].id),
            ),
        ],
      ),
    );
  }
}

class _ChainLink extends StatelessWidget {
  final PostComment comment;
  final bool isFirst;
  final bool isLast;
  final bool isOwn;
  final VoidCallback onDelete;

  const _ChainLink({
    required this.comment,
    required this.isFirst,
    required this.isLast,
    required this.isOwn,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connector column: vertical line + node
          SizedBox(
            width: 28,
            child: Column(
              children: [
                // Top spacer with line (skipped for first)
                Expanded(
                  flex: 0,
                  child: Container(
                    width: 1.5,
                    height: 6,
                    color: isFirst
                        ? Colors.transparent
                        : AppColors.emerald600.withValues(alpha: 0.45),
                  ),
                ),
                // Node dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.emerald600.withValues(alpha: 0.18),
                    border: Border.all(
                      color: AppColors.emerald600.withValues(alpha: 0.7),
                      width: 1.5,
                    ),
                  ),
                ),
                // Bottom line (skipped for last)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: isLast
                        ? Colors.transparent
                        : AppColors.emerald600.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Chain content card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.nobSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.emerald600.withValues(alpha: 0.20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.authorName ?? 'User',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _ago(comment.createdAt),
                          style: TextStyle(color: context.textMuted, fontSize: 10),
                        ),
                        const Spacer(),
                        if (isOwn)
                          GestureDetector(
                            onTap: onDelete,
                            child: Icon(Icons.delete_outline_rounded,
                                color: AppColors.error.withValues(alpha: 0.7),
                                size: 14),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment.content,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}

// ---------------------------------------------------------------------------
// Revision history sheet
// ---------------------------------------------------------------------------

void _showRevisionHistory(BuildContext context, String postId) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.nobSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _RevisionHistorySheet(postId: postId),
  );
}

class _RevisionHistorySheet extends ConsumerWidget {
  final String postId;
  const _RevisionHistorySheet({required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.nobBorder, borderRadius: BorderRadius.circular(2))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, color: AppColors.emerald600, size: 18),
                const SizedBox(width: 8),
                Text('Revision History',
                    style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.nobBorder),
          Expanded(
            child: FutureBuilder<List<PostRevision>>(
              future: ref.read(postRepositoryProvider).fetchRevisions(postId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.emerald600)));
                }
                final revisions = snap.data ?? [];
                if (revisions.isEmpty) {
                  return Center(child: Text('No revisions yet.',
                      style: TextStyle(color: context.textMuted, fontSize: 13)));
                }
                return ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount: revisions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (_, i) {
                    final r = revisions[i];
                    final isSecond = r.isSecondThought;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSecond ? AppColors.emerald600.withValues(alpha: 0.1) : context.surfaceAltColor,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: isSecond ? AppColors.emerald600.withValues(alpha: 0.3) : context.borderColor),
                            ),
                            child: Text(isSecond ? 'Second Thought' : 'Minor Edit',
                                style: TextStyle(color: isSecond ? AppColors.emerald600 : context.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          Text('v${r.revisionNumber}', style: TextStyle(color: context.textMuted, fontSize: 10)),
                          const Spacer(),
                          Text(_fmtTime(r.createdAt), style: TextStyle(color: context.textMuted, fontSize: 10)),
                        ]),
                        if (r.reason != null && r.reason!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(r.reason!, style: TextStyle(color: context.textMuted, fontSize: 11, fontStyle: FontStyle.italic)),
                        ],
                        const SizedBox(height: 8),
                        Text(r.previousContent, maxLines: 4, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: context.textMuted, fontSize: 12, height: 1.4,
                              decoration: TextDecoration.lineThrough, decorationColor: context.textMuted.withValues(alpha: 0.3))),
                        const SizedBox(height: 6),
                        Text(r.newContent, maxLines: 4, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: context.textPrimary, fontSize: 12, height: 1.4)),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtTime(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${dt.day}/${dt.month}';
  }
}

// ---------------------------------------------------------------------------
// Comment edit sheet
// ---------------------------------------------------------------------------

void _showCommentEditSheet(
    BuildContext context, WidgetRef ref, String postId, PostComment comment) {
  final ctrl = TextEditingController(text: comment.content);
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
          Row(children: [
            Icon(Icons.edit_outlined, color: ctx.textSecondary, size: 16),
            const SizedBox(width: 8),
            Text('Edit Comment', style: TextStyle(color: ctx.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${3 - comment.editCount} edits left',
                style: TextStyle(color: ctx.textMuted, fontSize: 11)),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            maxLines: null,
            minLines: 2,
            maxLength: 280,
            autofocus: true,
            style: TextStyle(color: ctx.textPrimary, fontSize: 14, height: 1.5),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ctx.borderColor)),
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
                final result = await ref
                    .read(commentsProvider(postId).notifier)
                    .editComment(comment.id, text);
                if (!result.ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.error ?? 'Edit failed')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    ),
  );
}
