import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../shared/widgets/app_button.dart';

// ---------------------------------------------------------------------------
// GenderSelectionScreen
//
// Appears AFTER ProfileBasicsScreen (name), BEFORE VerificationHubScreen.
// AppRouter drives navigation — no Navigator.push needed here.
// When updateGender() succeeds, profileState.hasGender becomes true and
// AppRouter automatically advances to VerificationHubScreen.
// ---------------------------------------------------------------------------

class GenderSelectionScreen extends ConsumerStatefulWidget {
  const GenderSelectionScreen({super.key});

  @override
  ConsumerState<GenderSelectionScreen> createState() =>
      _GenderSelectionScreenState();
}

class _GenderSelectionScreenState
    extends ConsumerState<GenderSelectionScreen> {
  String? _selected; // 'male' | 'female' | 'other'

  static const _options = [
    _GenderOption(
      value: 'female',
      label: 'Woman',
      emoji: '👩',
    ),
    _GenderOption(
      value: 'male',
      label: 'Man',
      emoji: '👨',
    ),
    _GenderOption(
      value: 'other',
      label: 'Prefer not to say',
      emoji: '🌿',
    ),
  ];

  Future<void> _submit() async {
    if (_selected == null) return;
    await ref.read(profileProvider.notifier).updateGender(_selected!);
    // AppRouter will advance automatically once hasGender = true
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.logout, size: 16, color: AppColors.textMuted),
            label: const Text('Sign Out',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'I identify as…',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This is used to match you correctly\nand verified with your selfie.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxxxl),
              ...(_options.map(
                (opt) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _GenderTile(
                    option: opt,
                    isSelected: _selected == opt.value,
                    onTap: () => setState(() => _selected = opt.value),
                  ),
                ),
              )),
              if (profile.error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  profile.error!,
                  style:
                      const TextStyle(color: AppColors.error, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              AppButton(
                label: 'Continue',
                isLoading: profile.isLoading,
                onPressed: (_selected == null || profile.isLoading)
                    ? null
                    : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _GenderOption
// ---------------------------------------------------------------------------

class _GenderOption {
  final String value;
  final String label;
  final String emoji;
  const _GenderOption(
      {required this.value, required this.label, required this.emoji});
}

// ---------------------------------------------------------------------------
// _GenderTile
// ---------------------------------------------------------------------------

class _GenderTile extends StatelessWidget {
  final _GenderOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.borderGold : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(option.emoji,
                style: const TextStyle(fontSize: 22)),
            const SizedBox(width: AppSpacing.lg),
            Text(
              option.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isSelected ? AppColors.gold : AppColors.textPrimary,
                  ),
            ),
            if (isSelected) ...[
              const Spacer(),
              const Icon(Icons.check_circle, color: AppColors.gold, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
