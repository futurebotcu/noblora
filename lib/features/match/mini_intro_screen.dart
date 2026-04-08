import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/noble_mode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/premium.dart';
import '../../data/models/match.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mini_intro_provider.dart';
import '../../services/gemini_service.dart';
import 'video_scheduling_screen.dart';

/// Mini Intro screen — shown after a Connection is made.
/// User sends a short intro (max 280 chars), optionally AI-assisted.
class MiniIntroScreen extends ConsumerStatefulWidget {
  final NobleMatch match;

  const MiniIntroScreen({super.key, required this.match});

  @override
  ConsumerState<MiniIntroScreen> createState() => _MiniIntroScreenState();
}

class _MiniIntroScreenState extends ConsumerState<MiniIntroScreen> {
  final _controller = TextEditingController();
  bool _isSending = false;
  bool _isLoadingOpeners = false;
  List<String> _openers = [];

  NobleMode get _mode {
    switch (widget.match.mode) {
      case 'bff':
        return NobleMode.bff;
      case 'social':
        return NobleMode.social;
      default:
        return NobleMode.date;
    }
  }

  String get _otherName => widget.match.otherUserName ?? 'your connection';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generateOpeners() async {
    setState(() => _isLoadingOpeners = true);
    try {
      final openers = await GeminiService.generateOpeners(
        userName: 'You',
        otherName: _otherName,
        userBio: '',
        otherBio: '',
      );
      setState(() => _openers = openers);
    } catch (_) {
      // Fallback openers
      setState(() => _openers = [
            'Hey $_otherName, nice to connect!',
            'Looking forward to getting to know you.',
            'What brought you to Noblara?',
          ]);
    }
    setState(() => _isLoadingOpeners = false);
  }

  Future<void> _sendIntro() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;

    final notifier = ref.read(miniIntroProvider(widget.match.id).notifier);
    await notifier.sendIntro(
      matchId: widget.match.id,
      senderId: userId,
      message: text,
    );

    // Advance to pending_video (authorized + state-checked)
    await notifier.advanceToVideo(widget.match.id, userId);

    if (!mounted) return;
    setState(() => _isSending = false);

    // Navigate to video scheduling
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => VideoSchedulingScreen(match: widget.match),
      ),
    );
  }

  void _skipForNow() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mode = _mode;
    final introState = ref.watch(miniIntroProvider(widget.match.id));
    final otherIntro = introState.intros
        .where((i) => i.senderId != ref.read(authProvider).userId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Mini Intro'),
        backgroundColor: AppColors.bg,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile photo & name
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: mode.accentLight,
                      child: Text(
                        (_otherName.isNotEmpty ? _otherName[0] : '?')
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: mode.accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _otherName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Other user's intro (if received)
              if (otherIntro != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: mode.accentColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: mode.accentColor.withValues(alpha: 0.12), width: 0.5),
                    boxShadow: Premium.shadowSm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_otherName says:',
                        style: TextStyle(
                          color: mode.accentColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        otherIntro.message,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Intro text field
              TextField(
                controller: _controller,
                maxLength: 280,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Write a short intro...',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  counterStyle: const TextStyle(color: AppColors.textMuted),
                ),
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.md),

              // AI Opener button
              OutlinedButton.icon(
                onPressed: _isLoadingOpeners ? null : _generateOpeners,
                icon: _isLoadingOpeners
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.auto_awesome, color: mode.accentColor),
                label: Text(
                  'Need an opener?',
                  style: TextStyle(color: mode.accentColor),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: mode.accentColor.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
              ),

              // Opener suggestions
              if (_openers.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                ..._openers.map((opener) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: InkWell(
                        onTap: () => _controller.text = opener,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Text(
                            opener,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    )),
              ],

              const Spacer(),

              // Schedule Short Intro button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  boxShadow: _isSending ? null : Premium.accentGlow(mode.accentColor, intensity: 0.6),
                ),
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendIntro,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mode.accentColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                child: _isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: AppColors.bg, strokeWidth: 2),
                      )
                    : const Text(
                        'Send & Schedule Short Intro',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Skip
              TextButton(
                onPressed: _skipForNow,
                child: const Text(
                  'Skip for now',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
