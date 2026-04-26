import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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
import '../../data/models/message_reaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/match_provider.dart';
import '../../providers/messages_provider.dart';
import '../../providers/user_report_provider.dart';
import '../../services/gemini_service.dart';
import '../../core/services/toast_service.dart';
import '../bff/bff_plan_screen.dart';
import '../match/real_meeting_screen.dart';
import '../match/video_scheduling_screen.dart';
import '../noblara_feed/user_profile_screen.dart';
import 'end_connection_screen.dart';

// Available reaction emojis
const _reactionEmojis = ['❤️', '😂', '👍', '😮', '😢', '🔥'];

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

  // Typing indicator
  RealtimeChannel? _typingChannel;
  bool _otherTyping = false;
  Timer? _typingDebounce;
  Timer? _typingTimeout;
  bool _iAmTyping = false;

  // Search
  bool _searchMode = false;
  final _searchCtrl = TextEditingController();
  List<ChatMessage>? _searchResults;

  // Reactions
  Map<String, List<MessageReaction>> _reactions = {};

  // Media upload
  bool _uploading = false;

  // Expiry guard — set once on load, blocks send + input
  bool _isExpired = false;

  // Older messages pagination
  final List<ChatMessage> _olderMessages = [];
  bool _loadingOlder = false;
  bool _noMoreOlder = false;

  InboxItem get _item => widget.item;
  Color get _accent => _item.mode.accentColor;
  bool get _isBff => _item.mode == NobleMode.bff;

  @override
  void initState() {
    super.initState();
    _msgCtrl.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(authProvider).userId;
      if (userId != null) {
        final repo = ref.read(messagesRepositoryProvider);
        repo.markRead(conversationId: widget.conversationId, userId: userId);
        repo.markDelivered(conversationId: widget.conversationId, userId: userId);
        repo.markMessagesRead(conversationId: widget.conversationId, userId: userId).then((_) {
          ref.invalidate(unreadMessageCountProvider);
        });
      }
      _initTypingChannel();
      _loadReactions();
      _checkMatchExpiry();
    });
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _typingTimeout?.cancel();
    _typingChannel?.unsubscribe();
    _msgCtrl.removeListener(_onTextChanged);
    _msgCtrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Typing indicator via Supabase Realtime Broadcast ──

  void _initTypingChannel() {
    if (isMockMode) return;
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;
    _typingChannel = ref.read(messagesRepositoryProvider).subscribeToTyping(
      widget.conversationId,
      userId,
      (_) {
        if (!mounted) return;
        setState(() => _otherTyping = true);
        _typingTimeout?.cancel();
        _typingTimeout = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _otherTyping = false);
        });
      },
    );
  }

  void _onTextChanged() {
    if (_msgCtrl.text.trim().isEmpty) {
      _iAmTyping = false;
      return;
    }
    if (!_iAmTyping) {
      _iAmTyping = true;
      _broadcastTyping();
    }
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      _iAmTyping = false;
    });
  }

  void _broadcastTyping() {
    final userId = ref.read(authProvider).userId;
    if (userId == null || isMockMode) return;
    _typingChannel?.sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': userId},
    );
  }

  // ── Reactions ──

  Future<void> _loadReactions() async {
    final repo = ref.read(messagesRepositoryProvider);
    final msgs = ref.read(messagesStreamProvider(widget.conversationId)).valueOrNull ?? [];
    if (msgs.isEmpty) return;
    final ids = msgs.map((m) => m.id).where((id) => !id.startsWith('pending-')).toList();
    if (ids.isEmpty) return;
    try {
      final result = await repo.fetchReactionsForMessages(ids);
      if (mounted) setState(() => _reactions = result);
    } catch (e) {
      debugPrint('[chat] Load reactions failed: $e');
    }
  }

  Future<void> _toggleReaction(String messageId, String emoji) async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;
    final repo = ref.read(messagesRepositoryProvider);
    final existing = _reactions[messageId] ?? [];
    final mine = existing.where((r) => r.userId == userId && r.emoji == emoji);
    try {
      if (mine.isNotEmpty) {
        await repo.removeReaction(messageId: messageId, userId: userId, emoji: emoji);
      } else {
        await repo.addReaction(messageId: messageId, userId: userId, emoji: emoji);
      }
      await _loadReactions();
    } catch (e) {
      if (mounted) ToastService.show(context, message: 'Could not update reaction', type: ToastType.error);
    }
  }

  // ── Media send ──

  Future<void> _pickAndSendImage() async {
    // Guard: check match expiry before allowing media send
    if (_isExpired) {
      if (mounted) ToastService.show(context, message: 'This conversation has ended', type: ToastType.error);
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final mime = picked.mimeType ?? 'image/jpeg';
    final authState = ref.read(authProvider);
    final userId = authState.userId;
    if (userId == null) return;
    final displayName = ref.read(profileProvider).profile?.displayName ?? 'User';

    setState(() => _uploading = true);
    final repo = ref.read(messagesRepositoryProvider);
    try {
      final url = await repo.uploadChatImage(
        conversationId: widget.conversationId,
        senderId: userId,
        bytes: bytes,
        mimeType: mime,
      );
      if (url == null) throw Exception('Upload returned null');
      await repo.sendMediaMessage(
        conversationId: widget.conversationId,
        senderId: userId,
        senderDisplayName: displayName,
        mode: _item.mode.name,
        mediaUrl: url,
        mediaType: 'image',
        matchId: widget.matchId,
      );
    } catch (e) {
      if (mounted) ToastService.show(context, message: 'Image failed to send', type: ToastType.error);
    }
    if (mounted) setState(() => _uploading = false);
  }

  // ── Search ──

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    final repo = ref.read(messagesRepositoryProvider);
    try {
      final results = await repo.searchMessages(
        conversationId: widget.conversationId,
        query: query.trim(),
      );
      if (mounted) setState(() => _searchResults = results);
    } catch (e) {
      debugPrint('[chat] Search failed: $e');
    }
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

  Future<void> _checkMatchExpiry() async {
    if (widget.matchId == null || isMockMode) return;
    try {
      final result = await ref
          .read(matchRepositoryProvider)
          .fetchStatusAndExpiry(widget.matchId!);
      final status = result.status;
      final expiresAt = result.chatExpiresAt;
      final expired = status == 'expired' || status == 'closed' ||
          (expiresAt != null && DateTime.tryParse(expiresAt)?.isBefore(DateTime.now().toUtc()) == true);
      if (expired && mounted) setState(() => _isExpired = true);
    } catch (e) {
      debugPrint('[chat] expiry check failed: $e');
      // assume not expired — server will reject truly expired sends
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder || _noMoreOlder) return;
    setState(() => _loadingOlder = true);
    try {
      final repo = ref.read(messagesRepositoryProvider);
      // Find the earliest message timestamp from current view
      final streamMsgs = ref.read(messagesStreamProvider(widget.conversationId)).valueOrNull ?? [];
      final allCurrent = [..._olderMessages, ...streamMsgs];
      if (allCurrent.isEmpty) {
        setState(() { _loadingOlder = false; _noMoreOlder = true; });
        return;
      }
      allCurrent.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final oldest = allCurrent.first.createdAt.toIso8601String();
      final older = await repo.fetchOlderMessages(
        widget.conversationId,
        beforeTimestamp: oldest,
      );
      if (older.isEmpty) {
        setState(() { _loadingOlder = false; _noMoreOlder = true; });
        return;
      }
      setState(() {
        _olderMessages.insertAll(0, older);
        _loadingOlder = false;
      });
    } catch (e) {
      debugPrint('[chat] older messages load failed: $e');
      setState(() => _loadingOlder = false);
    }
  }

  Future<void> _blockOrHideUser(BuildContext context, WidgetRef ref, String column) async {
    final label = column == 'blocked_users' ? 'Block' : 'Hide';
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: context.surfaceColor,
      title: Text('$label ${_item.name}?', style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      content: Text(column == 'blocked_users'
          ? 'They won\'t be able to see your profile or contact you.'
          : 'They\'ll be removed from your feed. They can still see your profile.',
          style: TextStyle(color: context.textMuted, fontSize: 14, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: context.textMuted))),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(label, style: TextStyle(color: AppColors.error))),
      ],
    ));
    if (confirmed != true) return;
    final uid = ref.read(authProvider).userId;
    if (uid == null || isMockMode) return;
    try {
      final repo = ref.read(profileRepositoryProvider);
      if (column == 'blocked_users') {
        await repo.addToBlockList(uid, _item.id);
      } else {
        await repo.addToHideList(uid, _item.id);
      }
      if (context.mounted) {
        ToastService.show(context, message: '${_item.name} ${column == 'blocked_users' ? 'blocked' : 'hidden'}', type: ToastType.system);
      }
    } catch (e, st) {
      debugPrint('[action] block/hide failed: $e\n$st');
      if (context.mounted) {
        ToastService.show(context, message: '${column == 'blocked_users' ? 'Block' : 'Hide'} failed, try again', type: ToastType.error);
      }
    }
  }

  void _showReportSheet(BuildContext context, WidgetRef ref) {
    const reasons = [
      'Inappropriate messages',
      'Fake profile / catfish',
      'Harassment or threats',
      'Spam or scam',
      'Underage user',
      'Other',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(
                color: context.borderColor, borderRadius: BorderRadius.circular(999)))),
              const SizedBox(height: 20),
              Text('Report ${_item.name}', style: TextStyle(
                color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Your report is confidential.', style: TextStyle(
                color: context.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              ...reasons.map((reason) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(reason, style: TextStyle(color: context.textPrimary, fontSize: 14)),
                trailing: Icon(Icons.chevron_right_rounded, color: context.textDisabled, size: 20),
                onTap: () async {
                  Navigator.pop(context);
                  final uid = ref.read(authProvider).userId;
                  if (uid == null || isMockMode) return;
                  try {
                    await ref.read(userReportRepositoryProvider).submitReport(
                      reporterId: uid,
                      reportedUserId: _item.id,
                      reason: reason,
                      context: 'chat',
                      contextId: widget.matchId,
                    );
                    if (context.mounted) {
                      ToastService.show(context, message: 'Report submitted. We\'ll review it.', type: ToastType.system);
                    }
                  } catch (e, st) {
                    debugPrint('[action] report failed: $e\n$st');
                    if (context.mounted) {
                      ToastService.show(context, message: 'Report failed, try again', type: ToastType.error);
                    }
                  }
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    // Guard: check match status before sending
    if (widget.matchId != null && !isMockMode) {
      try {
        final result = await ref
            .read(matchRepositoryProvider)
            .fetchStatusAndExpiry(widget.matchId!);
        final status = result.status;
        if (status == 'expired' || status == 'closed') {
          if (mounted) ToastService.show(context, message: 'This conversation has ended', type: ToastType.error);
          return;
        }
        final expiresAt = result.chatExpiresAt;
        if (expiresAt != null && DateTime.tryParse(expiresAt)?.isBefore(DateTime.now().toUtc()) == true) {
          if (mounted) ToastService.show(context, message: 'Chat time has expired', type: ToastType.error);
          return;
        }
      } catch (e) {
        debugPrint('[chat] expiry pre-check failed: $e');
        // Proceed on error — server will reject if truly expired
      }
    }

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
            matchId: widget.matchId,
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
        messageId: m.id,
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
        mediaUrl: m.mediaUrl,
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
                    subtitle: 'Available soon',
                    color: context.textDisabled,
                    onTap: () {
                      Navigator.pop(context);
                      ToastService.show(context,
                          message: 'Voice intro will be available in the next update',
                          type: ToastType.system);
                    },
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
    final isClosed = _isExpired || (widget.matchId != null &&
        matchState.matches
            .any((m) => m.id == widget.matchId && (m.status == 'closed' || m.status == 'expired')));

    final isLoadingMessages = messagesAsync.isLoading;
    final rawMsgs = messagesAsync.valueOrNull ?? [];
    // Check for AI nudge after frame builds (avoid setState during build)
    if (rawMsgs.isNotEmpty && !_nudgeDismissed && _chatNudge == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkForNudge(rawMsgs);
      });
    }
    // Merge older + stream + pending messages
    final allMsgs = [
      ..._olderMessages,
      ...rawMsgs.where((r) => !_olderMessages.any((o) => o.id == r.id)),
      ..._pendingMessages.where(
        (p) => !rawMsgs.any((r) => r.content == p.content && r.senderId == p.senderId),
      ),
    ];
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
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => UserProfileScreen(
              userId: _item.id,
              initialName: _item.name,
              initialAvatarUrl: _item.photoUrl,
              isMatch: true, // chat = confirmed match/connection
            ),
          )),
          child: Row(
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
        ),
        actions: [
          IconButton(
            icon: Icon(_searchMode ? Icons.close_rounded : Icons.search_rounded,
                color: context.textMuted, size: 20),
            onPressed: () {
              setState(() {
                _searchMode = !_searchMode;
                if (!_searchMode) {
                  _searchCtrl.clear();
                  _searchResults = null;
                }
              });
            },
            tooltip: _searchMode ? 'Close search' : 'Search messages',
          ),
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
              onSelected: (v) async {
                if (v == 'report') {
                  _showReportSheet(context, ref);
                } else if (v == 'block') {
                  await _blockOrHideUser(context, ref, 'blocked_users');
                } else if (v == 'hide') {
                  await _blockOrHideUser(context, ref, 'hidden_users');
                } else if (v == 'end') {
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
                PopupMenuItem(value: 'report', child: Row(children: [
                  Icon(Icons.flag_outlined, color: context.textMuted, size: 18),
                  const SizedBox(width: 8),
                  Text('Report user', style: TextStyle(color: context.textPrimary, fontSize: 14)),
                ])),
                PopupMenuItem(value: 'block', child: Row(children: [
                  Icon(Icons.block_rounded, color: context.textMuted, size: 18),
                  const SizedBox(width: 8),
                  Text('Block user', style: TextStyle(color: context.textPrimary, fontSize: 14)),
                ])),
                PopupMenuItem(value: 'hide', child: Row(children: [
                  Icon(Icons.visibility_off_outlined, color: context.textMuted, size: 18),
                  const SizedBox(width: 8),
                  Text('Hide user', style: TextStyle(color: context.textPrimary, fontSize: 14)),
                ])),
                PopupMenuItem(value: 'end', child: Row(children: [
                  Icon(Icons.link_off_rounded, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Text('End this connection', style: TextStyle(color: AppColors.error, fontSize: 14)),
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
          // Search bar
          if (_searchMode)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              color: context.surfaceColor,
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(color: context.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: TextStyle(color: context.textMuted, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: context.textMuted, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  filled: true,
                  fillColor: context.surfaceAltColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _runSearch,
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
                        itemCount: (_searchMode && _searchResults != null
                            ? _searchResults!.length
                            : messages.length) + (_searchMode ? 0 : 1), // +1 for load-earlier header
                        itemBuilder: (context, i) {
                          if (_searchMode && _searchResults != null) {
                            final sm = _searchResults![i];
                            final smMsg = _Msg(
                              sender: sm.senderDisplayName,
                              avatarSeed: sm.senderId ?? '',
                              text: sm.content,
                              time: sm.createdAt,
                              isSelf: sm.senderId == currentUserId,
                              mediaUrl: sm.mediaUrl,
                            );
                            return _MsgBubble(
                              msg: smMsg,
                              accentColor: accent,
                              reactions: _reactions[sm.id] ?? [],
                              currentUserId: currentUserId,
                              onReaction: (emoji) => _toggleReaction(sm.id, emoji),
                            );
                          }
                          // Index 0 = "Load earlier messages" header
                          if (i == 0) {
                            if (_noMoreOlder) {
                              return const SizedBox(height: 8);
                            }
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _loadingOlder
                                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.5, color: accent))
                                    : TextButton(
                                        onPressed: _loadOlderMessages,
                                        child: Text('Load earlier messages', style: TextStyle(color: context.textMuted, fontSize: 12)),
                                      ),
                              ),
                            );
                          }
                          final msg = messages[i - 1]; // offset by 1 for header
                          return _MsgBubble(
                            msg: msg,
                            accentColor: accent,
                            reactions: _reactions[msg.messageId] ?? [],
                            currentUserId: currentUserId,
                            onReaction: msg.messageId.startsWith('pending-')
                                ? null
                                : (emoji) => _toggleReaction(msg.messageId, emoji),
                          );
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
          // Typing indicator
          if (_otherTyping)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg, bottom: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 12,
                    child: _TypingDots(color: accent),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_item.name} is typing',
                    style: TextStyle(color: context.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          // Upload indicator
          if (_uploading)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Sending image...', style: TextStyle(color: context.textMuted, fontSize: 12)),
                ],
              ),
            ),
          // Input bar
          _ChatInputBar(
            controller: _msgCtrl,
            accentColor: accent,
            hint: isClosed ? 'This conversation has closed' : 'Write something...',
            onSend: isClosed ? null : _send,
            onAttach: isClosed ? null : _pickAndSendImage,
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
  final List<MessageReaction> reactions;
  final String? currentUserId;
  final void Function(String emoji)? onReaction;

  const _MsgBubble({
    required this.msg,
    required this.accentColor,
    this.reactions = const [],
    this.currentUserId,
    this.onReaction,
  });

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
            child: GestureDetector(
              onLongPress: onReaction != null
                  ? () => _showReactionPicker(context)
                  : null,
              child: Column(
                crossAxisAlignment: msg.isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
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
                        // Media preview
                        if (msg.hasMedia) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            child: CachedNetworkImage(
                              imageUrl: msg.mediaUrl!,
                              width: 220,
                              fit: BoxFit.cover,
                              memCacheWidth: 440,
                              placeholder: (_, __) => Container(
                                width: 220, height: 140,
                                color: Colors.black26,
                                child: const Center(
                                  child: SizedBox(width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 220, height: 80,
                                color: Colors.black12,
                                child: const Center(
                                  child: Icon(Icons.broken_image_rounded,
                                      color: AppColors.textDisabled, size: 28),
                                ),
                              ),
                            ),
                          ),
                          if (msg.text.trim().isNotEmpty)
                            const SizedBox(height: 6),
                        ],
                        if (msg.text.trim().isNotEmpty)
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
                  // Reaction chips
                  if (reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Wrap(
                        spacing: 4,
                        children: _groupReactions().entries.map((e) {
                          final isMine = e.value.any((r) => r.userId == currentUserId);
                          return GestureDetector(
                            onTap: onReaction != null
                                ? () => onReaction!(e.key)
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? accentColor.withValues(alpha: 0.2)
                                    : context.surfaceColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isMine
                                      ? accentColor.withValues(alpha: 0.5)
                                      : context.borderSubtleColor,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                '${e.key} ${e.value.length > 1 ? e.value.length : ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<MessageReaction>> _groupReactions() {
    final map = <String, List<MessageReaction>>{};
    for (final r in reactions) {
      map.putIfAbsent(r.emoji, () => []).add(r);
    }
    return map;
  }

  void _showReactionPicker(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => GestureDetector(
        onTap: () => entry.remove(),
        behavior: HitTestBehavior.opaque,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(24),
                boxShadow: Premium.shadowMd,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: _reactionEmojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      entry.remove();
                      onReaction?.call(emoji);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
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
  final VoidCallback? onAttach;

  const _ChatInputBar({
    required this.controller,
    required this.accentColor,
    required this.hint,
    required this.onSend,
    this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
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
          // Attach button
          if (onAttach != null)
            PressEffect(
              onTap: onAttach,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: Icon(Icons.add_photo_alternate_outlined,
                    color: context.textMuted, size: 24),
              ),
            ),
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
  final String messageId;
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
  final String? mediaUrl;

  _Msg({
    this.messageId = '',
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
    this.mediaUrl,
  });

  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;
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

// ---------------------------------------------------------------------------
// Typing dots animation
// ---------------------------------------------------------------------------

class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay = i * 0.2;
          final t = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
          final opacity = (t < 0.5 ? t * 2 : 2 - t * 2).clamp(0.3, 1.0);
          return Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}
