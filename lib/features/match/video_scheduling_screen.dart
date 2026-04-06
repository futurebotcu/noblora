import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/premium.dart';
import '../../data/models/match.dart';
import '../../data/models/video_session.dart';
import '../../providers/auth_provider.dart';
import '../../providers/video_provider.dart';
import '../../core/constants/scheduling.dart';
import 'short_intro_rules_screen.dart';

// ---------------------------------------------------------------------------
// Preset decline reasons
// ---------------------------------------------------------------------------

const _declineReasons = [
  "I'm busy at that time",
  "I'd prefer a different day",
  "I need more time to prepare",
  "The time is too early / too late for me",
  "Something came up unexpectedly",
];

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

class VideoSchedulingScreen extends ConsumerStatefulWidget {
  final NobleMatch match;
  const VideoSchedulingScreen({super.key, required this.match});

  @override
  ConsumerState<VideoSchedulingScreen> createState() =>
      _VideoSchedulingScreenState();
}

class _VideoSchedulingScreenState extends ConsumerState<VideoSchedulingScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 2));
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _submitting = false;

  DateTime get _scheduled => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

  String get _formattedScheduled =>
      DateFormat('EEEE, d MMMM • HH:mm').format(_scheduled);

  bool _isProposer(String userId, VideoSession? session) =>
      session?.proposedBy == userId;

  Future<void> _propose() async {
    setState(() => _submitting = true);
    final userId = ref.read(authProvider).userId ?? '';
    final session = await ref
        .read(videoProvider(widget.match.id).notifier)
        .proposeTime(
          matchId: widget.match.id,
          proposedBy: userId,
          recipientId: widget.match.otherUserId ?? '',
          scheduledAt: _scheduled,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (session != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Video call proposed. Waiting for confirmation.'),
        backgroundColor: AppColors.success,
      ));
      Navigator.pop(context);
    }
  }

  Future<void> _accept(VideoSession session) async {
    setState(() => _submitting = true);
    final userId = ref.read(authProvider).userId ?? '';
    await ref.read(videoProvider(widget.match.id).notifier).respond(
          sessionId: session.id,
          responderId: userId,
          accepted: true,
          proposerUserId: session.proposedBy,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.pop(context);
  }

  Future<void> _openDeclineCounter(VideoSession session) async {
    final userId = ref.read(authProvider).userId ?? '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeclineCounterSheet(
        session: session,
        responderId: userId,
        matchId: widget.match.id,
        onDone: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _sendCounter(VideoSession session) async {
    setState(() => _submitting = true);
    final userId = ref.read(authProvider).userId ?? '';
    await ref.read(videoProvider(widget.match.id).notifier).respond(
          sessionId: session.id,
          responderId: userId,
          accepted: false,
          counterTime: _scheduled,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Counter-proposal sent.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final videoState = ref.watch(videoProvider(widget.match.id));
    final session = videoState.session;
    final userId = ref.watch(authProvider).userId ?? '';
    final iAmProposer = _isProposer(userId, session);

    // Accepted → show join button
    if (session != null && session.isAccepted) {
      return _AcceptedView(match: widget.match, session: session);
    }

    // Expired / cancelled
    if (session != null && (session.isExpired || session.isCancelled)) {
      return _ExpiredView(
        match: widget.match,
        onPropose: () => setState(() {}),
      );
    }

    // I need to respond (receiver of pending OR proposer of counter)
    final needToRespond = session != null &&
        ((session.isPending && !iAmProposer) ||
            (session.isCounterProposed && iAmProposer));

    // I'm waiting (proposer of pending OR receiver of counter)
    final amWaiting = session != null &&
        ((session.isPending && iAmProposer) ||
            (session.isCounterProposed && !iAmProposer));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Short Intro with ${widget.match.otherUserName ?? "Match"}'),
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoBanner(),
              const SizedBox(height: AppSpacing.xxl),

              // ── Need to respond ──────────────────────────────────────────
              if (needToRespond) ...[
                Text(
                  session.isCounterProposed && iAmProposer
                      ? 'Counter-Proposal Received'
                      : 'Proposed Time',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (session.isCounterProposed && iAmProposer) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${widget.match.otherUserName ?? "Your match"} suggested a different time.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                _TimeDisplay(scheduledAt: session.scheduledAt),
                const SizedBox(height: AppSpacing.md),
                _ExpiryCountdown(session: session),
                const SizedBox(height: AppSpacing.xl),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => _openDeclineCounter(session),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: AppColors.error.withValues(alpha: 0.7)),
                        foregroundColor: AppColors.error,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Decline & Counter'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : () => _accept(session),
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
                          : const Text('Accept'),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.xxl),
                const Divider(color: AppColors.border),
                const SizedBox(height: AppSpacing.md),
                Text('Or propose a new time:',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: AppSpacing.md),
              ],

              // ── Waiting for response ─────────────────────────────────────
              if (amWaiting) ...[
                _WaitingBanner(session: session),
                const SizedBox(height: AppSpacing.xxl),
              ],

              // ── Date / time picker (always shown for new proposal or counter) ──
              Text('Select Date',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              _DateSelector(
                selected: _selectedDate,
                onSelected: (d) => setState(() => _selectedDate = d),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Select Time',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              _TimeSelector(
                selected: _selectedTime,
                onSelected: (t) => setState(() => _selectedTime = t),
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.emerald600.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.emerald600.withValues(alpha: 0.12), width: 0.5),
                  boxShadow: Premium.shadowSm,
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded,
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
                  onPressed: _submitting
                      ? null
                      : (needToRespond
                          ? () => _sendCounter(session)
                          : _propose),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.bg))
                      : Text(
                          session != null
                              ? 'Send Counter Proposal'
                              : 'Propose This Time',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Decline & Counter bottom sheet
// ---------------------------------------------------------------------------

class _DeclineCounterSheet extends ConsumerStatefulWidget {
  final VideoSession session;
  final String responderId;
  final String matchId;
  final VoidCallback onDone;

  const _DeclineCounterSheet({
    required this.session,
    required this.responderId,
    required this.matchId,
    required this.onDone,
  });

  @override
  ConsumerState<_DeclineCounterSheet> createState() =>
      _DeclineCounterSheetState();
}

class _DeclineCounterSheetState extends ConsumerState<_DeclineCounterSheet> {
  int? _selectedIndex;
  bool _submitting = false;

  late DateTime _counterDate;
  late TimeOfDay _counterTimeOfDay;

  @override
  void initState() {
    super.initState();
    final soon = DateTime.now().add(const Duration(hours: 2));
    _counterDate = soon;
    _counterTimeOfDay = SchedulingConfig.snapTime(
      TimeOfDay(hour: soon.hour, minute: soon.minute),
    );
  }

  DateTime get _counterDateTime => DateTime(
        _counterDate.year,
        _counterDate.month,
        _counterDate.day,
        _counterTimeOfDay.hour,
        _counterTimeOfDay.minute,
      );

  Future<void> _submit() async {
    if (_selectedIndex == null) return;
    setState(() => _submitting = true);
    await ref.read(videoProvider(widget.matchId).notifier).decline(
          sessionId: widget.session.id,
          responderId: widget.responderId,
          reason: _declineReasons[_selectedIndex!],
          counterTime: _counterDateTime,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.pop(context); // close sheet
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final hasReason = _selectedIndex != null;
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
              child: Row(children: [
                const Icon(Icons.cancel_outlined,
                    color: AppColors.error, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Decline & Counter-Propose',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                'Select a reason — then pick a better time for you.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl),
                children: [
                  for (int i = 0; i < _declineReasons.length; i++) ...[
                    _ReasonTile(
                      reason: _declineReasons[i],
                      selected: _selectedIndex == i,
                      onTap: () => setState(() => _selectedIndex = i),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (hasReason) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text('Suggest a new date',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    _DateSelector(
                      selected: _counterDate,
                      onSelected: (d) =>
                          setState(() => _counterDate = d),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Suggest a new time',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    _TimeSelector(
                      selected: _counterTimeOfDay,
                      onSelected: (t) =>
                          setState(() => _counterTimeOfDay = t),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.emerald600.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(
                            color: AppColors.emerald600.withValues(alpha: 0.4)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.schedule_rounded,
                            color: AppColors.emerald600, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          DateFormat('EEE, d MMM · HH:mm')
                              .format(_counterDateTime),
                          style: const TextStyle(
                              color: AppColors.emerald600,
                              fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (!hasReason || _submitting)
                          ? null
                          : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasReason
                            ? AppColors.emerald600
                            : AppColors.surface,
                        foregroundColor: AppColors.bg,
                        disabledBackgroundColor:
                            AppColors.surface,
                        disabledForegroundColor:
                            AppColors.textDisabled,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.bg))
                          : Text(
                              hasReason
                                  ? 'Send Counter-Proposal'
                                  : 'Select a reason first',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Just decline (no counter)
                  Center(
                    child: TextButton(
                      onPressed: _submitting || !hasReason
                          ? null
                          : () async {
                              setState(() => _submitting = true);
                              await ref
                                  .read(videoProvider(widget.matchId)
                                      .notifier)
                                  .decline(
                                    sessionId: widget.session.id,
                                    responderId: widget.responderId,
                                    reason: _declineReasons[
                                        _selectedIndex!],
                                  );
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              widget.onDone();
                            },
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.textMuted),
                      child: const Text('Just decline (no counter)'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  final String reason;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonTile({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.emerald600.withValues(alpha: 0.1)
              : AppColors.bg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: selected ? AppColors.emerald600 : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: selected ? AppColors.emerald600 : AppColors.border,
                  width: 2),
              color: selected ? AppColors.emerald600 : Colors.transparent,
            ),
            child: selected
                ? const Icon(Icons.check, size: 12, color: AppColors.bg)
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              reason,
              style: TextStyle(
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textMuted,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-views
// ---------------------------------------------------------------------------

class _AcceptedView extends StatelessWidget {
  final NobleMatch match;
  final VideoSession session;
  const _AcceptedView({required this.match, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Video Call Confirmed'),
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_rounded,
                color: AppColors.emerald600, size: 72),
            const SizedBox(height: AppSpacing.xxl),
            Text('Call Confirmed!',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: AppColors.emerald600)),
            const SizedBox(height: AppSpacing.md),
            _TimeDisplay(scheduledAt: session.scheduledAt),
            const SizedBox(height: AppSpacing.xxxl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.videocam_rounded),
                label: const Text('Join Call'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald600,
                  foregroundColor: AppColors.bg,
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () => ShortIntroRulesScreen.launchCall(
                  context,
                  match: match,
                  session: session,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiredView extends StatelessWidget {
  final NobleMatch match;
  final VoidCallback onPropose;
  const _ExpiredView({required this.match, required this.onPropose});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Schedule with ${match.otherUserName ?? "Match"}'),
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_off_rounded,
                color: AppColors.error.withValues(alpha: 0.7), size: 64),
            const SizedBox(height: AppSpacing.xxl),
            Text('Proposal Expired',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.md),
            Text(
              'The 12-hour window to respond has passed.\nThis match has been removed.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  foregroundColor: AppColors.textMuted,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Go Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable widgets
// ---------------------------------------------------------------------------

class _WaitingBanner extends StatefulWidget {
  final VideoSession session;
  const _WaitingBanner({required this.session});

  @override
  State<_WaitingBanner> createState() => _WaitingBannerState();
}

class _WaitingBannerState extends State<_WaitingBanner> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.session.timeUntilExpiry;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = widget.session.timeUntilExpiry;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.hourglass_top_rounded,
                color: AppColors.textMuted, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Waiting for response…',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ]),
          const SizedBox(height: AppSpacing.xs),
          _TimeDisplay(scheduledAt: widget.session.scheduledAt),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            Icon(
              Icons.timer_outlined,
              size: 14,
              color: _remaining.inHours < 2
                  ? AppColors.error
                  : AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              'Expires in ${_fmt(_remaining)}',
              style: TextStyle(
                fontSize: 12,
                color: _remaining.inHours < 2
                    ? AppColors.error
                    : AppColors.textMuted,
                fontWeight: _remaining.inHours < 2
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ExpiryCountdown extends StatefulWidget {
  final VideoSession session;
  const _ExpiryCountdown({required this.session});

  @override
  State<_ExpiryCountdown> createState() => _ExpiryCountdownState();
}

class _ExpiryCountdownState extends State<_ExpiryCountdown> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.session.timeUntilExpiry;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = widget.session.timeUntilExpiry);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final urgent = _remaining.inHours < 2;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: urgent
            ? AppColors.error.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: urgent
              ? AppColors.error.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Row(children: [
        Icon(Icons.timer_outlined,
            size: 16, color: urgent ? AppColors.error : AppColors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Respond within ${_fmt(_remaining)}',
          style: TextStyle(
            fontSize: 13,
            color: urgent ? AppColors.error : AppColors.textMuted,
            fontWeight: urgent ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ]),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.emerald600.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.emerald600.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.videocam_rounded, color: AppColors.emerald600),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('First Call — 5 Minutes',
                    style: TextStyle(
                        color: AppColors.emerald600,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text(
                  'Chat opens only if both of you enjoy the call.',
                  style: TextStyle(
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

class _TimeDisplay extends StatelessWidget {
  final DateTime scheduledAt;
  const _TimeDisplay({required this.scheduledAt});

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
      child: Row(children: [
        const Icon(Icons.schedule_rounded, color: AppColors.emerald600, size: 28),
        const SizedBox(width: AppSpacing.md),
        Text(fmt.format(scheduledAt.toLocal()),
            style: const TextStyle(
                color: AppColors.emerald600, fontWeight: FontWeight.w600)),
      ]),
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
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final date = DateTime.now().add(Duration(days: i));
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
