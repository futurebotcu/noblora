import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/scheduling.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/premium.dart';
import '../../data/models/real_meeting.dart';
import '../../providers/auth_provider.dart';
import '../../providers/real_meeting_provider.dart';

class RealMeetingScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String otherUserName;

  const RealMeetingScreen({
    super.key,
    required this.matchId,
    required this.otherUserName,
  });

  @override
  ConsumerState<RealMeetingScreen> createState() => _RealMeetingScreenState();
}

class _RealMeetingScreenState extends ConsumerState<RealMeetingScreen> {
  final _locationCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 0);
  bool _submitting = false;

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  DateTime get _scheduled => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

  String get _formattedScheduled =>
      DateFormat('EEEE, d MMMM • HH:mm').format(_scheduled);

  Future<void> _propose() async {
    final location = _locationCtrl.text.trim();
    if (location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a meeting location.')),
      );
      return;
    }
    setState(() => _submitting = true);
    final userId = ref.read(authProvider).userId ?? '';
    final ok = await ref
        .read(realMeetingProvider(widget.matchId).notifier)
        .propose(
          matchId: widget.matchId,
          proposedBy: userId,
          scheduledAt: _scheduled,
          locationText: location,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Meeting proposed! Waiting for confirmation.'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  Future<void> _confirm(RealMeeting meeting) async {
    setState(() => _submitting = true);
    final userId = ref.read(authProvider).userId ?? '';
    await ref
        .read(realMeetingProvider(widget.matchId).notifier)
        .confirm(meeting.id, userId);
    if (!mounted) return;
    setState(() => _submitting = false);
  }

  Future<void> _decline(RealMeeting meeting) async {
    setState(() => _submitting = true);
    final userId = ref.read(authProvider).userId ?? '';
    await ref
        .read(realMeetingProvider(widget.matchId).notifier)
        .decline(meeting.id, userId);
    if (!mounted) return;
    setState(() => _submitting = false);
  }

  Future<void> _cancel(RealMeeting meeting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cancel Meeting?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('This will cancel the planned meetup.',
            style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Keep', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Meeting',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _submitting = true);
    await ref
        .read(realMeetingProvider(widget.matchId).notifier)
        .cancel(meeting.id);
    if (!mounted) return;
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(realMeetingProvider(widget.matchId));
    final userId = ref.watch(authProvider).userId ?? '';
    final meeting = state.meeting;

    // Confirmed view
    if (meeting != null && meeting.isConfirmed) {
      return _ConfirmedView(
        meeting: meeting,
        otherUserName: widget.otherUserName,
        onCancel: () => _cancel(meeting),
        submitting: _submitting,
      );
    }

    final iAmProposer = meeting?.proposedBy == userId;
    final awaitingMyResponse =
        meeting != null && meeting.isProposed && !iAmProposer;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Meet ${widget.otherUserName}'),
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              _InfoBanner(otherUserName: widget.otherUserName),
              const SizedBox(height: AppSpacing.xxl),

              // Pending proposal — other user proposed, I need to respond
              if (awaitingMyResponse) ...[
                Text('Meeting Proposed',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${widget.otherUserName} wants to meet you.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                _MeetingCard(meeting: meeting),
                const SizedBox(height: AppSpacing.xl),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _submitting ? null : () => _decline(meeting),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        foregroundColor: AppColors.error,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _submitting ? null : () => _confirm(meeting),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald600,
                        foregroundColor: AppColors.bg,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.bg))
                          : const Text('Confirm'),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.xxl),
                const Divider(color: AppColors.border),
                const SizedBox(height: AppSpacing.lg),
                Text('Or propose a different time & place:',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: AppSpacing.lg),
              ],

              // My proposal sent — waiting
              if (meeting != null && iAmProposer && meeting.isProposed) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    const Icon(Icons.hourglass_top_rounded,
                        color: AppColors.textMuted, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Waiting for ${widget.otherUserName} to confirm…',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textMuted)),
                  ]),
                ),
                const SizedBox(height: AppSpacing.md),
                _MeetingCard(meeting: meeting),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: _submitting ? null : () => _cancel(meeting),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.textMuted,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Cancel Proposal'),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],

              // Propose / re-propose form
              if (meeting == null || (!iAmProposer && !awaitingMyResponse)) ...[
                Text('Where?',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _locationCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. Karaköy, café near the pier',
                    hintStyle:
                        const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                      borderSide:
                          const BorderSide(color: AppColors.emerald600),
                    ),
                    prefixIcon: const Icon(Icons.location_on_rounded,
                        color: AppColors.emerald600),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text('When?',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _DateSelector(
                  selected: _selectedDate,
                  onSelected: (d) => setState(() => _selectedDate = d),
                ),
                const SizedBox(height: AppSpacing.xl),
                _TimeSelector(
                  selected: _selectedTime,
                  onSelected: (t) => setState(() => _selectedTime = t),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Row(children: [
                    const Icon(Icons.event_rounded,
                        color: AppColors.emerald600, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Text(_formattedScheduled,
                        style: const TextStyle(
                            color: AppColors.emerald600,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(height: AppSpacing.xxl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald600,
                      foregroundColor: AppColors.bg,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _submitting ? null : _propose,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.bg))
                        : const Text(
                            'Propose Meetup',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                  ),
                ),
              ],

              // Error
              if (state.error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(state.error!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ConfirmedView extends StatelessWidget {
  final RealMeeting meeting;
  final String otherUserName;
  final VoidCallback onCancel;
  final bool submitting;

  const _ConfirmedView({
    required this.meeting,
    required this.otherUserName,
    required this.onCancel,
    required this.submitting,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Meeting Confirmed'),
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.emerald600.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.handshake_rounded,
                  color: AppColors.emerald600, size: 40),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text('It\'s a Date!',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: AppColors.emerald600)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You and $otherUserName are meeting up.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            _MeetingCard(meeting: meeting),
            const SizedBox(height: AppSpacing.lg),
            // Safety card — share meeting details with trusted contact
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share safety card'),
                onPressed: () {
                  final fmt = DateFormat('EEEE, d MMM yyyy · HH:mm');
                  final text =
                      'Noblara Safety Card\n'
                      'Meeting: $otherUserName\n'
                      'When: ${fmt.format(meeting.scheduledAt.toLocal())}\n'
                      'Where: ${meeting.locationText ?? "Not specified"}';
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Safety card copied — share with a trusted contact'),
                      backgroundColor: AppColors.emerald600,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.emerald600.withValues(alpha: 0.4)),
                  foregroundColor: AppColors.emerald600,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: submitting ? null : onCancel,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  foregroundColor: AppColors.textMuted,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Cancel Meeting'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String otherUserName;
  const _InfoBanner({required this.otherUserName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.emerald600.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.emerald600.withValues(alpha: 0.15), width: 0.5),
        boxShadow: Premium.shadowSm,
      ),
      child: Row(
        children: [
          const Icon(Icons.place_rounded, color: AppColors.emerald600),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Plan a Real Meetup',
                    style: TextStyle(
                        color: AppColors.emerald600,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Suggest a place and time to meet $otherUserName in person.',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final RealMeeting meeting;
  const _MeetingCard({required this.meeting});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEEE, d MMMM yyyy · HH:mm');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.emerald600.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.emerald600.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.schedule_rounded, color: AppColors.emerald600, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text(fmt.format(meeting.scheduledAt.toLocal()),
                style: const TextStyle(
                    color: AppColors.emerald600, fontWeight: FontWeight.w600)),
          ]),
          if (meeting.locationText != null &&
              meeting.locationText!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              const Icon(Icons.location_on_rounded,
                  color: AppColors.emerald600, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(meeting.locationText!,
                    style: const TextStyle(
                        color: AppColors.emerald600,
                        fontWeight: FontWeight.w500)),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  const _DateSelector({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final date = DateTime.now().add(Duration(days: i + 1));
          final isSel =
              date.day == selected.day && date.month == selected.month;
          return GestureDetector(
            onTap: () => onSelected(date),
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                color: isSel ? AppColors.emerald600 : AppColors.surface,
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(
                    color: isSel ? AppColors.emerald600 : AppColors.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('EEE').format(date),
                      style: TextStyle(
                          color:
                              isSel ? AppColors.bg : AppColors.textMuted,
                          fontSize: 11)),
                  Text('${date.day}',
                      style: TextStyle(
                          color: isSel
                              ? AppColors.bg
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TimeSelector extends StatefulWidget {
  final TimeOfDay selected;
  final ValueChanged<TimeOfDay> onSelected;
  const _TimeSelector({required this.selected, required this.onSelected});

  @override
  State<_TimeSelector> createState() => _TimeSelectorState();
}

class _TimeSelectorState extends State<_TimeSelector> {
  static const _startHour = SchedulingConfig.startHour;
  static const _endHour = SchedulingConfig.endHour;
  static const _minutes = SchedulingConfig.minutes;

  late int _selectedHour;
  late int _selectedMinute;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.selected.hour.clamp(_startHour, _endHour);
    _selectedMinute = SchedulingConfig.snapMinute(widget.selected.minute);
  }

  void _pickHour(int h) {
    setState(() => _selectedHour = h);
    widget.onSelected(TimeOfDay(hour: h, minute: _selectedMinute));
  }

  void _pickMinute(int m) {
    setState(() => _selectedMinute = m);
    widget.onSelected(TimeOfDay(hour: _selectedHour, minute: m));
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final hours =
        List.generate(_endHour - _startHour + 1, (i) => _startHour + i);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: hours.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppSpacing.xs),
            itemBuilder: (_, i) {
              final h = hours[i];
              final isSel = h == _selectedHour;
              return GestureDetector(
                onTap: () => _pickHour(h),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isSel ? AppColors.emerald600 : AppColors.surface,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                        color:
                            isSel ? AppColors.emerald600 : AppColors.border),
                  ),
                  child: Text(
                    '${_pad(h)}:__',
                    style: TextStyle(
                      color: isSel ? AppColors.bg : AppColors.textPrimary,
                      fontWeight: isSel
                          ? FontWeight.w700
                          : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (int row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: AppSpacing.xs),
          Row(
            children: _minutes.sublist(row * 6, row * 6 + 6).map((m) {
              final isSel = m == _selectedMinute;
              return Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.only(right: AppSpacing.xs),
                  child: GestureDetector(
                    onTap: () => _pickMinute(m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.emerald600.withValues(alpha: 0.15)
                            : AppColors.surfaceAlt,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(
                            color: isSel
                                ? AppColors.emerald600
                                : AppColors.border),
                      ),
                      child: Text(
                        ':${_pad(m)}',
                        style: TextStyle(
                          color: isSel
                              ? AppColors.emerald600
                              : AppColors.textMuted,
                          fontWeight: isSel
                              ? FontWeight.w700
                              : FontWeight.w400,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            const Icon(Icons.access_time_rounded,
                color: AppColors.textDisabled, size: 14),
            const SizedBox(width: 4),
            Text(
              'Selected: ${_pad(_selectedHour)}:${_pad(_selectedMinute)}',
              style: const TextStyle(
                  color: AppColors.textDisabled, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}
