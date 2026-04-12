import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/noble_mode.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../providers/mode_provider.dart';

/// Modes offered to the user in the mode switcher + mode selection dialog.
/// Date, BFF, Event (Event reuses the social enum value internally).
const List<NobleMode> _availableModes = [NobleMode.date, NobleMode.bff, NobleMode.social];

class ModeSwitcher extends ConsumerWidget {
  const ModeSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(modeProvider);

    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
        border: Border.all(color: context.borderSubtleColor, width: 0.5),
      ),
      child: Row(
        children: _availableModes
            .map((mode) => Expanded(
                  child: _ModeTab(mode: mode, isSelected: mode == current),
                ))
            .toList(),
      ),
    );
  }
}

class _ModeTab extends ConsumerWidget {
  final NobleMode mode;
  final bool isSelected;

  const _ModeTab({required this.mode, required this.isSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(modeProvider.notifier).setMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? mode.accentColor.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
          border: Border.all(
            color: isSelected
                ? mode.accentColor.withValues(alpha: 0.4)
                : context.borderSubtleColor,
            width: isSelected ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              mode.icon,
              size: 14,
              color: isSelected ? mode.accentColor : context.textMuted,
            ),
            const SizedBox(width: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? mode.accentColor : context.textMuted,
              ),
              child: Text(mode.shortLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen mode selection dialog (used from Profile tab or onboarding)
class ModeSelectionDialog extends ConsumerWidget {
  const ModeSelectionDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ModeSelectionDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(modeProvider);

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.xxxxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.borderColor,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Choose Your Mode',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Switch anytime from your profile.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: context.textMuted),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          // Show in reverse order (Social first when enabled) as original design
          ..._availableModes.reversed.map(
            (mode) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _ModeCard(mode: mode, isSelected: mode == current),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends ConsumerWidget {
  final NobleMode mode;
  final bool isSelected;

  const _ModeCard({required this.mode, required this.isSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(modeProvider.notifier).setMode(mode);
        Navigator.of(context).pop();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: isSelected ? mode.accentLight : context.surfaceAltColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: isSelected ? mode.accentColor : context.borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: mode.accentLight,
                shape: BoxShape.circle,
              ),
              child: Icon(mode.icon, color: mode.accentColor, size: 24),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isSelected
                              ? mode.accentColor
                              : context.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mode.subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: context.textMuted),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: mode.accentColor,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
