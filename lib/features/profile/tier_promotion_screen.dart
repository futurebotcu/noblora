import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/post.dart';

class TierPromotionScreen extends StatefulWidget {
  final NobTier newTier;
  const TierPromotionScreen({super.key, required this.newTier});

  @override
  State<TierPromotionScreen> createState() => _TierPromotionScreenState();
}

class _TierPromotionScreenState extends State<TierPromotionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6)));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNoble = widget.newTier == NobTier.noble;
    final color = isNoble ? AppColors.emerald500 : AppColors.info;
    final icon = isNoble ? Icons.workspace_premium_rounded : Icons.explore_rounded;
    final title = isNoble ? 'You\'re now Noble' : 'You\'ve reached Explorer';
    final subtitle = isNoble
        ? 'You\'re in the top 10% of Noblara.\nYour consistency speaks for itself.'
        : 'Your profile is growing.\nKeep engaging to reach Noble.';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => Opacity(
            opacity: _fade.value,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: _scale.value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.1),
                        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
                      ),
                      child: Icon(icon, color: color, size: 48),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textMuted,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xxxxl),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: AppColors.bg,
                      minimumSize: const Size(200, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
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
