import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/mock_mode.dart';
import '../../providers/auth_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 3-Step Sign Up Flow
// Step 1: Choose method (email / phone) → enter details
// Step 2: OTP verification (phone only)
// Step 3: Create password
// ═══════════════════════════════════════════════════════════════════════════════

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});
  @override
  ConsumerState<SignUpScreen> createState() => _SignUpState();
}

class _SignUpState extends ConsumerState<SignUpScreen> {
  int _step = 0; // 0=method, 1=otp, 2=password
  String? _method; // 'email' | 'phone'
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  _CountryEntry _country = _countries.first;
  bool _loading = false;
  String? _error;

  // OTP
  final List<TextEditingController> _otpCtrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocuses = List.generate(6, (_) => FocusNode());
  int _resendSeconds = 0;
  Timer? _resendTimer;

  // Password visibility
  bool _showPass = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    for (final c in _otpCtrls) { c.dispose(); }
    for (final f in _otpFocuses) { f.dispose(); }
    _resendTimer?.cancel();
    super.dispose();
  }

  String get _fullPhone => '${_country.code}${_phoneCtrl.text.trim().replaceAll(' ', '')}';
  String get _otp => _otpCtrls.map((c) => c.text).join();

  // ── Step 1 actions ──

  Future<void> _sendEmailVerification() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    // Email path skips OTP, goes directly to password
    setState(() { _error = null; _step = 2; });
  }

  Future<void> _sendPhoneOtp() async {
    final phone = _phoneCtrl.text.trim().replaceAll(' ', '');
    if (phone.length < 7) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      if (!isMockMode) {
        await Supabase.instance.client.auth.signInWithOtp(phone: _fullPhone);
      }
      _startResendTimer();
      setState(() { _loading = false; _step = 1; });
    } catch (e) {
      setState(() { _loading = false; _error = 'Failed to send code. Try again.'; });
    }
  }

  // ── Step 2 actions (OTP) ──

  void _startResendTimer() {
    _resendSeconds = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        t.cancel();
      }
    });
  }

  void _onOtpDigit(int i, String v) {
    if (v.length == 1 && i < 5) { _otpFocuses[i + 1].requestFocus(); }
    if (v.isEmpty && i > 0) { _otpFocuses[i - 1].requestFocus(); }
    if (_otp.length == 6) { _verifyOtp(); }
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != 6) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (!isMockMode) {
        await Supabase.instance.client.auth.verifyOTP(
          phone: _fullPhone, token: _otp, type: OtpType.sms);
      }
      setState(() { _loading = false; _step = 2; });
    } catch (_) {
      setState(() { _loading = false; _error = 'Invalid code. Try again.'; });
    }
  }

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0) return;
    try {
      if (!isMockMode) {
        await Supabase.instance.client.auth.signInWithOtp(phone: _fullPhone);
      }
      _startResendTimer();
    } catch (_) {}
  }

  // ── Step 3 actions (Password) ──

  bool get _passHas8 => _passCtrl.text.length >= 8;
  bool get _passMatch => _passCtrl.text == _confirmCtrl.text && _confirmCtrl.text.isNotEmpty;

  Future<void> _createAccount() async {
    if (!_passHas8) { setState(() => _error = 'Password must be 8+ characters'); return; }
    if (!_passMatch) { setState(() => _error = 'Passwords do not match'); return; }

    setState(() { _loading = true; _error = null; });

    final email = _method == 'email' ? _emailCtrl.text.trim() : '${_phoneCtrl.text.trim()}@phone.noblara.com';
    await ref.read(authProvider.notifier).signUp(email, _passCtrl.text);

    final auth = ref.read(authProvider);
    if (auth.isAuthenticated && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (auth.error != null) {
      setState(() { _loading = false; _error = auth.error; });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (prev, next) {
      if (next.isAuthenticated && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: () {
            if (_step > 0 && _method != null) {
              setState(() { _step = _step == 2 && _method == 'phone' ? 1 : 0; _error = null; });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text('Create Account', style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) => Container(
                  width: i == _step ? 24 : 8, height: 8,
                  margin: EdgeInsets.only(left: i > 0 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: i == _step ? context.accent : context.borderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
            ),

            // Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _step == 0
                    ? _buildStep1(context)
                    : _step == 1
                        ? _buildStep2(context)
                        : _buildStep3(context),
              ),
            ),

            // Sign in link
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: 'Already have an account? ', style: TextStyle(color: context.textMuted, fontSize: 14)),
                  TextSpan(text: 'Sign In', style: TextStyle(color: context.accent, fontSize: 14, fontWeight: FontWeight.w700)),
                ])),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Step 1 — Choose method
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep1(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('step1'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Text('Join Noblara', style: TextStyle(color: context.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Text('Choose how you want to sign up', style: TextStyle(color: context.textMuted, fontSize: 14)),
          const SizedBox(height: AppSpacing.xxxl),

          if (_method == null) ...[
            // Method cards
            _MethodCard(
              icon: Icons.email_outlined,
              label: 'Continue with Email',
              onTap: () => setState(() => _method = 'email'),
            ),
            const SizedBox(height: AppSpacing.md),
            _MethodCard(
              icon: Icons.phone_outlined,
              label: 'Continue with Phone',
              onTap: () => setState(() => _method = 'phone'),
            ),
          ],

          if (_method == 'email') ...[
            _buildEmailInput(context),
            const SizedBox(height: AppSpacing.xxl),
            if (_error != null) _ErrorText(_error!),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _loading ? null : _sendEmailVerification,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: _loading
                  ? _Spinner(color: context.onAccent)
                  : const Text('Continue', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ],

          if (_method == 'phone') ...[
            _buildPhoneInput(context),
            const SizedBox(height: AppSpacing.xxl),
            if (_error != null) _ErrorText(_error!),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _loading ? null : _sendPhoneOtp,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: _loading
                  ? _Spinner(color: context.onAccent)
                  : const Text('Send Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ],

          if (_method != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Center(child: TextButton(
              onPressed: () => setState(() { _method = null; _error = null; }),
              child: Text('Choose different method', style: TextStyle(color: context.textMuted, fontSize: 13)),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildEmailInput(BuildContext context) {
    return TextField(
      controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(color: context.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: 'Email',
        hintText: 'you@example.com',
        prefixIcon: Icon(Icons.email_outlined, color: context.textMuted, size: 20),
      ),
    );
  }

  Widget _buildPhoneInput(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => _showCountryPicker(context),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.surfaceAltColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_country.flag, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Text(_country.code, style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_rounded, color: context.textMuted, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            decoration: const InputDecoration(hintText: '5XX XXX XX XX'),
          ),
        ),
      ],
    );
  }

  void _showCountryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scroll) => _CountryPickerSheet(
          scrollController: scroll,
          selected: _country,
          onSelected: (c) {
            setState(() => _country = c);
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Step 2 — OTP
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep2(BuildContext context) {
    return Padding(
      key: const ValueKey('step2'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Text('Enter the code', style: TextStyle(color: context.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Text('Sent to $_fullPhone', style: TextStyle(color: context.textMuted, fontSize: 14)),
          const SizedBox(height: AppSpacing.xxxxl),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) => Container(
              width: 48, height: 56,
              margin: EdgeInsets.only(left: i > 0 ? 8 : 0),
              child: TextField(
                controller: _otpCtrls[i],
                focusNode: _otpFocuses[i],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.accent, width: 2),
                  ),
                ),
                onChanged: (v) => _onOtpDigit(i, v),
              ),
            )),
          ),

          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _ErrorText(_error!),
          ],

          const SizedBox(height: AppSpacing.xxl),
          Center(child: TextButton(
            onPressed: _resendSeconds > 0 ? null : _resendOtp,
            child: Text(
              _resendSeconds > 0 ? 'Resend code (${_resendSeconds}s)' : 'Resend code',
              style: TextStyle(color: _resendSeconds > 0 ? context.textDisabled : context.accent, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          )),

          const Spacer(),
          ElevatedButton(
            onPressed: (_loading || _otp.length != 6) ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _loading
                ? _Spinner(color: context.onAccent)
                : const Text('Verify', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Step 3 — Password
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep3(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('step3'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Text('Create your password', style: TextStyle(color: context.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Text('Secure your account', style: TextStyle(color: context.textMuted, fontSize: 14)),
          const SizedBox(height: AppSpacing.xxxl),

          TextField(
            controller: _passCtrl,
            obscureText: !_showPass,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: context.textMuted),
                onPressed: () => setState(() => _showPass = !_showPass),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          TextField(
            controller: _confirmCtrl,
            obscureText: !_showConfirm,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: context.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              suffixIcon: IconButton(
                icon: Icon(_showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: context.textMuted),
                onPressed: () => setState(() => _showConfirm = !_showConfirm),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Requirements checklist
          _Check(label: '8+ characters', met: _passHas8),
          const SizedBox(height: AppSpacing.sm),
          _Check(label: 'Passwords match', met: _passMatch),

          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _ErrorText(_error!),
          ],

          const SizedBox(height: AppSpacing.xxxl),
          ElevatedButton(
            onPressed: (_loading || !_passHas8 || !_passMatch) ? null : _createAccount,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _loading
                ? _Spinner(color: context.onAccent)
                : const Text('Create Account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Method card
// ═══════════════════════════════════════════════════════════════════════════════

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MethodCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor, width: 0.5),
        ),
        child: Row(children: [
          Icon(icon, color: context.accent, size: 24),
          const SizedBox(width: AppSpacing.lg),
          Text(label, style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, color: context.textMuted, size: 22),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Password check
// ═══════════════════════════════════════════════════════════════════════════════

class _Check extends StatelessWidget {
  final String label;
  final bool met;
  const _Check({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(met ? Icons.check_circle_rounded : Icons.circle_outlined,
          color: met ? AppColors.success : context.textDisabled, size: 18),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: met ? AppColors.success : context.textMuted, fontSize: 13)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Error text
// ═══════════════════════════════════════════════════════════════════════════════

class _ErrorText extends StatelessWidget {
  final String text;
  const _ErrorText(this.text);
  @override
  Widget build(BuildContext context) => Text(text, textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.error, fontSize: 13));
}

// ═══════════════════════════════════════════════════════════════════════════════
// Spinner
// ═══════════════════════════════════════════════════════════════════════════════

class _Spinner extends StatelessWidget {
  final Color color;
  const _Spinner({required this.color});
  @override
  Widget build(BuildContext context) => SizedBox(width: 22, height: 22,
      child: CircularProgressIndicator(strokeWidth: 2, color: color));
}

// ═══════════════════════════════════════════════════════════════════════════════
// Country picker
// ═══════════════════════════════════════════════════════════════════════════════

class _CountryEntry {
  final String flag;
  final String name;
  final String code;
  const _CountryEntry(this.flag, this.name, this.code);
}

const _countries = [
  _CountryEntry('🇹🇷', 'Turkey', '+90'),
  _CountryEntry('🇬🇧', 'United Kingdom', '+44'),
  _CountryEntry('🇩🇪', 'Germany', '+49'),
  _CountryEntry('🇺🇸', 'United States', '+1'),
  _CountryEntry('🇫🇷', 'France', '+33'),
  _CountryEntry('🇳🇱', 'Netherlands', '+31'),
  _CountryEntry('🇧🇪', 'Belgium', '+32'),
  _CountryEntry('🇦🇹', 'Austria', '+43'),
  _CountryEntry('🇨🇭', 'Switzerland', '+41'),
  _CountryEntry('🇸🇪', 'Sweden', '+46'),
  _CountryEntry('🇳🇴', 'Norway', '+47'),
  _CountryEntry('🇩🇰', 'Denmark', '+45'),
  _CountryEntry('🇫🇮', 'Finland', '+358'),
  _CountryEntry('🇦🇺', 'Australia', '+61'),
  _CountryEntry('🇨🇦', 'Canada', '+1'),
  _CountryEntry('🇯🇵', 'Japan', '+81'),
  _CountryEntry('🇰🇷', 'South Korea', '+82'),
  _CountryEntry('🇸🇬', 'Singapore', '+65'),
  _CountryEntry('🇦🇪', 'UAE', '+971'),
  _CountryEntry('🇸🇦', 'Saudi Arabia', '+966'),
  _CountryEntry('🇶🇦', 'Qatar', '+974'),
  _CountryEntry('🇰🇼', 'Kuwait', '+965'),
  _CountryEntry('🇧🇭', 'Bahrain', '+973'),
  _CountryEntry('🇦🇿', 'Azerbaijan', '+994'),
  _CountryEntry('🇬🇪', 'Georgia', '+995'),
  _CountryEntry('🇷🇺', 'Russia', '+7'),
  _CountryEntry('🇺🇦', 'Ukraine', '+380'),
  _CountryEntry('🇵🇱', 'Poland', '+48'),
  _CountryEntry('🇨🇿', 'Czech Republic', '+420'),
  _CountryEntry('🇷🇴', 'Romania', '+40'),
  _CountryEntry('🇬🇷', 'Greece', '+30'),
  _CountryEntry('🇮🇹', 'Italy', '+39'),
  _CountryEntry('🇪🇸', 'Spain', '+34'),
  _CountryEntry('🇵🇹', 'Portugal', '+351'),
];

class _CountryPickerSheet extends StatefulWidget {
  final ScrollController scrollController;
  final _CountryEntry selected;
  final ValueChanged<_CountryEntry> onSelected;
  const _CountryPickerSheet({required this.scrollController, required this.selected, required this.onSelected});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  List<_CountryEntry> get _filtered {
    if (_query.isEmpty) return _countries;
    final q = _query.toLowerCase();
    return _countries.where((c) => c.name.toLowerCase().contains(q) || c.code.contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.lg),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: TextStyle(color: context.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search country or code...',
              prefixIcon: Icon(Icons.search_rounded, color: context.textMuted, size: 20),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final c = _filtered[i];
              final sel = c.code == widget.selected.code && c.name == widget.selected.name;
              return ListTile(
                leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                title: Text(c.name, style: TextStyle(color: context.textPrimary, fontSize: 14)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.code, style: TextStyle(color: context.textMuted, fontSize: 14)),
                    if (sel) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check_rounded, color: context.accent, size: 18),
                    ],
                  ],
                ),
                onTap: () => widget.onSelected(c),
              );
            },
          ),
        ),
      ],
    );
  }
}
