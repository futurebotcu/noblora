import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';

/// Premium skeleton loading card — obsidian shimmer effect
class PremiumSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const PremiumSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 200,
    this.radius = 20,
  });

  @override
  State<PremiumSkeleton> createState() => _PremiumSkeletonState();
}

class _PremiumSkeletonState extends State<PremiumSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final v = _anim.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + 3.0 * v, 0),
              end: Alignment(-0.5 + 3.0 * v, 0),
              stops: const [0.0, 0.4, 0.6, 1.0],
              colors: [
                context.shimmerBase,
                context.shimmerHighlight,
                context.shimmerHighlight,
                context.shimmerBase,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Premium skeleton list — multiple cards
class PremiumSkeletonList extends StatelessWidget {
  final int count;
  final double cardHeight;

  const PremiumSkeletonList({super.key, this.count = 3, this.cardHeight = 140});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: List.generate(count, (i) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: PremiumSkeleton(height: cardHeight, radius: AppSpacing.radiusLg),
        )),
      ),
    );
  }
}
