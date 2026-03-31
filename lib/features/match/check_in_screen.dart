import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/check_in_provider.dart';

/// Post-meetup check-in screen — "How did it go? Are you okay?"
class CheckInScreen extends ConsumerWidget {
  final String meetingId;
  final String otherUserName;

  const CheckInScreen({
    super.key,
    required this.meetingId,
    required this.otherUserName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkInProvider(meetingId));
    final userId = ref.read(authProvider).userId ?? '';

    if (state.isSubmitted) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.gold, size: 64),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Thanks for checking in!',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Your response helps keep Noblara safe.',
                    style: TextStyle(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bg,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Check-in'),
        backgroundColor: AppColors.bg,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.health_and_safety_outlined,
                  color: AppColors.gold, size: 64),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'How did it go?',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'You met with $otherUserName. Are you okay?',
                style: const TextStyle(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              if (state.isLoading)
                const CircularProgressIndicator(color: AppColors.gold)
              else ...[
                _ResponseButton(
                  label: 'Great!',
                  icon: Icons.sentiment_very_satisfied_rounded,
                  color: AppColors.gold,
                  onTap: () => _submit(ref, userId, 'great'),
                ),
                const SizedBox(height: AppSpacing.md),
                _ResponseButton(
                  label: 'It was okay',
                  icon: Icons.sentiment_neutral_rounded,
                  color: AppColors.textMuted,
                  onTap: () => _submit(ref, userId, 'okay'),
                ),
                const SizedBox(height: AppSpacing.md),
                _ResponseButton(
                  label: "I'd rather not say",
                  icon: Icons.remove_circle_outline_rounded,
                  color: AppColors.textMuted,
                  onTap: () => _submit(ref, userId, 'rather_not_say'),
                ),
                const SizedBox(height: AppSpacing.md),
                _ResponseButton(
                  label: 'Report an issue',
                  icon: Icons.flag_outlined,
                  color: AppColors.error,
                  onTap: () => _submit(ref, userId, 'report'),
                ),
              ],
              if (state.error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  state.error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _submit(WidgetRef ref, String userId, String response) {
    ref.read(checkInProvider(meetingId).notifier).submitCheckIn(
          meetingId: meetingId,
          userId: userId,
          response: response,
        );
  }
}

class _ResponseButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ResponseButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
