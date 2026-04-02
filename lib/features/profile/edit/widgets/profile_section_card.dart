import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_tokens.dart';

class ProfileSectionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double progress;
  final VoidCallback onTap;
  final List<String> previewChips;
  final bool isEmpty;
  final String? boostHint; // e.g. "+12 → better matches"
  final int staggerIndex;  // for fade-in animation

  const ProfileSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.onTap,
    this.previewChips = const [],
    this.isEmpty = false,
    this.boostHint,
    this.staggerIndex = 0,
  });

  @override
  State<ProfileSectionCard> createState() => _ProfileSectionCardState();
}

class _ProfileSectionCardState extends State<ProfileSectionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeSlide = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    // Staggered entrance
    Future.delayed(Duration(milliseconds: 60 * widget.staggerIndex), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasChips = widget.previewChips.isNotEmpty;
    final done = widget.progress >= 1.0;

    return FadeTransition(
      opacity: _fadeSlide,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(_fadeSlide),
        child: GestureDetector(
          onTapDown: (_) => HapticFeedback.selectionClick(),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: done
                    ? context.accent.withValues(alpha: 0.25)
                    : context.borderColor.withValues(alpha: 0.3),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icon circle
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: widget.isEmpty
                            ? null
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  context.accent.withValues(alpha: 0.15),
                                  context.accent.withValues(alpha: 0.06),
                                ],
                              ),
                        color: widget.isEmpty ? context.borderColor.withValues(alpha: 0.15) : null,
                      ),
                      child: Icon(widget.icon,
                        color: widget.isEmpty ? context.textDisabled : context.accent,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          )),
                          const SizedBox(height: 2),
                          Text(widget.subtitle, style: TextStyle(
                            color: widget.isEmpty ? context.textDisabled : context.textMuted,
                            fontSize: 12,
                            height: 1.3,
                          )),
                        ],
                      ),
                    ),
                    // Chevron
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isEmpty ? Colors.transparent : context.accent.withValues(alpha: 0.06),
                      ),
                      child: Icon(Icons.chevron_right_rounded,
                        color: widget.isEmpty ? context.textDisabled : context.accent.withValues(alpha: 0.6),
                        size: 18,
                      ),
                    ),
                  ],
                ),
                // Preview chips with icons
                if (hasChips) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 28,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.previewChips.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: context.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.accent.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (i == 0) ...[
                              Icon(widget.icon, size: 11, color: context.accent.withValues(alpha: 0.6)),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              widget.previewChips[i],
                              style: TextStyle(
                                color: context.accent.withValues(alpha: 0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                // Boost hint — curiosity hook
                if (widget.boostHint != null && widget.isEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.trending_up_rounded, size: 13, color: context.accent.withValues(alpha: 0.6)),
                      const SizedBox(width: 5),
                      Text(widget.boostHint!, style: TextStyle(
                        color: context.accent.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                      )),
                    ],
                  ),
                ],
                // Progress bar
                if (!widget.isEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: widget.progress,
                      minHeight: 2,
                      backgroundColor: context.borderColor.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        done ? context.accent : context.accent.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
