import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/premium.dart';
import '../../core/services/toast_service.dart';
import '../../core/utils/mock_mode.dart';
import '../../data/models/match.dart';
import '../../providers/auth_provider.dart';
import '../../providers/match_provider.dart';
import '../../providers/video_provider.dart';
import '../../data/models/inbox_item.dart';
import '../../core/enums/noble_mode.dart';
import '../matches/individual_chat_screen.dart';
import 'mini_intro_screen.dart';
import 'video_scheduling_screen.dart';
import 'video_call_screen.dart';

class MatchDetailScreen extends ConsumerWidget {
  final NobleMatch match;
  const MatchDetailScreen({super.key, required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch matchProvider for live updates instead of using stale passed object
    final liveMatch = ref.watch(matchProvider).matches
        .where((m) => m.id == match.id).firstOrNull ?? match;
    final videoState = ref.watch(videoProvider(liveMatch.id));
    final userId = ref.watch(authProvider).userId ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(liveMatch.otherUserName ?? 'Match'),
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
            color: AppColors.surface,
            onSelected: (v) {
              if (v == 'report') {
                _showReportSheet(context, ref, liveMatch);
              } else if (v == 'block' || v == 'hide') {
                _blockOrHideUser(context, ref, liveMatch, v == 'block' ? 'blocked_users' : 'hidden_users');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'report', child: Row(children: [
                Icon(Icons.flag_outlined, color: AppColors.textMuted, size: 18),
                const SizedBox(width: 8),
                Text('Report user', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
              ])),
              PopupMenuItem(value: 'block', child: Row(children: [
                Icon(Icons.block_rounded, color: AppColors.textMuted, size: 18),
                const SizedBox(width: 8),
                Text('Block user', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
              ])),
              PopupMenuItem(value: 'hide', child: Row(children: [
                Icon(Icons.visibility_off_outlined, color: AppColors.textMuted, size: 18),
                const SizedBox(width: 8),
                Text('Hide user', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
              ])),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            _StatusCard(match: liveMatch),
            const SizedBox(height: AppSpacing.xxl),

            // Deadline counter
            if (liveMatch.isPendingVideo && liveMatch.videoDeadlineAt != null)
              _DeadlineCard(deadline: liveMatch.videoDeadlineAt!),

            // Pending intro hint
            if (liveMatch.isPendingIntro && liveMatch.videoDeadlineAt != null)
              _DeadlineCard(deadline: liveMatch.videoDeadlineAt!),

            // Video session info
            if (videoState.session != null && !liveMatch.isChatting)
              _SessionCard(session: videoState.session!),

            const Spacer(),

            // Action button
            _ActionButton(
              match: liveMatch,
              videoState: videoState,
              userId: userId,
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _blockOrHideUser(BuildContext context, WidgetRef ref, NobleMatch match, String column) async {
    final label = column == 'blocked_users' ? 'Block' : 'Hide';
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('$label ${match.otherUserName ?? 'this user'}?', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      content: Text(column == 'blocked_users'
          ? 'They won\'t be able to see your profile or contact you.'
          : 'They\'ll be removed from your feed. They can still see your profile.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(label, style: TextStyle(color: AppColors.error))),
      ],
    ));
    if (confirmed != true) return;
    final uid = ref.read(authProvider).userId;
    final targetId = match.otherUserId;
    if (uid == null || targetId == null || isMockMode) return;
    try {
      final row = await Supabase.instance.client.from('profiles').select(column).eq('id', uid).single();
      final list = List<String>.from((row[column] as List<dynamic>?) ?? []);
      if (!list.contains(targetId)) list.add(targetId);
      await Supabase.instance.client.from('profiles').update({column: list}).eq('id', uid);
      if (context.mounted) {
        ToastService.show(context, message: '${match.otherUserName ?? 'User'} ${column == 'blocked_users' ? 'blocked' : 'hidden'}', type: ToastType.system);
      }
    } catch (_) {}
  }

  static void _showReportSheet(BuildContext context, WidgetRef ref, NobleMatch match) {
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
      backgroundColor: AppColors.surface,
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
                color: AppColors.border, borderRadius: BorderRadius.circular(999)))),
              const SizedBox(height: 20),
              Text('Report ${match.otherUserName ?? 'this user'}', style: TextStyle(
                color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Your report is confidential.', style: TextStyle(
                color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              ...reasons.map((reason) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(reason, style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textDisabled, size: 20),
                onTap: () async {
                  Navigator.pop(context);
                  final uid = ref.read(authProvider).userId;
                  if (uid == null || isMockMode) return;
                  try {
                    await Supabase.instance.client.from('user_reports').insert({
                      'reporter_id': uid,
                      'reported_user_id': match.otherUserId,
                      'reason': reason,
                      'context': 'match_detail',
                      'context_id': match.id,
                    });
                  } catch (_) {}
                  if (context.mounted) {
                    ToastService.show(context, message: 'Report submitted. We\'ll review it.', type: ToastType.system);
                  }
                },
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _StatusCard extends StatelessWidget {
  final NobleMatch match;
  const _StatusCard({required this.match});

  String get _label {
    switch (match.status) {
      case 'pending_intro':
        return 'Send a Mini Intro';
      case 'pending_video':
        return 'Schedule a Short Intro Call';
      case 'video_scheduled':
        return 'Short Intro Scheduled';
      case 'video_completed':
        return 'Awaiting Decision';
      case 'chatting':
        return 'Chat is Open';
      case 'meeting_scheduled':
        return 'Meeting Scheduled';
      case 'expired':
        return 'Connection Expired';
      case 'closed':
        return 'Connection Closed';
      default:
        return match.status;
    }
  }

  Color get _color {
    switch (match.status) {
      case 'chatting':
        return AppColors.emerald600;
      case 'expired':
        return AppColors.error;
      case 'pending_video':
        return AppColors.emerald500;
      default:
        return AppColors.emerald600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: _color.withValues(alpha: 0.20), width: 0.5),
        boxShadow: Premium.shadowSm,
      ),
      child: Row(
        children: [
          Icon(Icons.circle, color: _color, size: 10),
          const SizedBox(width: AppSpacing.sm),
          Text(_label,
              style: TextStyle(
                  color: _color, fontWeight: FontWeight.w600, fontSize: 15)),
        ],
      ),
    );
  }
}

class _DeadlineCard extends StatelessWidget {
  final DateTime deadline;
  const _DeadlineCard({required this.deadline});

  @override
  Widget build(BuildContext context) {
    final remaining = deadline.difference(DateTime.now());
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_rounded, color: AppColors.warning, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Schedule within ${h}h ${m}m',
            style: const TextStyle(
                color: AppColors.warning, fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}


class _SessionCard extends StatelessWidget {
  final dynamic session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM · HH:mm');
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.emerald600.withValues(alpha: 0.10), width: 0.5),
        boxShadow: Premium.shadowSm,
      ),
      child: Row(
        children: [
          const Icon(Icons.videocam_rounded, color: AppColors.emerald600, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Video: ${fmt.format(session.scheduledAt.toLocal())} · ${session.status}',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends ConsumerWidget {
  final NobleMatch match;
  final dynamic videoState;
  final String userId;

  const _ActionButton({
    required this.match,
    required this.videoState,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mini Intro (new connection, before video)
    if (match.isPendingIntro) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          label: const Text('Send Mini Intro'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.emerald600,
            foregroundColor: AppColors.bg,
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MiniIntroScreen(match: match),
            ),
          ),
        ),
      );
    }

    if (match.isPendingVideo || match.isVideoScheduled) {
      final session = videoState.session;
      if (session != null && session.isAccepted) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.videocam_rounded),
            label: const Text('Join Video Call'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald600,
              foregroundColor: AppColors.bg,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VideoCallScreen(
                    match: match, session: session),
              ),
            ),
          ),
        );
      }
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.schedule_rounded),
          label: const Text('Schedule Video Call'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.emerald600,
            foregroundColor: AppColors.bg,
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoSchedulingScreen(match: match),
            ),
          ),
        ),
      );
    }

    if (match.isChatting && match.conversationId != null) {
      final mode = NobleMode.values.firstWhere(
        (m) => m.name == match.mode,
        orElse: () => NobleMode.date,
      );
      final item = InboxItem(
        id: match.id,
        name: match.otherUserName ?? 'Match',
        avatarSeed: match.otherUserId ?? match.id,
        lastMessage: 'Chat is open',
        ago: DateTime.now().difference(match.matchedAt),
        mode: mode,
        type: ConversationType.alliance,
      );
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.chat_bubble_rounded),
          label: const Text('Open Chat'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.emerald600,
            foregroundColor: AppColors.bg,
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => IndividualChatScreen(
                item: item,
                conversationId: match.conversationId!,
                matchId: match.id,
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
