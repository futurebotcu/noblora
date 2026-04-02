import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';

/// Single-select chip group
class SingleChipSelector extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;
  final String? label;

  const SingleChipSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(label!, style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final active = selected == o;
            return GestureDetector(
              onTap: () => onSelected(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? context.accent.withValues(alpha: 0.12) : context.surfaceColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
                  border: Border.all(color: active ? context.accent.withValues(alpha: 0.5) : context.borderColor, width: 0.5),
                ),
                child: Text(o, style: TextStyle(color: active ? context.accent : context.textMuted, fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Multi-select chip group
class MultiChipSelector extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;
  final String? label;

  const MultiChipSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Text(label!, style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                if (selected.isNotEmpty) ...[
                  const Spacer(),
                  Text('${selected.length} selected', style: TextStyle(color: context.accent, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final active = selected.contains(o);
            return GestureDetector(
              onTap: () => onToggle(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? context.accent.withValues(alpha: 0.12) : context.surfaceColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
                  border: Border.all(color: active ? context.accent.withValues(alpha: 0.5) : context.borderColor, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (active) ...[
                      Icon(Icons.check_rounded, size: 14, color: context.accent),
                      const SizedBox(width: 4),
                    ],
                    Text(o, style: TextStyle(color: active ? context.accent : context.textMuted, fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
