import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/post.dart';
import '../../providers/appearance_provider.dart';
import '../../providers/posts_provider.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appearanceProvider);
    final accent = state.accent;
    final tierAsync = ref.watch(nobTierProvider);
    final isNoble = tierAsync.maybeWhen(data: (t) => t == NobTier.noble, orElse: () => false);

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Appearance',
            style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        children: [
          const SizedBox(height: AppSpacing.lg),

          // ═══ SECTION — YOUR NOBLARA ═══
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: context.accent, size: 16),
              const SizedBox(width: 6),
              Text('YOUR NOBLARA', style: TextStyle(
                  color: context.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Personalize your experience', style: TextStyle(color: context.textDisabled, fontSize: 12)),

          const SizedBox(height: AppSpacing.xxl),

          // ═══ ACCENT COLOR ═══
          Text('ACCENT COLOR', style: TextStyle(
              color: context.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: AppSpacing.lg),

          if (!isNoble)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.emerald500.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.15)),
              ),
              child: Row(children: [
                Icon(Icons.lock_outline_rounded, color: AppColors.emerald500.withValues(alpha: 0.6), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text('Unlock accent colors with Noble tier',
                    style: TextStyle(color: AppColors.emerald500.withValues(alpha: 0.8), fontSize: 13))),
              ]),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: AppColors.accents.map((a) {
              final sel = a.id == state.accentId;
              final locked = a.nobleOnly && !isNoble;
              return _AccentCircle(
                accent: a,
                selected: sel,
                locked: locked,
                onTap: () {
                  if (locked) return;
                  HapticFeedback.lightImpact();
                  ref.read(appearanceProvider.notifier).setAccent(a.id, isNoble: isNoble);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // ═══ LIVE PREVIEW ═══
          Text('PREVIEW', style: TextStyle(
              color: context.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: AppSpacing.md),
          _LivePreview(accent: accent),

          const SizedBox(height: AppSpacing.xxxxl),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Accent circle
// ═══════════════════════════════════════════════════════════════════════════════

class _AccentCircle extends StatelessWidget {
  final AccentColor accent;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  const _AccentCircle({required this.accent, required this.selected, required this.locked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: locked ? accent.primary.withValues(alpha: 0.4) : accent.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.bg : Colors.transparent,
                width: selected ? 3 : 0,
              ),
              boxShadow: selected ? [
                BoxShadow(color: accent.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 2)),
              ] : null,
            ),
            child: locked
                ? Icon(Icons.lock_rounded, color: Colors.white.withValues(alpha: 0.5), size: 18)
                : selected
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                    : null,
          ),
          const SizedBox(height: 6),
          Text(accent.name, style: TextStyle(
            color: selected ? context.textPrimary : context.textMuted,
            fontSize: 10, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Live preview
// ═══════════════════════════════════════════════════════════════════════════════

class _LivePreview extends StatelessWidget {
  final AccentColor accent;

  const _LivePreview({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor, width: 0.5),
      ),
      child: Column(
        children: [
          // Avatar + name
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.primary.withValues(alpha: 0.12),
                border: Border.all(color: accent.primary.withValues(alpha: 0.3)),
              ),
              child: Center(child: Text('N', style: TextStyle(color: accent.primary, fontSize: 16, fontWeight: FontWeight.w700))),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Noblara User', style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              Text('Istanbul', style: TextStyle(color: context.textMuted, fontSize: 11)),
            ]),
          ]),
          const SizedBox(height: AppSpacing.md),

          // Button preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: accent.primary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: Text('Connect', style: TextStyle(
                color: accent.onAccent, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Chips row
          Row(
            children: [
              _previewChip('Active', true, accent, context),
              const SizedBox(width: 8),
              _previewChip('Inactive', false, accent, context),
              const SizedBox(width: 8),
              _previewChip('Option', false, accent, context),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Nav indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Icon(Icons.favorite_rounded, color: accent.primary, size: 22),
              Icon(Icons.explore_outlined, color: context.textMuted, size: 22),
              Icon(Icons.chat_outlined, color: context.textMuted, size: 22),
              Icon(Icons.person_outline, color: context.textMuted, size: 22),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewChip(String label, bool active, AccentColor accent, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? accent.soft : context.surfaceColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? accent.primary.withValues(alpha: 0.5) : context.borderColor,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active) ...[
            Icon(Icons.check_rounded, size: 14, color: accent.primary),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(
            color: active ? accent.primary : context.textMuted,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          )),
        ],
      ),
    );
  }
}
