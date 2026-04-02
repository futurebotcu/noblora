import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/mock_mode.dart';
import '../../providers/auth_provider.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phone;
  final String email;
  final String password;

  const OtpVerificationScreen({
    super.key,
    required this.phone,
    required this.email,
    required this.password,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpState();
}

class _OtpState extends ConsumerState<OtpVerificationScreen> {
  final List<TextEditingController> _ctrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focuses = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String? _error;
  int _resendSeconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    for (final c in _ctrls) { c.dispose(); }
    for (final f in _focuses) { f.dispose(); }
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendSeconds = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        t.cancel();
      }
    });
  }

  String get _otp => _ctrls.map((c) => c.text).join();

  Future<void> _verify() async {
    final otp = _otp;
    if (otp.length != 6) return;

    setState(() { _loading = true; _error = null; });

    try {
      if (!isMockMode) {
        await Supabase.instance.client.auth.verifyOTP(
          phone: widget.phone,
          token: otp,
          type: OtpType.sms,
        );
      }

      // Now sign up with email+password to create the full account
      await ref.read(authProvider.notifier).signUp(widget.email, widget.password);

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Invalid code. Please try again.';
      });
    }
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0) return;
    try {
      if (!isMockMode) {
        await Supabase.instance.client.auth.signInWithOtp(phone: widget.phone);
      }
      _startResendTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Code resent'), backgroundColor: context.accent));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resend: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focuses[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focuses[index - 1].requestFocus();
    }
    // Auto-verify when all 6 digits entered
    if (_otp.length == 6) {
      _verify();
    }
  }

  @override
  Widget build(BuildContext context) {
    final masked = widget.phone.replaceRange(
      widget.phone.length > 4 ? widget.phone.length - 4 : 0,
      widget.phone.length > 4 ? widget.phone.length - 2 : 0,
      '••',
    );

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xxxl),
              Text('Verify your number',
                  style: TextStyle(color: context.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              Text('We sent a code to $masked',
                  style: TextStyle(color: context.textMuted, fontSize: 14)),
              const SizedBox(height: AppSpacing.xxxxl),

              // OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) => Container(
                  width: 48, height: 56,
                  margin: EdgeInsets.only(left: i > 0 ? 8 : 0),
                  child: TextField(
                    controller: _ctrls[i],
                    focusNode: _focuses[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: context.surfaceColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.accent, width: 2),
                      ),
                    ),
                    onChanged: (v) => _onDigitChanged(i, v),
                  ),
                )),
              ),

              if (_error != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(_error!, textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ],

              const SizedBox(height: AppSpacing.xxl),

              // Resend
              Center(
                child: TextButton(
                  onPressed: _resendSeconds > 0 ? null : _resend,
                  child: Text(
                    _resendSeconds > 0 ? 'Resend code (${_resendSeconds}s)' : 'Resend code',
                    style: TextStyle(
                      color: _resendSeconds > 0 ? context.textDisabled : context.accent,
                      fontSize: 14, fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Verify button
              ElevatedButton(
                onPressed: (_loading || _otp.length != 6) ? null : _verify,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: _loading
                    ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(
                        strokeWidth: 2, color: context.onAccent))
                    : const Text('Verify', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}
