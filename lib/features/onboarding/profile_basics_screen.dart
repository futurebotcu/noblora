import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../providers/profile_provider.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';

/// Onboarding step: collect display name only.
/// Mode and gender are deferred until deployed DB columns are confirmed.
/// AppRouter drives navigation — once profileProvider.hasProfile is true
/// the router automatically advances to the verification screen.
class ProfileBasicsScreen extends ConsumerStatefulWidget {
  const ProfileBasicsScreen({super.key});

  @override
  ConsumerState<ProfileBasicsScreen> createState() =>
      _ProfileBasicsScreenState();
}

class _ProfileBasicsScreenState extends ConsumerState<ProfileBasicsScreen> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(profileProvider.notifier).createProfile(
          fullName: _nameCtrl.text.trim(),
          currentMode: 'date',
        );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxxxl),
                Text(
                  'Welcome to Noblara',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'What should we call you?',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: context.textMuted,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxxxl),
                AppTextField(
                  controller: _nameCtrl,
                  label: 'Your name',
                  hint: 'e.g. Sofia',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name required' : null,
                ),
                if (profile.error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    profile.error!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 13),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxxxl),
                AppButton(
                  label: "Let's Go",
                  isLoading: profile.isLoading,
                  onPressed: profile.isLoading ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
