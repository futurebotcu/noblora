import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/mock_mode.dart';
import '../../providers/auth_provider.dart';

class EntryGateScreen extends ConsumerStatefulWidget {
  const EntryGateScreen({super.key});

  @override
  ConsumerState<EntryGateScreen> createState() => _EntryGateScreenState();
}

class _EntryGateScreenState extends ConsumerState<EntryGateScreen> {
  final _codeCtrl = TextEditingController();
  bool _submitting = false;
  String? _feedback;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _submitting = true;
      _feedback = null;
    });

    try {
      if (!isMockMode) {
        final userId = ref.read(authProvider).userId;
        if (userId != null) {
          await Supabase.instance.client
              .from('gating_status')
              .update({'entry_message': code})
              .eq('user_id', userId);
        }
      }
      if (!mounted) return;
      setState(() {
        _feedback = 'Code submitted. We will review it shortly.';
        _codeCtrl.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _feedback = 'Could not submit. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        actions: [
          TextButton.icon(
            icon: Icon(Icons.logout, size: 16, color: context.textMuted),
            label: Text('Sign Out',
                style: TextStyle(color: context.textMuted, fontSize: 12)),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  color: context.accent,
                  size: 72,
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Access Pending',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: context.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Your application is under review.\n'
                  'You will be notified once approved.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: context.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxxl),
                // Pulse indicator
                const _WaitingPulse(),
                const SizedBox(height: AppSpacing.xxxl),
                // Referral code input
                Text(
                  'Have a referral code?',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.textMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeCtrl,
                        style: TextStyle(color: context.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Enter referral code',
                          hintStyle: TextStyle(
                              color: context.textDisabled),
                          filled: true,
                          fillColor: context.surfaceColor,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                            borderSide:
                                BorderSide(color: context.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                            borderSide:
                                BorderSide(color: context.borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                            borderSide:
                                BorderSide(color: context.accent),
                          ),
                        ),
                        onSubmitted: (_) => _submitCode(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _submitting
                        ? SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              color: context.accent,
                              strokeWidth: 2,
                            ),
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.accent,
                              foregroundColor: AppColors.textOnEmerald,
                              minimumSize: const Size(60, 44),
                            ),
                            onPressed: _submitCode,
                            child: const Text('Send'),
                          ),
                  ],
                ),
                if (_feedback != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _feedback!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _feedback!.startsWith('Could')
                            ? AppColors.error
                            : AppColors.emerald500),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  'This screen updates automatically\nwhen your access is granted.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.textMuted),
                  textAlign: TextAlign.center,
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
// Subtle animated pulse — reassures user that the app is live-listening
// ---------------------------------------------------------------------------

class _WaitingPulse extends StatefulWidget {
  const _WaitingPulse();

  @override
  State<_WaitingPulse> createState() => _WaitingPulseState();
}

class _WaitingPulseState extends State<_WaitingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.emerald500,
        ),
      ),
    );
  }
}
