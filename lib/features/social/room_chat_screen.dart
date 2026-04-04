import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/room.dart';
import '../../data/models/room_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import 'edit_room_screen.dart';

const _violet = AppColors.violet;

class RoomChatScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String hostId;
  final String roomTitle;

  const RoomChatScreen({
    super.key,
    required this.roomId,
    required this.hostId,
    required this.roomTitle,
  });

  @override
  ConsumerState<RoomChatScreen> createState() => _RoomChatScreenState();
}

class _RoomChatScreenState extends ConsumerState<RoomChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = (roomId: widget.roomId, hostId: widget.hostId);
    final chatState = ref.watch(roomChatProvider(args));
    final currentUserId = ref.watch(authProvider).userId;
    final isHost = currentUserId == widget.hostId;
    final pinned = chatState.pinnedMessages;

    // Scroll to bottom when new messages arrive
    ref.listen(roomChatProvider(args), (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.roomTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              '${chatState.participants.length} participants',
              style: TextStyle(
                color: context.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          // Edit button (host only)
          if (isHost)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              color: _violet,
              onPressed: () async {
                final room = Room(
                  id: widget.roomId,
                  hostId: widget.hostId,
                  title: widget.roomTitle,
                  topicTags: const [],
                  lastActivityAt: DateTime.now(),
                  createdAt: DateTime.now(),
                );
                final edited = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => EditRoomScreen(room: room)),
                );
                if (edited == true) {
                  ref.invalidate(roomChatProvider(args));
                  ref.read(roomListProvider.notifier).load();
                }
              },
            ),
          // Participants button
          IconButton(
            icon: const Icon(Icons.people_outline_rounded),
            color: _violet,
            onPressed: () => _showParticipants(context, chatState),
          ),
          // Leave button
          IconButton(
            icon: const Icon(Icons.exit_to_app_rounded),
            color: context.textMuted,
            onPressed: () => _leaveRoom(context, args),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Pinned / Flagged messages ──
          if (pinned.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                border: Border(
                  bottom: BorderSide(
                    color: context.borderSubtleColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PINNED',
                    style: TextStyle(
                      color: context.textDisabled,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ...pinned.take(3).map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            if (m.goldFlagged)
                              const Icon(Icons.push_pin_rounded,
                                  color: AppColors.gold, size: 12)
                            else
                              Icon(Icons.flag_rounded,
                                  color: Colors.blue.shade300, size: 12),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${m.senderName ?? 'User'}: ${m.content}',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),

          // ── Messages ──
          Expanded(
            child: chatState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _violet),
                  )
                : chatState.messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet.\nBe the first to say something!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, i) {
                          final msg = chatState.messages[i];
                          final isSelf = msg.senderId == currentUserId;
                          return _MessageBubble(
                            message: msg,
                            isSelf: isSelf,
                            isHost: isHost,
                            onGoldFlag: isHost
                                ? () => _flagGold(args, msg.id)
                                : null,
                            onBlueFlag: !isSelf
                                ? () => _flagBlue(args, msg.id)
                                : null,
                          );
                        },
                      ),
          ),

          // ── Input bar ──
          Container(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
              MediaQuery.of(context).padding.bottom + AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border(
                top: BorderSide(color: context.borderSubtleColor, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Say something...',
                      hintStyle: TextStyle(color: context.textDisabled),
                      filled: true,
                      fillColor: context.surfaceAltColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusCircle),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _send(args),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                GestureDetector(
                  onTap: () => _send(args),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: _violet,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _send(({String roomId, String hostId}) args) {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(roomChatProvider(args).notifier).sendMessage(text);
    _inputCtrl.clear();
  }

  Future<void> _flagGold(
      ({String roomId, String hostId}) args, String messageId) async {
    final result =
        await ref.read(roomChatProvider(args).notifier).flagGold(messageId);
    if (!mounted) return;
    if (result != 'flagged') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result), backgroundColor: context.surfaceColor),
      );
    }
  }

  Future<void> _flagBlue(
      ({String roomId, String hostId}) args, String messageId) async {
    await ref.read(roomChatProvider(args).notifier).flagBlue(messageId);
  }

  Future<void> _leaveRoom(
      BuildContext context, ({String roomId, String hostId}) args) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Leave room?',
            style: TextStyle(color: context.textPrimary)),
        content: Text('You can rejoin anytime while the room is active.',
            style: TextStyle(color: context.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(roomChatProvider(args).notifier).leaveRoom();
    if (context.mounted) Navigator.pop(context);
  }

  void _showParticipants(BuildContext context, RoomChatState chatState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.borderColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'Participants (${chatState.participants.length})',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...chatState.participants.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: _violet.withValues(alpha: 0.2),
                        backgroundImage: p.avatarUrl != null
                            ? NetworkImage(p.avatarUrl!)
                            : null,
                        child: p.avatarUrl == null
                            ? Text(
                                (p.displayName ?? '?')[0].toUpperCase(),
                                style: const TextStyle(
                                    color: _violet, fontSize: 13),
                              )
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        p.displayName ?? 'User',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      if (p.userId == widget.hostId) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: _violet.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Host',
                            style: TextStyle(
                              color: _violet,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                )),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final RoomMessage message;
  final bool isSelf;
  final bool isHost;
  final VoidCallback? onGoldFlag;
  final VoidCallback? onBlueFlag;

  const _MessageBubble({
    required this.message,
    required this.isSelf,
    required this.isHost,
    this.onGoldFlag,
    this.onBlueFlag,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isSelf) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: _violet.withValues(alpha: 0.15),
              backgroundImage: message.senderAvatarUrl != null
                  ? NetworkImage(message.senderAvatarUrl!)
                  : null,
              child: message.senderAvatarUrl == null
                  ? Text(
                      (message.senderName ?? '?')[0].toUpperCase(),
                      style: const TextStyle(color: _violet, fontSize: 10),
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showActions(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: isSelf
                      ? _violet.withValues(alpha: 0.15)
                      : context.elevatedColor,
                  border: Border.all(
                    color: message.goldFlagged
                        ? AppColors.gold.withValues(alpha: 0.5)
                        : message.blueFlagged
                            ? Colors.blue.withValues(alpha: 0.3)
                            : isSelf
                                ? _violet.withValues(alpha: 0.2)
                                : context.borderSubtleColor,
                    width: message.goldFlagged || message.blueFlagged ? 1 : 0.5,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AppSpacing.radiusLg),
                    topRight: const Radius.circular(AppSpacing.radiusLg),
                    bottomLeft: Radius.circular(
                        isSelf ? AppSpacing.radiusLg : 4),
                    bottomRight: Radius.circular(
                        isSelf ? 4 : AppSpacing.radiusLg),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isSelf)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.senderName ?? 'User',
                            style: TextStyle(
                              color: message.isHost ? _violet : context.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (message.isHost) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: _violet.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'Host',
                                style: TextStyle(
                                  color: _violet,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          if (message.goldFlagged) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.push_pin_rounded,
                                color: AppColors.gold, size: 11),
                          ],
                          if (message.blueFlagged) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.flag_rounded,
                                color: Colors.blue.shade300, size: 11),
                          ],
                        ],
                      ),
                    if (!isSelf) const SizedBox(height: 2),
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isSelf
                            ? context.textPrimary
                            : context.textSecondary,
                        fontSize: 14,
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

  void _showActions(BuildContext context) {
    if (onGoldFlag == null && onBlueFlag == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onGoldFlag != null)
              ListTile(
                leading: const Icon(Icons.push_pin_rounded,
                    color: AppColors.gold),
                title: Text('Gold Pin',
                    style: TextStyle(color: context.textPrimary)),
                subtitle: Text('Pin this message (max 3)',
                    style: TextStyle(color: context.textMuted, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  onGoldFlag!();
                },
              ),
            if (onBlueFlag != null)
              ListTile(
                leading: Icon(Icons.flag_rounded, color: Colors.blue.shade300),
                title: Text('Blue Flag',
                    style: TextStyle(color: context.textPrimary)),
                subtitle: Text('Flag this message',
                    style: TextStyle(color: context.textMuted, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  onBlueFlag!();
                },
              ),
          ],
        ),
      ),
    );
  }
}
