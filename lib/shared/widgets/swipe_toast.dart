import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum ToastType { signal, match, message, event, system, success, error }

class SwipeToast extends StatefulWidget {
  final String message;
  final ToastType type;
  final Duration duration;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  const SwipeToast({
    super.key,
    required this.message,
    this.type = ToastType.system,
    this.duration = const Duration(seconds: 4),
    this.onTap,
    required this.onDismiss,
  });

  @override
  State<SwipeToast> createState() => _SwipeToastState();
}

class _SwipeToastState extends State<SwipeToast> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideIn;
  late Animation<double> _fadeIn;
  double _dragX = 0;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slideIn = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    _startAutoTimer();
  }

  void _startAutoTimer() {
    _autoTimer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    _autoTimer?.cancel();
    if (!mounted) return;
    await _ctrl.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Color get _dotColor => switch (widget.type) {
    ToastType.signal => AppColors.gold,
    ToastType.match => AppColors.gold,
    ToastType.message => const Color(0xFF26C6DA),
    ToastType.event => const Color(0xFF9B6DFF),
    ToastType.system => const Color(0xFF78909C),
    ToastType.success => const Color(0xFF4CAF50),
    ToastType.error => const Color(0xFFEF5350),
  };

  IconData get _icon => switch (widget.type) {
    ToastType.signal => Icons.bolt_rounded,
    ToastType.match => Icons.favorite_rounded,
    ToastType.message => Icons.chat_bubble_rounded,
    ToastType.event => Icons.event_rounded,
    ToastType.system => Icons.info_outline_rounded,
    ToastType.success => Icons.check_circle_rounded,
    ToastType.error => Icons.error_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isImportant = widget.type == ToastType.signal || widget.type == ToastType.match || widget.type == ToastType.error;
    final dragOpacity = (1.0 - (_dragX.abs() / (screenW * 0.4))).clamp(0.0, 1.0);

    return SlideTransition(
      position: _slideIn,
      child: FadeTransition(
        opacity: _fadeIn,
        child: GestureDetector(
          onHorizontalDragUpdate: (d) => setState(() => _dragX += d.delta.dx),
          onHorizontalDragEnd: (d) {
            if (_dragX.abs() > screenW * 0.25 || d.velocity.pixelsPerSecond.dx.abs() > 500) {
              _dismiss();
            } else {
              setState(() => _dragX = 0);
            }
          },
          onTap: () {
            widget.onTap?.call();
            _dismiss();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            transform: Matrix4.translationValues(_dragX, 0, 0),
            child: Opacity(
              opacity: dragOpacity,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF111113),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isImportant ? AppColors.gold.withValues(alpha: 0.4) : const Color(0xFF222225),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(_icon, color: _dotColor, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(widget.message,
                          style: const TextStyle(color: Color(0xFFF2F2F2), fontSize: 14, fontWeight: FontWeight.w400),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _dismiss,
                      child: Icon(Icons.close_rounded, color: const Color(0xFF78909C), size: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
