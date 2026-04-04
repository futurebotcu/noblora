import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

enum AppButtonVariant { primary, outline, ghost }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isLoading || widget.onPressed == null) return;
    HapticFeedback.lightImpact();
    widget.onPressed!();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.isLoading || widget.onPressed == null) return;
    _scaleCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) => _scaleCtrl.reverse();
  void _onTapCancel() => _scaleCtrl.reverse();

  @override
  Widget build(BuildContext context) {
    final child = widget.isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.bg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(widget.label),
            ],
          );

    final button = switch (widget.variant) {
      AppButtonVariant.primary => ElevatedButton(
          onPressed: widget.isLoading ? null : _handleTap,
          child: child,
        ),
      AppButtonVariant.outline => OutlinedButton(
          onPressed: widget.isLoading ? null : _handleTap,
          child: child,
        ),
      AppButtonVariant.ghost => TextButton(
          onPressed: widget.isLoading ? null : _handleTap,
          child: child,
        ),
    };

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(scale: _scale, child: button),
    );
  }
}
