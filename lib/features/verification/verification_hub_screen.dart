import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/premium.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gating_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/verification_provider.dart';

class VerificationHubScreen extends ConsumerWidget {
  const VerificationHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verif = ref.watch(verificationProvider);
    final status = verif.verificationStatus;
    final claimedGender = ref.watch(profileProvider).profile?.gender;

    // Upload steps are interactive only in idle / rejected / error states.
    final inputsEnabled = status == VerificationStatus.idle ||
        status == VerificationStatus.rejected ||
        status == VerificationStatus.error;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        actions: [
          TextButton.icon(
            icon: Icon(Icons.logout, size: 16, color: context.textMuted),
            label: Text('Sign Out',
                style: TextStyle(color: context.textMuted, fontSize: 12)),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Icon(Icons.shield_outlined, color: context.accent, size: 48),
              const SizedBox(height: AppSpacing.lg),
              Text('Verify Your Identity',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: context.textPrimary)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Add a selfie and a profile photo. '
                'Both are analysed together by AI.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: context.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Gender reminder banner ────────────────────────────────────
              // Reminds the user which gender they declared so the selfie
              // matches their profile — helps avoid manual review friction.
              if (claimedGender != null && inputsEnabled)
                _GenderReminderBanner(gender: claimedGender),

              const SizedBox(height: AppSpacing.xl),

              // ── Upload steps ──────────────────────────────────────────────
              // Hidden during manual_review (photos are submitted — nothing to change)
              if (status != VerificationStatus.manualReview) ...[
                _VerifStep(
                  step: 1,
                  title: 'Selfie',
                  subtitle: verif.pendingSelfieBytes != null
                      ? 'Selfie ready — tap to re-take'
                      : 'Take a selfie with your camera',
                  icon: Icons.face_rounded,
                  isCompleted: verif.selfieApproved,
                  isStaged: verif.pendingSelfieBytes != null,
                  isLoading: status == VerificationStatus.loading,
                  onTap: inputsEnabled
                      ? () => _stageImage(ref, 'selfie')
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                _VerifStep(
                  step: 2,
                  title: 'Profile Photo',
                  subtitle: verif.pendingProfileBytes != null
                      ? 'Photo ready — tap to change'
                      : 'Upload an authentic photo from your gallery',
                  icon: Icons.photo_camera_rounded,
                  isCompleted: verif.hasApprovedPhoto,
                  isStaged: verif.pendingProfileBytes != null,
                  isLoading: status == VerificationStatus.loading,
                  onTap: inputsEnabled
                      ? () => _stageImage(ref, 'profile')
                      : null,
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],

              // ── Verify button ─────────────────────────────────────────────
              // Only when both photos are staged and status allows submission
              if (verif.bothStaged && inputsEnabled) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.accent,
                      foregroundColor: AppColors.textOnEmerald,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd)),
                    ),
                    onPressed: () =>
                        ref.read(verificationProvider.notifier).verifyBoth(),
                    icon: const Icon(Icons.verified_user_rounded),
                    label: const Text('Verify Both Photos',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // ── Loading indicator (standalone, shown above banner) ─────────
              if (status == VerificationStatus.loading) ...[
                Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: context.accent),
                      const SizedBox(height: AppSpacing.md),
                      Text('Analysing photos…',
                          style: TextStyle(
                              color: context.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

              // ── Status banner ─────────────────────────────────────────────
              if (status == VerificationStatus.approved ||
                  status == VerificationStatus.manualReview ||
                  status == VerificationStatus.rejected) ...[
                _StatusBanner(
                  status: status,
                  reason: verif.lastResult?.aiReason ?? '',
                  onRetry: status == VerificationStatus.rejected
                      ? () => ref
                          .read(verificationProvider.notifier)
                          .clearStaged()
                      : null,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

              // ── Error text ────────────────────────────────────────────────
              if (status == VerificationStatus.error &&
                  verif.error != null) ...[
                _StatusBanner(
                  status: VerificationStatus.error,
                  reason: verif.error!,
                  onRetry: () =>
                      ref.read(verificationProvider.notifier).clearStaged(),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // ── Continue button (approved only) ───────────────────────────
              if (status == VerificationStatus.approved)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.accent,
                      foregroundColor: AppColors.textOnEmerald,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd)),
                    ),
                    onPressed: () async {
                      final userId = ref.read(authProvider).userId ?? '';
                      await ref
                          .read(gatingProvider.notifier)
                          .markVerified(userId);
                    },
                    child: const Text('Continue',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _stageImage(WidgetRef ref, String photoType) async {
    final picker = ImagePicker();
    final source =
        photoType == 'selfie' ? ImageSource.camera : ImageSource.gallery;

    final file = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    ref.read(verificationProvider.notifier).stageImage(
          bytes: bytes,
          photoType: photoType,
        );
  }
}

// ---------------------------------------------------------------------------
// _VerifStep
// ---------------------------------------------------------------------------

class _VerifStep extends StatelessWidget {
  final int step;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isCompleted;
  final bool isStaged;
  final bool isLoading;
  final VoidCallback? onTap; // null → non-interactive

  const _VerifStep({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isCompleted,
    required this.isStaged,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    final Color iconBg;
    final Color iconColor;
    final IconData displayIcon;

    if (isCompleted) {
      borderColor = AppColors.success.withValues(alpha: 0.5);
      iconBg = AppColors.success.withValues(alpha: 0.1);
      iconColor = AppColors.success;
      displayIcon = Icons.check_circle_rounded;
    } else if (isStaged) {
      borderColor = AppColors.emerald500.withValues(alpha: 0.7);
      iconBg = AppColors.emerald500.withValues(alpha: 0.15);
      iconColor = AppColors.emerald500;
      displayIcon = Icons.check_rounded;
    } else {
      borderColor = context.borderColor;
      iconBg = AppColors.emerald500.withValues(alpha: 0.1);
      iconColor = AppColors.emerald500;
      displayIcon = icon;
    }

    return GestureDetector(
      onTap: (isCompleted || isLoading || onTap == null) ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: borderColor, width: 0.5),
          boxShadow: Premium.shadowMd,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(displayIcon, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? AppColors.success
                              : context.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: context.textMuted, fontSize: 13)),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.emerald500))
            else if (!isCompleted && onTap != null)
              Icon(
                isStaged
                    ? Icons.refresh_rounded
                    : Icons.chevron_right_rounded,
                color: context.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _StatusBanner — handles approved | manualReview | rejected | error
// ---------------------------------------------------------------------------

class _StatusBanner extends StatelessWidget {
  final VerificationStatus status;
  final String reason;
  final VoidCallback? onRetry;

  const _StatusBanner({
    required this.status,
    required this.reason,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String title, String? body) =
        switch (status) {
      VerificationStatus.approved => (
          AppColors.success,
          Icons.check_circle_rounded,
          'Identity Verified',
          reason.isNotEmpty ? reason : null,
        ),
      VerificationStatus.manualReview => (
          AppColors.warning,
          Icons.hourglass_top_rounded,
          'Photos Under Review',
          'Our team will review your photos within 24 hours. '
              'You\'ll be notified once a decision is made.',
        ),
      VerificationStatus.rejected => (
          AppColors.error,
          Icons.cancel_rounded,
          'Verification Failed',
          reason.isNotEmpty ? reason : null,
        ),
      _ => (                   // error
          AppColors.error,
          Icons.error_outline_rounded,
          'Something went wrong',
          reason.isNotEmpty ? reason : null,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.20), width: 0.5),
        boxShadow: Premium.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w600)),
                    if (body != null) ...[
                      const SizedBox(height: 2),
                      Text(body,
                          style: TextStyle(
                              color: context.textMuted, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // Retry link — only for rejected and error
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: onRetry,
              child: Text(
                'Tap to retry with new photos',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _GenderReminderBanner
// Shown when user is about to submit photos — reminds them which gender
// they declared so the selfie matches the profile claim.
// ---------------------------------------------------------------------------

class _GenderReminderBanner extends StatelessWidget {
  final String gender; // 'male' | 'female' | 'other'
  const _GenderReminderBanner({required this.gender});

  @override
  Widget build(BuildContext context) {
    final (String label, String emoji) = switch (gender) {
      'female' => ('Woman', '👩'),
      'male'   => ('Man', '👨'),
      _        => ('Other', '🌿'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.emerald500.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                    color: context.textMuted, fontSize: 13),
                children: [
                  const TextSpan(text: 'You declared as '),
                  TextSpan(
                    text: label,
                    style: const TextStyle(
                        color: AppColors.emerald500,
                        fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(
                      text:
                          '. Please upload a selfie that matches this identity.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
