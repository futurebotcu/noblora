import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/mock_mode.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import 'otp_verification_screen.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _countryCode = '+90';
  bool _sendingOtp = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final phone = '$_countryCode${_phoneCtrl.text.trim().replaceAll(' ', '')}';

    // If phone is provided, send OTP first
    if (_phoneCtrl.text.trim().isNotEmpty) {
      setState(() => _sendingOtp = true);
      try {
        if (!isMockMode) {
          await Supabase.instance.client.auth.signInWithOtp(phone: phone);
        }
        if (mounted) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              phone: phone,
              email: _emailCtrl.text.trim(),
              password: _passCtrl.text,
            ),
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send code: $e'), backgroundColor: AppColors.error));
        }
      } finally {
        if (mounted) setState(() => _sendingOtp = false);
      }
      return;
    }

    // No phone — direct email sign-up
    await ref.read(authProvider.notifier).signUp(
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    // When sign-up is immediately active, clear nav stack.
    ref.listen(authProvider, (prev, next) {
      if (next.isAuthenticated && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    final auth = ref.watch(authProvider);
    final isAlreadyRegistered = auth.error == 'already_registered';
    final errorText = isAlreadyRegistered ? null : auth.error;
    final isLoading = auth.isLoading || _sendingOtp;

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
                Text('Join Noblara', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.xxl),

                // Email
                AppTextField(
                  controller: _emailCtrl,
                  label: 'Email',
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email required';
                    final valid = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
                        .hasMatch(v.trim());
                    if (!valid) return 'Enter a valid email address';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Phone number
                _PhoneField(
                  controller: _phoneCtrl,
                  countryCode: _countryCode,
                  onCountryCodeChanged: (v) => setState(() => _countryCode = v),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Password
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

                // Banners
                if (auth.needsEmailConfirmation)
                  _InfoBanner(
                    icon: Icons.mark_email_unread_outlined,
                    color: AppColors.info,
                    message: 'Account created! Check your inbox and click the confirmation link.',
                  ),
                if (isAlreadyRegistered)
                  _InfoBanner(
                    icon: Icons.person_outline,
                    color: AppColors.warning,
                    message: 'This email is already registered.',
                    trailing: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Sign in instead',
                          style: TextStyle(color: context.accent, fontWeight: FontWeight.w700)),
                    ),
                  ),
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(errorText, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ),

                const SizedBox(height: AppSpacing.xxxl),

                AppButton(
                  label: _phoneCtrl.text.trim().isNotEmpty ? 'Send Verification Code' : 'Create Account',
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _submit,
                ),

                const SizedBox(height: AppSpacing.xxl),

                // Sign in link
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: 'Already have an account? ',
                          style: TextStyle(color: context.textMuted, fontSize: 14)),
                      TextSpan(text: 'Sign In',
                          style: TextStyle(color: context.accent, fontSize: 14, fontWeight: FontWeight.w700)),
                    ])),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Phone field with country code
// ═══════════════════════════════════════════════════════════════════════════════

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String countryCode;
  final ValueChanged<String> onCountryCodeChanged;

  const _PhoneField({
    required this.controller,
    required this.countryCode,
    required this.onCountryCodeChanged,
  });

  static const _codes = ['+90', '+1', '+44', '+49', '+33', '+81', '+82', '+61', '+55', '+91'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Phone Number', style: TextStyle(color: context.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            // Country code selector
            GestureDetector(
              onTap: () => _showCodePicker(context),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.borderColor, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(countryCode, style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, color: context.textMuted, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Phone input
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: context.textPrimary, fontSize: 15),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                decoration: InputDecoration(
                  hintText: '5XX XXX XX XX',
                  hintStyle: TextStyle(color: context.textDisabled),
                  filled: true,
                  fillColor: context.surfaceColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.borderColor, width: 0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.borderColor, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.accent, width: 1.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showCodePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: _codes.map((code) => ListTile(
          title: Text(code, style: TextStyle(color: context.textPrimary, fontSize: 16)),
          trailing: code == countryCode
              ? Icon(Icons.check_rounded, color: context.accent, size: 20)
              : null,
          onTap: () {
            onCountryCodeChanged(code);
            Navigator.pop(context);
          },
        )).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Info banner
// ═══════════════════════════════════════════════════════════════════════════════

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
          Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
