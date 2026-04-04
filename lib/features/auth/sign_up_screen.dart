import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/premium.dart';
import '../../core/utils/mock_mode.dart';
import '../../core/services/device_service.dart';
import '../../providers/auth_provider.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});
  @override
  ConsumerState<SignUpScreen> createState() => _SignUpState();
}

class _SignUpState extends ConsumerState<SignUpScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showPass = false;
  bool _showConfirm = false;
  bool _loading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _has8 => _passCtrl.text.length >= 8;
  bool get _hasUpper => _passCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber => _passCtrl.text.contains(RegExp(r'[0-9]'));
  bool get _passMatch => _passCtrl.text == _confirmCtrl.text && _confirmCtrl.text.isNotEmpty;
  bool get _allValid => _has8 && _hasUpper && _hasNumber && _passMatch;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_allValid) return;

    setState(() => _loading = true);

    // Device security checks
    if (!isMockMode) {
      final banned = await DeviceService.isDeviceBanned();
      if (banned && mounted) {
        setState(() => _loading = false);
        _showBlockDialog('Access Restricted', 'This device cannot create new accounts.');
        return;
      }

      final hasAccount = await DeviceService.deviceHasAccount();
      if (hasAccount && mounted) {
        setState(() => _loading = false);
        final proceed = await _showAccountExistsDialog();
        if (proceed != true) return;
        setState(() => _loading = true);
      }
    }

    // Sign up
    await ref.read(authProvider.notifier).signUp(
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );

    final auth = ref.read(authProvider);

    if (auth.isAuthenticated) {
      // Immediate login (no email confirmation)
      if (!isMockMode) {
        DeviceService.registerDevice(auth.userId!);
      }
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    if (auth.needsEmailConfirmation) {
      setState(() { _loading = false; _emailSent = true; });
      return;
    }

    setState(() => _loading = false);
  }

  void _showBlockDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(title, style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text(message, style: TextStyle(color: context.textMuted, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: TextStyle(color: context.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showAccountExistsDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Account Exists', style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text('An account from this device already exists. Sign in instead?',
            style: TextStyle(color: context.textMuted, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx, false); Navigator.pop(context); },
            child: Text('Sign In', style: TextStyle(color: context.accent, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Continue Anyway', style: TextStyle(color: context.textMuted)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (prev, next) {
      if (next.isAuthenticated && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    final auth = ref.watch(authProvider);
    final isAlreadyRegistered = auth.error == 'already_registered';

    if (_emailSent) return _buildEmailSent(context);

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Create Account', style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                Text('Join Noblara', style: TextStyle(color: context.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.sm),
                Text('Where elegance meets connection.', style: TextStyle(color: context.textMuted, fontSize: 14)),
                const SizedBox(height: AppSpacing.xxxl),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: context.textPrimary, fontSize: 15),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email required';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim())) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Password
                TextFormField(
                  controller: _passCtrl,
                  obscureText: !_showPass,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: context.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: context.textMuted),
                      onPressed: () => setState(() => _showPass = !_showPass),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Confirm password
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: !_showConfirm,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: context.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: context.textMuted),
                      onPressed: () => setState(() => _showConfirm = !_showConfirm),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Password requirements
                _Req('At least 8 characters', _has8),
                const SizedBox(height: AppSpacing.xs),
                _Req('One uppercase letter', _hasUpper),
                const SizedBox(height: AppSpacing.xs),
                _Req('One number', _hasNumber),
                const SizedBox(height: AppSpacing.xs),
                _Req('Passwords match', _passMatch),

                // Already registered
                if (isAlreadyRegistered) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.20), width: 0.5),
                      boxShadow: Premium.shadowSm,
                    ),
                    child: Row(children: [
                      const Icon(Icons.person_outline, color: AppColors.warning, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text('This email is already registered.',
                          style: TextStyle(color: AppColors.warning, fontSize: 13))),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Sign In', style: TextStyle(color: context.accent, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ]),
                  ),
                ],

                // Generic error
                if (auth.error != null && !isAlreadyRegistered) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(auth.error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],

                const SizedBox(height: AppSpacing.xxxl),

                // Create Account button
                ElevatedButton(
                  onPressed: (_loading || !_allValid) ? null : _submit,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: _loading
                      ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: context.onAccent))
                      : const Text('Create Account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // Sign in link
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: 'Already have an account? ', style: TextStyle(color: context.textMuted, fontSize: 14)),
                      const TextSpan(text: 'Sign In', style: TextStyle(color: AppColors.emerald500, fontSize: 14, fontWeight: FontWeight.w700)),
                    ])),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailSent(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [context.accent.withValues(alpha: 0.12), context.accent.withValues(alpha: 0.04)],
                  ),
                  border: Border.all(color: context.accent.withValues(alpha: 0.20), width: 0.5),
                  boxShadow: Premium.emeraldGlow(intensity: 0.6),
                ),
                child: Icon(Icons.mark_email_read_outlined, color: context.accent, size: 36),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Check your email', style: TextStyle(color: context.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.md),
              Text('We sent a verification link to', style: TextStyle(color: context.textMuted, fontSize: 14)),
              const SizedBox(height: 4),
              Text(_emailCtrl.text.trim(), style: TextStyle(color: context.accent, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.xxxxl),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: const Text('Back to Sign In', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Req extends StatelessWidget {
  final String label;
  final bool met;
  const _Req(this.label, this.met);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(met ? Icons.check_circle_rounded : Icons.circle_outlined,
          color: met ? AppColors.success : context.textDisabled, size: 16),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: met ? AppColors.success : context.textMuted, fontSize: 13)),
    ]);
  }
}
