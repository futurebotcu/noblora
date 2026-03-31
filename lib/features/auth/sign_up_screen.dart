import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(authProvider.notifier).signUp(
          _emailCtrl.text.trim(),
          _passCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    // When sign-up is immediately active (no email confirmation), clear nav stack.
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.isAuthenticated && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    final auth = ref.watch(authProvider);

    // "already_registered" is a sentinel — show it with a sign-in link.
    final isAlreadyRegistered = auth.error == 'already_registered';
    final errorText = isAlreadyRegistered ? null : auth.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxxl),
                Text(
                  'Join Noblara',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xxl),

                AppTextField(
                  controller: _emailCtrl,
                  label: 'Email',
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email required';
                    final valid = RegExp(
                            r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
                        .hasMatch(v.trim());
                    if (!valid) return 'Enter a valid email address';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                AppTextField(
                  controller: _passCtrl,
                  label: 'Password',
                  hint: '••••••••',
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password required';
                    if (v.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Email confirmation banner ──────────────────────────────
                if (auth.needsEmailConfirmation)
                  _InfoBanner(
                    icon: Icons.mark_email_unread_outlined,
                    color: AppColors.info,
                    message:
                        'Account created! Check your inbox and click the confirmation link to activate your account.',
                  ),

                // ── Already registered banner ──────────────────────────────
                if (isAlreadyRegistered)
                  _InfoBanner(
                    icon: Icons.person_outline,
                    color: AppColors.warning,
                    message:
                        'This email is already registered.',
                    trailing: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Sign in instead',
                        style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                // ── Generic error ──────────────────────────────────────────
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      errorText,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 13),
                    ),
                  ),

                const SizedBox(height: AppSpacing.xxxl),

                AppButton(
                  label: 'Create Account',
                  isLoading: auth.isLoading,
                  onPressed: auth.isLoading ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final Widget? trailing;

  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.message,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message,
                style: TextStyle(color: color, fontSize: 13)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
