import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/event_participant.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';
import 'edit_event_screen.dart';
import 'event_chat_screen.dart';
import 'event_checkin_screen.dart';

const _violet = AppColors.violet;

class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(eventDetailProvider(widget.eventId).notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventDetailProvider(widget.eventId));
    final event = state.event;
    final uid = ref.watch(authProvider).userId;

    if (state.isLoading || event == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(backgroundColor: AppColors.bg, surfaceTintColor: Colors.transparent),
        body: const Center(child: CircularProgressIndicator(color: _violet)),
      );
    }

    final isHost = uid == event.hostId;
    final isLocked = event.isLocked;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(event.title),
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (isHost && !isLocked)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: _violet),
              onPressed: () async {
                final edited = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => EditEventScreen(event: event)),
                );
                if (edited == true) {
                  ref.read(eventDetailProvider(widget.eventId).notifier).load();
                  ref.read(eventListProvider.notifier).load();
                }
              },
            ),
          if (!isLocked)
            IconButton(
              icon: const Icon(Icons.chat_rounded, color: _violet),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EventChatScreen(eventId: widget.eventId)),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          // ── Event info ──
          if (event.description != null) ...[
            Text(event.description!, style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
            const SizedBox(height: AppSpacing.xxl),
          ],

          // Date & location
          _InfoRow(icon: Icons.calendar_today_rounded, text: DateFormat('EEE, d MMM yyyy · HH:mm').format(event.eventDate)),
          if (event.locationText != null) _InfoRow(icon: Icons.location_on_outlined, text: event.locationText!),
          _InfoRow(icon: Icons.people_outline_rounded, text: '${event.attendeeCount}/${event.maxAttendees} attending'),
          if (event.companionEnabled) _InfoRow(icon: Icons.person_add_outlined, text: 'Companions allowed'),

          const SizedBox(height: AppSpacing.xxl),

          if (isLocked)
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'This event has ended. Chat is now read-only.',
                style: TextStyle(color: AppColors.warning, fontSize: 13),
              ),
            ),

          const SizedBox(height: AppSpacing.xxl),

          // ── Attendee list (grouped by status) ──
          Text('Attendees', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.md),
          // Host first, then Going, Maybe, rest
          ..._buildGroupedParticipants(state.participants),

          const SizedBox(height: AppSpacing.xxxl),

          // ── Actions ──
          if (!isLocked && !isHost) ...[
            // Join actions row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _violet, foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                    ),
                    onPressed: () => _joinWithCompanion(context),
                    child: const Text('Going'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      side: BorderSide(color: AppColors.textMuted.withValues(alpha: 0.3)),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () async {
                      await ref.read(eventDetailProvider(widget.eventId).notifier).updateMyAttendance('maybe');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as Maybe')));
                      }
                    },
                    child: const Text('Maybe'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Secondary actions
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      await ref.read(eventDetailProvider(widget.eventId).notifier).updateMyAttendance('on_my_way');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('On my way!')));
                      }
                    },
                    child: Text('\u231B On My Way', style: TextStyle(color: _violet, fontSize: 13)),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      await ref.read(eventListProvider.notifier).leaveEvent(widget.eventId);
                      ref.read(eventDetailProvider(widget.eventId).notifier).load();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Left event')));
                      }
                    },
                    child: Text('Leave', style: TextStyle(color: AppColors.error, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],

          if (isLocked) ...[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _violet),
                foregroundColor: _violet,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EventCheckinScreen(eventId: widget.eventId)),
              ),
              child: const Text('Post-event check-in'),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildGroupedParticipants(List<EventParticipant> all) {
    // Host first, then Going, Maybe, rest
    final host = all.where((p) => p.isHost).toList();
    final going = all.where((p) => !p.isHost && p.attendanceStatus == 'going').toList();
    final maybe = all.where((p) => p.attendanceStatus == 'maybe').toList();
    final onWay = all.where((p) => p.attendanceStatus == 'on_my_way').toList();
    final arrived = all.where((p) => p.attendanceStatus == 'arrived').toList();

    final widgets = <Widget>[];
    for (final group in [
      (host, 'Host'),
      (going, 'Going'),
      (maybe, 'Maybe'),
      (onWay, 'On My Way'),
      (arrived, 'Arrived'),
    ]) {
      if (group.$1.isEmpty) continue;
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
        child: Text(group.$2, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      ));
      for (final p in group.$1) {
        widgets.add(_participantRow(p));
      }
    }
    return widgets;
  }

  Widget _participantRow(EventParticipant p) {
    return GestureDetector(
      onTap: () => _showParticipantProfile(p),
      child: Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _violet.withValues(alpha: 0.2),
            child: Text((p.displayName ?? '?')[0].toUpperCase(), style: const TextStyle(color: _violet, fontSize: 14)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Row(
              children: [
                Text(p.displayName ?? 'User', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                if (p.isHost) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: _violet.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                    child: const Text('Host', style: TextStyle(color: _violet, fontSize: 9, fontWeight: FontWeight.w600)),
                  ),
                ],
                if (p.companionCount > 0) ...[
                  const SizedBox(width: 6),
                  Text('+${p.companionCount}', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ],
            ),
          ),
          Text(p.statusIcon, style: const TextStyle(fontSize: 16)),
        ],
      ),
    ),
    );
  }

  void _showParticipantProfile(EventParticipant p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        expand: false,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(AppSpacing.xxl),
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: _violet.withValues(alpha: 0.2),
                  backgroundImage: p.photoUrl != null ? NetworkImage(p.photoUrl!) : null,
                  child: p.photoUrl == null
                      ? Text((p.displayName ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: _violet, fontSize: 24, fontWeight: FontWeight.w600))
                      : null,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.displayName ?? 'User',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                      if (p.isHost)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: _violet.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                          child: const Text('Host', style: TextStyle(color: _violet, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text('Status: ${p.attendanceStatus.replaceAll('_', ' ')}',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            if (p.companionCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text('Coming with +${p.companionCount}', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  void _joinWithCompanion(BuildContext context) {
    final event = ref.read(eventDetailProvider(widget.eventId)).event;
    if (event == null) return;

    if (!event.companionEnabled) {
      _doJoin(0);
      return;
    }

    final maxCompanion = event.plus3Enabled ? 3 : 2;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How many are coming?', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            if (event.plus3Enabled)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: _violet.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _violet.withValues(alpha: 0.3)),
                  ),
                  child: const Text('+3 mode enabled', style: TextStyle(color: _violet, fontSize: 11)),
                ),
              ),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int n = 0; n <= maxCompanion; n++)
                  GestureDetector(
                    onTap: () { Navigator.pop(ctx); _doJoin(n); },
                    child: Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: _violet.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: _violet.withValues(alpha: 0.3)),
                      ),
                      child: Center(child: Text(n == 0 ? 'Just me' : '+$n',
                          style: TextStyle(color: _violet, fontWeight: FontWeight.w600))),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  void _doJoin(int companionCount) async {
    final result = await ref.read(eventListProvider.notifier).joinEvent(widget.eventId, companionCount: companionCount);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result == 'joined' ? 'You\'re going!${companionCount > 0 ? ' (+$companionCount)' : ''}' : result)),
    );
    ref.read(eventDetailProvider(widget.eventId).notifier).load();
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: _violet, size: 18),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: TextStyle(color: AppColors.textSecondary, fontSize: 14))),
        ],
      ),
    );
  }
}
