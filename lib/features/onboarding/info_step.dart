import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/premium.dart';

/// Onboarding info step shown right after Welcome (R13 V1 launch path).
///
/// Mandatory acknowledgement of the V1 regional scope — Thailand, Vietnam,
/// Philippines. No skip; the user must press Continue before proceeding to
/// Basics. Users outside these regions can still complete onboarding and
/// unlock interactions later via Travel Mode (Settings) — the body copy
/// primes that escape hatch so the gate (Discover swipe-locked banner +
/// `create_swipe_with_gate` RPC) doesn't read as a hard block later.
///
/// Lives in its own file (rather than as a private widget inside
/// `onboarding_flow_screen.dart`) so the host file's growing list of
/// `_*Page` widgets stays manageable; this is the first onboarding step
/// that's purely informational rather than data-collecting.
class OnboardingInfoStep extends StatelessWidget {
  final VoidCallback onNext;

  const OnboardingInfoStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),

          Text(
            'Welcome to Noblara',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Currently available in',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textMuted,
              fontSize: 14,
              letterSpacing: 0.3,
            ),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // Three regions side-by-side. Flags rendered via system emoji font;
          // a fontSize of 48 is large enough that even Android's older
          // emoji subsets render the regional flag glyphs without falling
          // back to letter pairs (TH/VN/PH).
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RegionChip(flag: '🇹🇭', label: 'Thailand'),
              _RegionChip(flag: '🇻🇳', label: 'Vietnam'),
              _RegionChip(flag: '🇵🇭', label: 'Philippines'),
            ],
          ),

          const SizedBox(height: AppSpacing.xxxxl),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              "We connect travelers and locals across Thailand, Vietnam, and "
              "the Philippines. If you're outside these regions, you can "
              "still join — activate Travel Mode to match with people in "
              "your destination.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textMuted,
                fontSize: 14,
                height: 1.6,
                letterSpacing: 0.1,
              ),
            ),
          ),

          const Spacer(flex: 2),

          // Mandatory acknowledgement — no Skip. The button advertises the
          // gesture explicitly so users with screen readers don't infer it
          // from the gradient alone.
          Semantics(
            button: true,
            label: 'Continue to onboarding',
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                boxShadow: Premium.emeraldGlow(intensity: 0.7),
              ),
              child: ElevatedButton(
                onPressed: onNext,
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxxxl),
        ],
      ),
    );
  }
}

class _RegionChip extends StatelessWidget {
  final String flag;
  final String label;

  const _RegionChip({required this.flag, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(flag, style: const TextStyle(fontSize: 48)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
