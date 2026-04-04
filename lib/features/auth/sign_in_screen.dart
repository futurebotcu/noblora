import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/premium.dart';
import '../../core/utils/mock_mode.dart';
import '../../core/services/device_service.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _deviceError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Device ban check
    if (!isMockMode) {
      final banned = await DeviceService.isDeviceBanned();
      if (banned && mounted) {
        setState(() => _deviceError = 'This device has been restricted. Contact support.');
        return;
      }
    }

    setState(() => _deviceError = null);
    await ref.read(authProvider.notifier).signIn(
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );

    // Register device on success
    final auth = ref.read(authProvider);
    if (auth.isAuthenticated && !isMockMode) {
      DeviceService.registerDevice(auth.userId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (prev, next) {
      if (next.isAuthenticated && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    final auth = ref.watch(authProvider);
    final error = _deviceError ?? auth.error;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: context.textPrimary,
        title: Text('Sign In', style: TextStyle(color: context.textPrimary)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxxl),
                Text('Welcome back', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: context.textPrimary)),
                const SizedBox(height: AppSpacing.xxl),
                AppTextField(
                  controller: _emailCtrl,
                  label: 'Email',
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Email required' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _passCtrl,
                  label: 'Password',
                  hint: '••••••••',
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      // Forgot password — could trigger reset flow
                    },
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: AppColors.emerald500,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(error, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],
                const SizedBox(height: AppSpacing.xxxl),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    boxShadow: auth.isLoading ? null : Premium.emeraldGlow(intensity: 0.6),
                  ),
                  child: AppButton(
                    label: 'Sign In',
                    isLoading: auth.isLoading,
                    onPressed: auth.isLoading ? null : _submit,
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
