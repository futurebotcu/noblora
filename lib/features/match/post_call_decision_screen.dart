import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/premium.dart';
import '../../data/models/match.dart';
import '../../data/models/video_session.dart';
import '../../providers/auth_provider.dart';
import '../../providers/video_provider.dart';

class PostCallDecisionScreen extends ConsumerStatefulWidget {
  final NobleMatch match;
  final VideoSession session;

  const PostCallDecisionScreen({
    super.key,
    required this.match,
    required this.session,
  });

  @override
  ConsumerState<PostCallDecisionScreen> createState() =>
      _PostCallDecisionScreenState();
}

class _PostCallDecisionScreenState
    extends ConsumerState<PostCallDecisionScreen> {
  bool _submitting = false;
  bool _decided = false;
  bool _waiting = false; // submitted, waiting for other person
  StreamSubscription<List<Map<String, dynamic>>>? _decisionSub;
  Timer? _expiryTimer;

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _decisionSub?.cancel();
    super.dispose();
  }

  Future<void> _submit(bool enjoyed) async {
    if (_decided) return;
    setState(() {
      _submitting = true;
      _decided = true;
    });

    final userId = ref.read(authProvider).userId ?? '';
    final result = await ref
        .read(videoProvider(widget.match.id).notifier)
        .submitDecision(userId: userId, enjoyed: enjoyed);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result == 'waiting') {
      // My decision is in — wait for the other person via realtime
      setState(() => _waiting = true);
      _listenForOtherDecision();
    } else {
      _handleResult(result);
    }
  }

  void _listenForOtherDecision() {
    // Timeout: if other user doesn't decide in 10 minutes, expire
    _expiryTimer?.cancel();
    _expiryTimer = Timer(const Duration(minutes: 10), () {
      if (mounted && _waiting) {
        _decisionSub?.cancel();
        _handleResult('expired');
      }
    });
    _decisionSub?.cancel();
    _decisionSub = Supabase.instance.client
        .from('call_decisions')
        .stream(primaryKey: ['id'])
        .eq('video_session_id', widget.session.id)
        .listen(
          (rows) async {
            if (rows.length < 2) return; // still waiting
            // Both decisions are in — finalize without re-upserting
            try {
              final userId = ref.read(authProvider).userId ?? '';
              final myRow = rows.firstWhere(
                (r) => r['user_id'] == userId,
                orElse: () => <String, dynamic>{},
              );
              final myEnjoyed = myRow['enjoyed'] as bool? ?? false;
              final result = await ref
                  .read(videoProvider(widget.match.id).notifier)
                  .finalizeDecision(userId: userId, enjoyed: myEnjoyed);
              if (!mounted) return;
              _decisionSub?.cancel();
              _handleResult(result);
            } catch (e) {
              debugPrint('[post-call] Decision finalization error: $e');
            }
          },
          onError: (Object e) {
            _decisionSub?.cancel();
          },
        );
  }

  void _handleResult(String result) {
    if (result == 'chat_opened') {
      _showChatOpenedDialog();
    } else if (result == 'closed' || result == 'expired') {
      _showClosedDialog();
    }
    // 'waiting' → already handled above
  }

  void _showChatOpenedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: Premium.dialogShape(),
        title: const Row(children: [
          Icon(Icons.chat_bubble_rounded, color: AppColors.emerald600),
          SizedBox(width: AppSpacing.sm),
          Text('Chat is Open!', style: TextStyle(color: AppColors.emerald600)),
        ]),
        content: Text(
          "You're both in! Start chatting and take your time getting to know each other.",
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textMuted),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald600,
              foregroundColor: AppColors.bg,
            ),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Start Chatting'),
          ),
        ],
      ),
    );
  }

  void _showClosedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: Premium.dialogShape(),
        title: const Row(children: [
          Icon(Icons.link_off_rounded,
              color: AppColors.textMuted, size: 20),
          SizedBox(width: AppSpacing.sm),
          Text('Connection Ended',
              style: TextStyle(color: AppColors.textMuted)),
        ]),
        content: Text(
          "This connection has ended. Not every match is meant to be — and that's perfectly fine.",
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Back to Feed'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: _waiting ? _buildWaitingView() : _buildDecisionView(),
        ),
      ),
    );
  }

  Widget _buildWaitingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            color: AppColors.emerald600,
            strokeWidth: 2,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Decision sent!',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Waiting for ${widget.match.otherUserName ?? "your match"} to share their decision…',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Both decisions are private.\nYou\'ll be notified as soon as they respond.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textDisabled),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDecisionView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.videocam_off_rounded,
            color: AppColors.emerald600, size: 64),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Call Ended',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'How was your Short Intro with ${widget.match.otherUserName ?? "this person"}?',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxxl),
        if (_submitting)
          const CircularProgressIndicator(color: AppColors.emerald600)
        else ...[
          _DecisionButton(
            label: 'Keep Open',
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.emerald600,
            onTap: () => _submit(true),
          ),
          const SizedBox(height: AppSpacing.lg),
          _DecisionButton(
            label: 'Pass',
            icon: Icons.close_rounded,
            color: AppColors.textMuted,
            onTap: () => _submit(false),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Both decisions are private.\nChat opens only if both choose Keep Open.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        // Privacy notice
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded,
                color: AppColors.textDisabled, size: 12),
            const SizedBox(width: 4),
            Text(
              'Calls are not recorded.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                      color: AppColors.textDisabled, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

class _DecisionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DecisionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressEffect(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
          boxShadow: [
            ...Premium.shadowMd,
            BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 16, spreadRadius: -2),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
