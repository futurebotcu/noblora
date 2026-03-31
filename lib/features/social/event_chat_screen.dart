import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/mock_mode.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';

const _violet = Color(0xFFAB47BC);
const _gold = AppColors.gold;

class EventChatScreen extends ConsumerStatefulWidget {
  final String eventId;
  const EventChatScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventChatScreen> createState() => _EventChatScreenState();
}

class _EventChatScreenState extends ConsumerState<EventChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  StreamSubscription<dynamic>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(eventDetailProvider(widget.eventId).notifier).load();
      _subscribeRealtime();
    });
  }

  void _subscribeRealtime() {
    if (isMockMode) return;
    final channel = Supabase.instance.client.channel('event-chat-${widget.eventId}');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'event_messages',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'event_id', value: widget.eventId),
      callback: (payload) {
        ref.read(eventDetailProvider(widget.eventId).notifier).load();
        _scrollToBottom();
      },
    ).subscribe();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
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
  void dispose() {
    _realtimeSub?.cancel();
    if (!isMockMode) {
      Supabase.instance.client.removeChannel(
        Supabase.instance.client.channel('event-chat-${widget.eventId}'),
      );
    }
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    ref.read(eventDetailProvider(widget.eventId).notifier).sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventDetailProvider(widget.eventId));
    final uid = ref.watch(authProvider).userId;
    final isLocked = state.event?.isLocked ?? false;

    final pinned = state.messages.where((m) => m.goldFlagged).toList();
    final flagged = state.messages.where((m) => m.blueFlagged && !m.goldFlagged).toList();
    final regular = state.messages.where((m) => !m.goldFlagged).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(state.event?.title ?? 'Event Chat'),
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (flagged.isNotEmpty)
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.flag_rounded, color: Colors.blue),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                      child: Text('${flagged.length}', style: const TextStyle(fontSize: 8, color: Colors.white)),
                    ),
                  ),
                ],
              ),
              onPressed: () => _showFlagged(flagged),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Pinned messages (gold) ──
          if (pinned.isNotEmpty)
            Container(
              color: _gold.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: pinned.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.push_pin_rounded, color: _gold, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(m.content,
                                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    )).toList(),
              ),
            ),

          if (isLocked)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              color: AppColors.warning.withValues(alpha: 0.1),
              child: const Row(
                children: [
                  Icon(Icons.lock_rounded, color: AppColors.warning, size: 16),
                  SizedBox(width: 8),
                  Text('Chat is read-only', style: TextStyle(color: AppColors.warning, fontSize: 13)),
                ],
              ),
            ),

          // ── Messages ──
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator(color: _violet))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: regular.length,
                    itemBuilder: (context, i) {
                      final msg = regular[i];
                      final isMine = msg.senderId == uid;
                      return GestureDetector(
                        onLongPress: () => _showMessageActions(msg.id, uid == state.event?.hostId),
                        child: Align(
                          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: isMine ? _violet.withValues(alpha: 0.2) : AppColors.surface,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              border: msg.blueFlagged ? Border.all(color: Colors.blue.withValues(alpha: 0.5)) : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMine)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        msg.senderName ?? 'User',
                                        style: TextStyle(color: _violet, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                      if (msg.isHost) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(color: _violet.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3)),
                                          child: const Text('Host', style: TextStyle(color: _violet, fontSize: 8, fontWeight: FontWeight.w600)),
                                        ),
                                      ],
                                      if (msg.blueFlagged) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.flag_rounded, color: Colors.blue, size: 12),
                                      ],
                                    ],
                                  ),
                                Text(msg.content, style: TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.3)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // ── Input ──
          if (!isLocked)
            Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Message...',
                        hintStyle: TextStyle(color: AppColors.textDisabled),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: _violet),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showMessageActions(String messageId, bool isHost) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isHost)
              ListTile(
                leading: Icon(Icons.push_pin_rounded, color: _gold),
                title: const Text('Pin message', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(eventDetailProvider(widget.eventId).notifier).flagGold(messageId);
                },
              ),
            ListTile(
              leading: const Icon(Icons.flag_rounded, color: Colors.blue),
              title: const Text('Flag as important', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(eventDetailProvider(widget.eventId).notifier).flagBlue(messageId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFlagged(List<dynamic> flagged) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Flagged Messages', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.md),
            ...flagged.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_rounded, color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(m.content as String, style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
