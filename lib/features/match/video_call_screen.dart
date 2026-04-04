import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/match.dart';
import '../../data/models/video_session.dart';
import '../../providers/profile_provider.dart';
import '../../providers/video_provider.dart';
import '../../services/gemini_service.dart';
import '../../services/video_service.dart';
import 'post_call_decision_screen.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  final NobleMatch match;
  final VideoSession session;

  const VideoCallScreen({
    super.key,
    required this.match,
    required this.session,
  });

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  late final Duration _callDuration;

  final ValueNotifier<Duration> _remaining = ValueNotifier(Duration.zero);
  Timer? _timer;
  bool _callStarted = false;
  bool _callEnded = false;
  bool _isAudioPhase = true; // first 60s is audio-only
  String? _topicSuggestion;
  bool _loadingTopic = false;

  @override
  void initState() {
    super.initState();
    _callDuration = Duration(minutes: widget.session.callDurationMinutes);
    _remaining.value = _callDuration;
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCallOrWait());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remaining.dispose();
    super.dispose();
  }

  void _startCallOrWait() {
    final now = DateTime.now();
    final scheduled = widget.session.scheduledAt;
    final diff = scheduled.difference(now);

    if (diff.isNegative || diff.inMinutes < 1) {
      _beginCall();
    } else {
      _remaining.value = diff;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final r = widget.session.scheduledAt.difference(DateTime.now());
        if (r.isNegative) {
          _timer?.cancel();
          _beginCall();
        } else {
          if (mounted) _remaining.value = r;
        }
      });
    }
  }

  void _beginCall() {
    _timer?.cancel();
    setState(() {
      _callStarted = true;
      _isAudioPhase = true;
      _remaining.value = _callDuration;
    });

    final notifier = ref.read(videoProvider(widget.match.id).notifier);
    notifier.markStarted(widget.session.id);
    notifier.startCallTimer(widget.session.id);

    final displayName =
        ref.read(profileProvider).profile?.displayName ?? '';

    // Open call (audio-only config for first 60s, then video)
    VideoService.openCall(widget.match.id, displayName: displayName)
        .catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open video call. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    // Audio→video phase transition after 60 seconds
    Future.delayed(const Duration(seconds: 60), () {
      if (mounted && _callStarted && !_callEnded) {
        setState(() => _isAudioPhase = false);
      }
    });

    // Local countdown — ValueNotifier avoids full widget rebuild per tick
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final videoState = ref.read(videoProvider(widget.match.id));
      final remaining = videoState.callTimeRemaining ?? Duration.zero;
      _remaining.value = remaining;

      if (remaining.inSeconds <= 0) {
        _timer?.cancel();
        _onCallEnded();
      }
    });
  }

  void _onCallEnded() {
    if (_callEnded) return;
    _callEnded = true;
    ref.read(videoProvider(widget.match.id).notifier).stopCallTimer();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PostCallDecisionScreen(
          match: widget.match,
          session: widget.session,
        ),
      ),
    );
  }

  Future<void> _suggestTopic() async {
    setState(() => _loadingTopic = true);
    try {
      final topic = await GeminiService.suggestTopic(
        userName: ref.read(profileProvider).profile?.displayName ?? 'You',
        otherName: widget.match.otherUserName ?? 'your match',
      );
      if (mounted) setState(() => _topicSuggestion = topic);
    } catch (_) {
      if (mounted) {
        setState(() => _topicSuggestion = '[AI unavailable] What do you enjoy doing on weekends?');
      }
    }
    if (mounted) setState(() => _loadingTopic = false);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _callStarted ? _buildCallUI() : _buildWaitingUI(),
      ),
    );
  }

  Widget _buildWaitingUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded, color: AppColors.gold, size: 64),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'Call starts in',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _formatDuration(_remaining.value),
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 52,
                fontWeight: FontWeight.w300,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'The video call will open automatically.\nMake sure your camera and microphone are ready.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline_rounded,
                      color: AppColors.textMuted, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'This call is private. Recording is disabled.',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                foregroundColor: AppColors.error,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallUI() {
    final pct = _remaining.value.inSeconds / _callDuration.inSeconds;
    final color = pct > 0.4
        ? AppColors.gold
        : pct > 0.15
            ? Colors.orange
            : AppColors.error;

    return Stack(
      children: [
        // Background
        Container(
          color: AppColors.bg,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isAudioPhase ? Icons.mic_rounded : Icons.videocam_rounded,
                  color: AppColors.gold, size: 80,
                ),
                const SizedBox(height: AppSpacing.xl),
                // Phase indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: (_isAudioPhase ? Colors.blue : AppColors.gold).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
                    border: Border.all(color: (_isAudioPhase ? Colors.blue : AppColors.gold).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _isAudioPhase ? 'Audio Only — Video starts soon' : 'Video Phase',
                    style: TextStyle(
                      color: _isAudioPhase ? Colors.blue : AppColors.gold,
                      fontSize: 12, fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _isAudioPhase ? 'Just voices, no pressure' : 'Call open in browser',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.match.otherUserName ?? 'Your Match',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '${widget.session.callDurationMinutes}-minute Short Intro',
                  style: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Timer overlay
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.bg.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Time Remaining',
                        style:
                            TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    Text(
                      _formatDuration(_remaining.value),
                      style: TextStyle(
                        color: color,
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ),

        // AI Topic suggestion (floating, dismissible)
        if (_topicSuggestion != null)
          Positioned(
            bottom: 120,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: AppColors.gold, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _topicSuggestion!,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _topicSuggestion = null),
                    child: const Icon(Icons.close,
                        color: AppColors.textMuted, size: 18),
                  ),
                ],
              ),
            ),
          ),

        // Bottom buttons: topic + end call
        Positioned(
          bottom: AppSpacing.xxl,
          left: 0,
          right: 0,
          child: Center(
            child: Column(
              children: [
                // "Need a topic?" button
                GestureDetector(
                  onTap: _loadingTopic ? null : _suggestTopic,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.6),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_loadingTopic)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.gold),
                          )
                        else
                          const Icon(Icons.lightbulb_outline,
                              color: AppColors.gold, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Need a topic?',
                          style: TextStyle(
                            color: AppColors.gold.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                GestureDetector(
                  onTap: _onCallEnded,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_end_rounded,
                        color: AppColors.textOnEmerald, size: 28),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text('End Call',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
