import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';
import 'event_chat_screen.dart';
import 'event_checkin_screen.dart';

const _violet = Color(0xFFAB47BC);

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

          // ── Attendee list ──
          Text('Attendees', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.md),
          ...state.participants.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _violet.withValues(alpha: 0.2),
                      child: Text(
                        (p.displayName ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: _violet, fontSize: 14),
                      ),
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
              )),

          const SizedBox(height: AppSpacing.xxxl),

          // ── Actions ──
          if (!isLocked && !isHost)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _violet,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                ),
                onPressed: () async {
                  final result = await ref.read(eventListProvider.notifier).joinEvent(widget.eventId);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result == 'joined' ? 'You\'re going!' : result)),
                  );
                  ref.read(eventDetailProvider(widget.eventId).notifier).load();
                },
                child: const Text('Going'),
              ),
            ),

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
