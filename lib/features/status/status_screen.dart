import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/post.dart';
import '../../data/models/profile.dart';
import '../../providers/profile_provider.dart';
import '../../shared/widgets/tier_badge.dart';
import '../../services/gemini_service.dart';

class StatusScreen extends ConsumerStatefulWidget {
  const StatusScreen({super.key});

  @override
  ConsumerState<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends ConsumerState<StatusScreen> {
  bool _animate = false;
  String? _aiExplanation;
  bool _loadingAi = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _animate = true);
    });
  }

  Future<void> _loadAi(Profile p) async {
    if (_loadingAi || _aiExplanation != null) return;
    setState(() => _loadingAi = true);
    try {
      _aiExplanation = await GeminiService.getTierExplanation(
        tier: p.nobTier.name,
        profileCompleteness: p.profileCompletenessScore,
        communityScore: p.communityScore,
        depthScore: p.depthScore,
        followThrough: p.followThroughScore,
      );
    } catch (_) {
      _aiExplanation = 'Keep engaging — your profile grows with every interaction.';
    }
    if (mounted) setState(() => _loadingAi = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(profileProvider).profile;
    if (p == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(backgroundColor: AppColors.bg, surfaceTintColor: Colors.transparent,
            title: const Text('Status', style: TextStyle(color: AppColors.textPrimary))),
        body: const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    if (_aiExplanation == null && !_loadingAi) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAi(p));
    }

    final tierColor = switch (p.nobTier) {
      NobTier.noble => AppColors.gold,
      NobTier.explorer => const Color(0xFF26C6DA),
      NobTier.observer => AppColors.textMuted,
    };

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.bg, surfaceTintColor: Colors.transparent,
          title: const Text('Your Status', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          // Tier badge + label
          Center(child: TierBadge(tier: p.nobTier, size: 56)),
          const SizedBox(height: AppSpacing.lg),
          Center(child: Text(p.nobTier.label, style: TextStyle(color: tierColor, fontSize: 24, fontWeight: FontWeight.w700))),
          const SizedBox(height: AppSpacing.xs),
          Center(child: Text('Profile Strength: ${p.strengthLabel}', style: TextStyle(color: AppColors.textMuted, fontSize: 14))),
          const SizedBox(height: AppSpacing.xxl),

          // Strength bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _animate ? (p.maturityScore / 100).clamp(0, 1) : 0),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 8,
                  backgroundColor: AppColors.surfaceAlt, valueColor: AlwaysStoppedAnimation(tierColor)),
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),

          // Component bars (qualitative — no raw numbers)
          _Bar('Profile', p.profileCompletenessScore / 100, tierColor, _animate),
          _Bar('Community', p.communityScore / 100, tierColor, _animate),
          _Bar('Depth', p.depthScore / 100, tierColor, _animate),
          _Bar('Trust', p.trustScore / 100, tierColor, _animate),
          _Bar('Follow-through', p.followThroughScore / 100, tierColor, _animate),
          _Bar('Activity', p.vitalityScore / 100, tierColor, _animate),
          const SizedBox(height: AppSpacing.xxxl),

          // AI explanation
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: tierColor.withValues(alpha: 0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.auto_awesome_rounded, color: tierColor, size: 16),
                const SizedBox(width: AppSpacing.sm),
                Text('Noblara Guide', style: TextStyle(color: tierColor, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: AppSpacing.md),
              if (_loadingAi)
                const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)))
              else
                Text(_aiExplanation ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
            ]),
          ),
          const SizedBox(height: AppSpacing.xxxl),

          // Tips
          if (p.profileTips.isNotEmpty) ...[
            const Text('Tips', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            ...p.profileTips.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.lightbulb_outline_rounded, color: AppColors.gold, size: 16),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(t, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4))),
              ]),
            )),
          ],
          const SizedBox(height: AppSpacing.xxxxl),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label; final double value; final Color color; final bool animate;
  const _Bar(this.label, this.value, this.color, this.animate);

  String get _q {
    if (value >= 0.8) return 'Strong';
    if (value >= 0.5) return 'Good';
    if (value >= 0.2) return 'Growing';
    return 'New';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const Spacer(),
          Text(_q, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: animate ? value.clamp(0, 1) : 0),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 4,
                backgroundColor: AppColors.surfaceAlt, valueColor: AlwaysStoppedAnimation(color)),
          ),
        ),
      ]),
    );
  }
}
