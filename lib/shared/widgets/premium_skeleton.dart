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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1 + 2 * _ctrl.value, 0),
            end: Alignment(-1 + 2 * _ctrl.value + 1, 0),
            colors: [
              context.shimmerBase,
              context.shimmerHighlight,
              context.shimmerBase,
            ],
          ),
        ),
      ),
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
