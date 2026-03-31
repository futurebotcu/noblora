import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/enums/noble_mode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/table_card.dart';

// ---------------------------------------------------------------------------
// Group Chat Screen (stub — mock messages only)
// ---------------------------------------------------------------------------

class GroupChatScreen extends StatefulWidget {
  final TableCard table;
  final String currentUserId;
  final String currentUserName;

  const GroupChatScreen({
    super.key,
    required this.table,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMsg> _messages = [];
  Timer? _joinTimer;
  Timer? _typingTimer;
  final bool _showTyping = false;

  static final _mode = NobleMode.social;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _joinTimer?.cancel();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMsg(
        sender: widget.currentUserName,
        avatarSeed: widget.currentUserId,
        text: text,
        time: DateTime.now(),
        isSelf: true,
      ));
      _msgCtrl.clear();
    });
    _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090610), // Social bgTint
      appBar: AppBar(
        backgroundColor: const Color(0xFF090610),
        leading: const BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.table.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text(
              '${widget.table.currentCount}/${widget.table.maxParticipants} members · ${widget.table.eventTag}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppSpacing.lg),
            child: _ParticipantAvatarStack(
              participants: widget.table.participants,
              accentColor: _mode.accentColor,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Discussion topics banner
          if (widget.table.discussionTopics.isNotEmpty)
            _TopicsBanner(
              topics: widget.table.discussionTopics,
              accentColor: _mode.accentColor,
            ),
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: _messages.length + (_showTyping ? 1 : 0),
              itemBuilder: (context, i) {
                if (_showTyping && i == _messages.length) {
                  return const _TypingIndicator();
                }
                return _MessageBubble(
                  msg: _messages[i],
                  accentColor: _mode.accentColor,
                );
              },
            ),
          ),
          // Input bar
          _InputBar(
            controller: _msgCtrl,
            accentColor: _mode.accentColor,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting widgets
// ---------------------------------------------------------------------------

class _ParticipantAvatarStack extends StatelessWidget {
  final List<TableParticipant> participants;
  final Color accentColor;

  const _ParticipantAvatarStack({
    required this.participants,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    const size = 28.0;
    const overlap = 10.0;
    final visible = participants.take(3).toList();
    final totalWidth = size + (visible.length - 1) * (size - overlap);

    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(
        children: visible.asMap().entries.map((entry) {
          return Positioned(
            left: entry.key * (size - overlap),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              child: ClipOval(
                child: Image.network(
                  'https://picsum.photos/seed/${entry.value.avatarSeed}/60/60',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => CircleAvatar(
                    backgroundColor: accentColor.withValues(alpha: 0.3),
                    child: Text(
                      entry.value.name[0],
                      style: TextStyle(
                          color: accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TopicsBanner extends StatelessWidget {
  final List<String> topics;
  final Color accentColor;

  const _TopicsBanner({required this.topics, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      color: AppColors.surfaceAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tonight\'s agenda',
            style: TextStyle(
              color: accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: topics.map((t) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusCircle),
                  border: Border.all(
                      color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  t,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMsg msg;
  final Color accentColor;

  const _MessageBubble({required this.msg, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    if (msg.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Center(
          child: Text(
            msg.text,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
              child: Image.network(
                'https://picsum.photos/seed/${msg.avatarSeed}/40/40',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => CircleAvatar(
                  radius: 16,
                  backgroundColor: accentColor.withValues(alpha: 0.3),
                  child: Text(
                    msg.sender.isNotEmpty ? msg.sender[0] : '?',
                    style: TextStyle(
                        color: accentColor, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: msg.isSelf
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!msg.isSelf)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      msg.sender,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: msg.isSelf
                        ? accentColor
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppSpacing.radiusMd),
                      topRight: const Radius.circular(AppSpacing.radiusMd),
                      bottomLeft: Radius.circular(
                          msg.isSelf ? AppSpacing.radiusMd : 4),
                      bottomRight: Radius.circular(
                          msg.isSelf ? 4 : AppSpacing.radiusMd),
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      color: msg.isSelf ? AppColors.bg : AppColors.textPrimary,
                      fontSize: 14,
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
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                SizedBox(width: 4),
                _Dot(delay: 150),
                SizedBox(width: 4),
                _Dot(delay: 300),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.repeat(reverse: true);
    });
    _a = Tween<double>(begin: 0.3, end: 1.0).animate(_c);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Opacity(
        opacity: _a.value,
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final Color accentColor;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.accentColor,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Say something...',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusCircle),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: AppColors.bg,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class _ChatMsg {
  final String sender;
  final String avatarSeed;
  final String text;
  final DateTime time;
  final bool isSelf;
  final bool isSystem;

  _ChatMsg({
    required this.sender,
    required this.avatarSeed,
    required this.text,
    required this.time,
    this.isSelf = false,
    // ignore: unused_element_parameter
    this.isSystem = false,
  });
}
