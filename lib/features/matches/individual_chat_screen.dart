import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/enums/noble_mode.dart';
import '../../core/utils/mock_mode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/premium.dart';
import '../../data/models/inbox_item.dart';
import '../../data/models/match.dart';
import '../../data/models/message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/match_provider.dart';
import '../../providers/messages_provider.dart';
import '../../services/gemini_service.dart';
import '../../core/services/toast_service.dart';
import '../bff/bff_plan_screen.dart';
import '../match/real_meeting_screen.dart';
import '../match/video_scheduling_screen.dart';
import 'end_connection_screen.dart';

// ---------------------------------------------------------------------------
// Individual Chat Screen — 1-on-1 for Date & BFF alliances
// ---------------------------------------------------------------------------

class IndividualChatScreen extends ConsumerStatefulWidget {
  final InboxItem item;
  final String conversationId;
  final String? matchId;

  const IndividualChatScreen({
    super.key,
    required this.item,
    required this.conversationId,
    this.matchId,
  });

  @override
  ConsumerState<IndividualChatScreen> createState() =>
      _IndividualChatState();
}

class _IndividualChatState extends ConsumerState<IndividualChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _chatNudge;
  bool _nudgeDismissed = false;
  int _lastMessageCount = 0;
  final List<ChatMessage> _pendingMessages = [];

  InboxItem get _item => widget.item;
  Color get _accent => _item.mode.accentColor;
  bool get _isBff => _item.mode == NobleMode.bff;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(authProvider).userId;
      if (userId != null) {
        final repo = ref.read(messagesRepositoryProvider);
        repo.markRead(conversationId: widget.conversationId, userId: userId);
        repo.markDelivered(conversationId: widget.conversationId, userId: userId);
        repo.markMessagesRead(conversationId: widget.conversationId, userId: userId);
      }
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _suggestBffOpener() async {
    // Check AI message softening setting
    if (!isMockMode) {
      final uid = ref.read(authProvider).userId;
      if (uid != null) {
        try {
          final row = await Supabase.instance.client.from('profiles')
              .select('ai_writing_help').eq('id', uid).maybeSingle();
          final prefs = row?['ai_writing_help'] as Map<String, dynamic>?;
          if (prefs != null && prefs['message_softening'] == false) {
            if (mounted) {
              ToastService.show(context, message: 'AI conversation help is turned off', type: ToastType.system);
            }
            return;
          }
        } catch (e) { debugPrint('[chat] AI prefs check failed: $e'); }
      }
    }

    try {
      final opener = await GeminiService.generateBffOpener(
        userName: 'You',
        otherName: _item.name,
      );
      if (mounted) {
        _msgCtrl.text = opener;
      }
    } catch (e) {
      debugPrint('[chat] BFF opener generation failed: $e');
      if (mounted) {
        _msgCtrl.text = 'Hey ${_item.name}! Looks like we have some things in common.';
      }
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();

    final authState = ref.read(authProvider);
    final userId = authState.userId;
    if (userId == null) return;

    final displayName = ref.read(profileProvider).profile?.displayName ?? 'User';

    // Optimistic insert — show message immediately before server confirms
    final optimistic = ChatMessage(
      id: 'pending-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversationId,
      senderId: userId,
      senderDisplayName: displayName,
      content: text,
      mode: _item.mode.name,
      createdAt: DateTime.now(),
    );
    setState(() => _pendingMessages.add(optimistic));
    _scrollToBottom();

    try {
      await ref.read(messagesRepositoryProvider).sendMessage(
            conversationId: widget.conversationId,
            senderId: userId,
            senderDisplayName: displayName,
            content: text,
            mode: _item.mode.name,
          );
      // Server confirmed — pending message will be replaced by stream
      if (mounted) setState(() => _pendingMessages.remove(optimistic));
    } catch (e) {
      // Remove optimistic message and restore text for retry
      if (mounted) {
        setState(() => _pendingMessages.remove(optimistic));
        _msgCtrl.text = text;
        ToastService.show(context, message: 'Message failed to send', type: ToastType.error);
      }
    }
  }

  /// Check if conversation is silent for 24h+ and show AI nudge
  void _checkForNudge(List<ChatMessage> msgs) {
    if (_nudgeDismissed || _chatNudge != null) return;
    if (msgs.isEmpty) return;
    final last = msgs.last;
    final hoursSinceLast =
        DateTime.now().difference(last.createdAt).inHours;
    if (hoursSinceLast >= 24) {
      GeminiService.suggestChatNudge(
        userName: 'You',
        otherName: _item.name,
        lastMessageContent: last.content,
      ).then((nudge) {
        if (mounted) setState(() => _chatNudge = nudge);
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<_Msg> _buildMessages(List<ChatMessage> chatMessages, String? currentUserId) {
    return chatMessages.map((m) {
      final isSelf = m.senderId != null && m.senderId == currentUserId;
      final isPending = m.id.startsWith('pending-');
      return _Msg(
        sender: m.senderDisplayName,
        avatarSeed: m.senderId ?? '',
        photoUrl: isSelf ? null : _item.photoUrl,
        text: m.content,
        time: m.createdAt,
        isSelf: isSelf,
        isSystem: m.isSystem,
        isPending: isPending,
        isDelivered: m.isDelivered,
        isRead: m.isRead,
      );
    }).toList();
  }

  void _showQuickIntroSheet(BuildContext context, List<NobleMatch> matches) {
    final name = _item.name;
    final match = widget.matchId != null
        ? matches.where((m) => m.id == widget.matchId).firstOrNull
        : null;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.surfaceAltColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Quick Intro',
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Start a short intro with $name',
              style: TextStyle(
                  color: context.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: [
                Expanded(
                  child: _IntroOption(
                    icon: Icons.videocam_rounded,
                    label: 'Video',
                    subtitle: match != null ? 'Schedule call' : 'Coming soon',
                    color: match != null ? _accent : context.textDisabled,
                    onTap: match != null
                        ? () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    VideoSchedulingScreen(match: match),
                              ),
                            );
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _IntroOption(
                    icon: Icons.mic_rounded,
                    label: 'Voice',
                    subtitle: 'Coming soon',
                    color: context.textDisabled,
                    onTap: null,
                  ),
                ),
              ],
            ),
            SizedBox(
                height: MediaQuery.of(context).padding.bottom + AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final currentUserId = ref.watch(authProvider).userId;
    final messagesAsync =
        ref.watch(messagesStreamProvider(widget.conversationId));

    // Check if this match has been closed
    final matchState = ref.watch(matchProvider);
    final isClosed = widget.matchId != null &&
        matchState.matches
            .any((m) => m.id == widget.matchId && m.status == 'closed');

    final isLoadingMessages = messagesAsync.isLoading;
    final rawMsgs = messagesAsync.valueOrNull ?? [];
    // Check for AI nudge after frame builds (avoid setState during build)
    if (rawMsgs.isNotEmpty && !_nudgeDismissed && _chatNudge == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkForNudge(rawMsgs);
      });
    }
    // Merge server messages with pending optimistic messages
    final allMsgs = [...rawMsgs, ..._pendingMessages.where(
      (p) => !rawMsgs.any((r) => r.content == p.content && r.senderId == p.senderId),
    )];
    final messages = _buildMessages(allMsgs, currentUserId);

    // Auto-scroll only when new messages arrive (not on every rebuild)
    if (messages.length > _lastMessageCount && messages.isNotEmpty) {
      _scrollToBottom();
    }
    _lastMessageCount = messages.length;

    return Scaffold(
      backgroundColor: _item.mode.bgTint,
      appBar: AppBar(
        backgroundColor: _item.mode.bgTint,
        leading: const BackButton(),
        titleSpacing: 0,
        title: Row(
          children: [
            // Avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: _item.photoUrl ?? 'https://picsum.photos/seed/${_item.avatarSeed}/80/80',
                  fit: BoxFit.cover,
                  memCacheWidth: 200,
                  placeholder: (_, __) => CircleAvatar(
                    backgroundColor: accent.withValues(alpha: 0.2),
                    child: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (_, __, ___) => CircleAvatar(
                    backgroundColor: accent.withValues(alpha: 0.2),
                    child: Text(
                      _item.name[0],
                      style: TextStyle(
                          color: accent, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Name + mode label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _item.name,
                    style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _item.mode.label,
                        style: TextStyle(color: accent, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (widget.matchId != null)
            IconButton(
              icon: Icon(_isBff ? Icons.coffee_rounded : Icons.handshake_rounded, color: accent),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _isBff
                      ? BffPlanScreen(conversationId: _item.id)
                      : RealMeetingScreen(
                          matchId: widget.matchId!,
                          otherUserName: _item.name,
                        ),
                ),
              ),
              tooltip: _isBff ? 'Make a plan' : 'Plan Meeting',
            ),
          IconButton(
            icon: Icon(Icons.video_call_rounded, color: accent),
            onPressed: () =>
                _showQuickIntroSheet(context, matchState.matches),
            tooltip: 'Quick Intro',
          ),
          if (widget.matchId != null)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: context.textMuted),
              color: context.surfaceColor,
              onSelected: (v) {
                if (v == 'end') {
                  final match = matchState.matches.where((m) => m.id == widget.matchId).firstOrNull;
                  Navigator.push(context, MaterialPageRoute(builder: (_) => EndConnectionScreen(
                    matchId: widget.matchId!,
                    otherUserId: match?.otherUserId ?? '',
                    otherUserName: _item.name,
                    otherUserPhotoUrl: match?.otherUserPhotoUrl,
                  )));
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'end', child: Row(children: [
                  Icon(Icons.link_off_rounded, color: context.textMuted, size: 18),
                  const SizedBox(width: 8),
                  Text('End this connection', style: TextStyle(color: context.textPrimary, fontSize: 14)),
                ])),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Closed banner
          if (isClosed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              color: AppColors.error.withValues(alpha: 0.12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link_off_rounded,
                      color: AppColors.error, size: 14),
                  SizedBox(width: AppSpacing.xs),
                  Text(
                    'This conversation has closed',
                    style: TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          // BFF: expertise bar pinned below AppBar
          if (_isBff && _item.expertise != null)
            _ExpertiseBar(item: _item, accentColor: accent),
          // AI Chat Unblock nudge banner (after 24h silence)
          if (_chatNudge != null && !_nudgeDismissed)
            Container(
              margin: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.emerald600.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.emerald600.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: AppColors.emerald600, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _msgCtrl.text = _chatNudge!;
                        setState(() => _nudgeDismissed = true);
                      },
                      child: Text(
                        'Pick a direction? "$_chatNudge"',
                        style: TextStyle(
                          color: AppColors.emerald600.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _nudgeDismissed = true),
                    child: Icon(Icons.close,
                        color: context.textMuted, size: 16),
                  ),
                ],
              ),
            ),
          // Messages list
          Expanded(
            child: isLoadingMessages
                ? Center(
                    child: CircularProgressIndicator(color: accent),
                  )
                : messages.isEmpty
                    ? Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                          decoration: Premium.emptyStateDecoration(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      accent.withValues(alpha: 0.12),
                                      accent.withValues(alpha: 0.04),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.15),
                                    width: 0.5,
                                  ),
                                ),
                                child: Icon(
                                  _isBff ? Icons.handshake_outlined : Icons.chat_bubble_outline_rounded,
                                  color: accent.withValues(alpha: 0.6), size: 24,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text('Say hello',
                                  style: TextStyle(color: context.textPrimary, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
                              const SizedBox(height: 6),
                              Text(
                                _isBff ? 'Good friendships start with a single message' : 'The best conversations start simply',
                                style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.4),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: messages.length,
                        itemBuilder: (context, i) {
                          return _MsgBubble(msg: messages[i], accentColor: accent);
                        },
                      ),
          ),
          // BFF opener helper — shown when chat is empty
          if (_isBff && messages.isEmpty && !isClosed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: GestureDetector(
                onTap: _suggestBffOpener,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: accent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: accent, size: 16),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text('Stuck? Tap for a conversation starter.',
                            style: TextStyle(color: accent, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Input bar
          _ChatInputBar(
            controller: _msgCtrl,
            accentColor: accent,
            hint: isClosed ? 'This conversation has closed' : 'Write something...',
            onSend: isClosed ? null : _send,
          ),
          // Encrypted connection footer
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 4, top: 4),
            color: context.elevatedColor,
            child: Center(
              child: Text(
                'ENCRYPTED CONNECTION',
                style: TextStyle(
                  color: context.textDisabled,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expertise bar (BFF mode only)
// ---------------------------------------------------------------------------

class _ExpertiseBar extends StatelessWidget {
  final InboxItem item;
  final Color accentColor;

  const _ExpertiseBar({required this.item, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      color: context.surfaceColor,
      child: Row(
        children: [
          Icon(Icons.business_center_rounded, color: accentColor, size: 12),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              item.expertise!,
              style: TextStyle(color: accentColor, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (item.connectionGoal != null) ...[
            const SizedBox(width: AppSpacing.md),
            Icon(Icons.handshake_outlined,
                color: accentColor.withValues(alpha: 0.65), size: 12),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                item.connectionGoal!,
                style: TextStyle(
                    color: accentColor.withValues(alpha: 0.65), fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick Intro option button
// ---------------------------------------------------------------------------

class _IntroOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _IntroOption({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                    color: context.textDisabled, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message bubble
// ---------------------------------------------------------------------------

String _formatTime(DateTime time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

class _MsgBubble extends StatelessWidget {
  final _Msg msg;
  final Color accentColor;

  const _MsgBubble({required this.msg, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    if (msg.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(
          child: Text(
            msg.text,
            style: TextStyle(color: context.textMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment:
            msg.isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isSelf) ...[
            ClipOval(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CachedNetworkImage(
                  imageUrl: msg.photoUrl ?? 'https://picsum.photos/seed/${msg.avatarSeed}/40/40',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  memCacheWidth: 96,
                  placeholder: (_, __) => CircleAvatar(
                    radius: 16,
                    backgroundColor: accentColor.withValues(alpha: 0.25),
                    child: const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (_, __, ___) => CircleAvatar(
                    radius: 16,
                    backgroundColor: accentColor.withValues(alpha: 0.25),
                    child: Text(
                      msg.sender.isNotEmpty ? msg.sender[0] : '?',
                      style: TextStyle(
                          color: accentColor, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                gradient: msg.isSelf
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accentColor, accentColor.withValues(alpha: 0.85)],
                      )
                    : null,
                color: msg.isSelf ? null : context.surfaceColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppSpacing.radiusLg),
                  topRight: const Radius.circular(AppSpacing.radiusLg),
                  bottomLeft:
                      Radius.circular(msg.isSelf ? AppSpacing.radiusLg : 6),
                  bottomRight:
                      Radius.circular(msg.isSelf ? 6 : AppSpacing.radiusLg),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (msg.isSelf ? accentColor : Colors.black)
                        .withValues(alpha: msg.isSelf ? 0.12 : 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: msg.isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: TextStyle(
                      color: msg.isSelf ? AppColors.textOnEmerald : context.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(msg.time),
                        style: TextStyle(
                          color: msg.isSelf
                              ? AppColors.textOnEmerald.withValues(alpha: 0.6)
                              : context.textDisabled,
                          fontSize: 10,
                        ),
                      ),
                      if (msg.isSelf) ...[
                        const SizedBox(width: 3),
                        _StatusIcon(
                          msg: msg,
                          color: AppColors.textOnEmerald.withValues(alpha: 0.6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat input bar
// ---------------------------------------------------------------------------

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final Color accentColor;
  final String hint;
  final VoidCallback? onSend;

  const _ChatInputBar({
    required this.controller,
    required this.accentColor,
    required this.hint,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.elevatedColor,
        border: Border(top: BorderSide(color: context.borderSubtleColor.withValues(alpha: 0.3), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: context.textMuted),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                filled: true,
                fillColor: context.surfaceAltColor,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusCircle),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: onSend != null ? (_) => onSend!() : null,
              enabled: onSend != null,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          PressEffect(
            onTap: onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: onSend != null
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [accentColor, accentColor.withValues(alpha: 0.85)],
                      )
                    : null,
                color: onSend != null ? null : context.surfaceAltColor,
                shape: BoxShape.circle,
                boxShadow: onSend != null
                    ? Premium.accentGlow(accentColor, intensity: 0.6)
                    : null,
              ),
              child: Icon(Icons.send_rounded,
                  color: onSend != null ? context.bgColor : context.textDisabled,
                  size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message data class
// ---------------------------------------------------------------------------

class _Msg {
  final String sender;
  final String avatarSeed;
  final String? photoUrl;
  final String text;
  final DateTime time;
  final bool isSelf;
  final bool isSystem;
  final bool isPending;
  final bool isDelivered;
  final bool isRead;

  _Msg({
    required this.sender,
    required this.avatarSeed,
    this.photoUrl,
    required this.text,
    required this.time,
    this.isSelf = false,
    this.isSystem = false,
    this.isPending = false,
    this.isDelivered = false,
    this.isRead = false,
  });
}

// ---------------------------------------------------------------------------
// Delivery / read status icon
// ---------------------------------------------------------------------------

class _StatusIcon extends StatelessWidget {
  final _Msg msg;
  final Color color;

  const _StatusIcon({required this.msg, required this.color});

  @override
  Widget build(BuildContext context) {
    if (msg.isPending) {
      return Icon(Icons.schedule_rounded, size: 12, color: color);
    }
    if (msg.isRead) {
      return Icon(Icons.done_all_rounded, size: 12, color: AppColors.emerald500);
    }
    if (msg.isDelivered) {
      return Icon(Icons.done_all_rounded, size: 12, color: color);
    }
    // Sent (reached server)
    return Icon(Icons.done_rounded, size: 12, color: color);
  }
}
