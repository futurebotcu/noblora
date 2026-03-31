import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/match.dart';
import '../../data/models/video_session.dart';
import 'video_call_screen.dart';

const _prefsKey = 'short_intro_rules_seen';

class ShortIntroRulesScreen extends StatefulWidget {
  final NobleMatch match;
  final VideoSession session;

  const ShortIntroRulesScreen({
    super.key,
    required this.match,
    required this.session,
  });

  /// Checks prefs and pushes either this screen or VideoCallScreen directly.
  static Future<void> launchCall(
    BuildContext context, {
    required NobleMatch match,
    required VideoSession session,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_prefsKey) ?? false;
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => seen
            ? VideoCallScreen(match: match, session: session)
            : ShortIntroRulesScreen(match: match, session: session),
      ),
    );
  }

  @override
  State<ShortIntroRulesScreen> createState() => _ShortIntroRulesScreenState();
}

class _ShortIntroRulesScreenState extends State<ShortIntroRulesScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _onReady() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          match: widget.match,
          session: widget.session,
        ),
      ),
    );
  }

  void _onRemindNext() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          match: widget.match,
          session: widget.session,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.xxxl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.gold,
                    size: 40,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Before you connect',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'A few things to keep in mind',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  ..._rules.map((r) => _RuleCard(rule: r)),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Both of you are seeing this right now',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.bg,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      onPressed: _onReady,
                      child: const Text(
                        "I'm ready",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: _onRemindNext,
                    style:
                        TextButton.styleFrom(foregroundColor: AppColors.textMuted),
                    child: const Text('Remind me next time'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Rule data ───────────────────────────────────────────────────────────────

class _Rule {
  final IconData icon;
  final String text;
  const _Rule(this.icon, this.text);
}

const _rules = [
  _Rule(Icons.mic_rounded, 'First minute is audio only — just voices, no pressure'),
  _Rule(Icons.videocam_rounded, 'Video starts automatically after 1 minute'),
  _Rule(Icons.timer_rounded, 'You have 5 minutes — make it count'),
  _Rule(Icons.lock_rounded, 'This call is private — no recording, no sharing'),
  _Rule(Icons.auto_awesome_rounded, "Be yourself — that's the whole point"),
];

// ─── Rule card widget ────────────────────────────────────────────────────────

class _RuleCard extends StatelessWidget {
  final _Rule rule;
  const _RuleCard({required this.rule});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(rule.icon, color: AppColors.gold, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                rule.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
