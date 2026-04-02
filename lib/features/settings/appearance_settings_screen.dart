import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../providers/appearance_provider.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appearanceProvider);
    final accent = state.accent;

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

          // ═══ SECTION 1 — THEME ═══
          _SectionLabel('THEME'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _ThemeCard(
                label: 'Dark',
                icon: Icons.dark_mode_rounded,
                previewColor: const Color(0xFF111113),
                selected: state.themeMode == ThemeMode.dark,
                accent: accent,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(appearanceProvider.notifier).setThemeMode(ThemeMode.dark);
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              _ThemeCard(
                label: 'Light',
                icon: Icons.light_mode_rounded,
                previewColor: const Color(0xFFFAF9F6),
                selected: state.themeMode == ThemeMode.light,
                accent: accent,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(appearanceProvider.notifier).setThemeMode(ThemeMode.light);
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              _ThemeCard(
                label: 'System',
                icon: Icons.settings_brightness_rounded,
                previewColor: const Color(0xFF333333),
                selected: state.themeMode == ThemeMode.system,
                accent: accent,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(appearanceProvider.notifier).setThemeMode(ThemeMode.system);
                },
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // ═══ SECTION 2 — ACCENT COLOR ═══
          _SectionLabel('ACCENT COLOR'),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: AppColors.accents.map((a) {
              final sel = a.id == state.accentId;
              return _AccentCircle(
                accent: a,
                selected: sel,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(appearanceProvider.notifier).setAccent(a.id);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // ═══ SECTION 3 — LIVE PREVIEW ═══
          _SectionLabel('PREVIEW'),
          const SizedBox(height: AppSpacing.md),
          _LivePreview(accent: accent, isDark: context.isDark),

          const SizedBox(height: AppSpacing.xxxxl),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Section label
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(
      color: context.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Theme card
// ═══════════════════════════════════════════════════════════════════════════════

class _ThemeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color previewColor;
  final bool selected;
  final AccentColor accent;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.label,
    required this.icon,
    required this.previewColor,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent.primary : context.borderColor,
              width: selected ? 1.5 : 0.5,
            ),
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: previewColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.borderColor, width: 0.5),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: -2, right: -2,
                      child: Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          color: accent.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_rounded, size: 12, color: accent.onAccent),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(label, style: TextStyle(
                color: selected ? accent.primary : context.textMuted,
                fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
            ],
          ),
        ),
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
  final VoidCallback onTap;

  const _AccentCircle({required this.accent, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: accent.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.white : Colors.transparent,
                width: selected ? 3 : 0,
              ),
              boxShadow: selected ? [
                BoxShadow(color: accent.primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 2)),
              ] : null,
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
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
  final bool isDark;

  const _LivePreview({required this.accent, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF111113) : const Color(0xFFFAF9F6);
    final surface = isDark ? const Color(0xFF18181B) : const Color(0xFFFFFFFF);
    final text = isDark ? const Color(0xFFF2F2F2) : const Color(0xFF1A1814);
    final muted = isDark ? const Color(0xFF808080) : const Color(0xFF8C8680);
    final border = isDark ? const Color(0xFF222225) : const Color(0xFFE8E4DC);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Column(
        children: [
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
              _previewChip('Active', true, accent, surface, text, border),
              const SizedBox(width: 8),
              _previewChip('Inactive', false, accent, surface, muted, border),
              const SizedBox(width: 8),
              _previewChip('Option', false, accent, surface, muted, border),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Input preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.primary, width: 1.5),
            ),
            child: Text('Search...', style: TextStyle(color: muted, fontSize: 14)),
          ),
          const SizedBox(height: AppSpacing.md),

          // Nav indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Icon(Icons.favorite_rounded, color: accent.primary, size: 22),
              Icon(Icons.explore_outlined, color: muted, size: 22),
              Icon(Icons.chat_outlined, color: muted, size: 22),
              Icon(Icons.person_outline, color: muted, size: 22),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewChip(String label, bool active, AccentColor accent,
      Color surface, Color text, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? accent.soft : surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? accent.primary.withValues(alpha: 0.5) : border,
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
            color: active ? accent.primary : text,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          )),
        ],
      ),
    );
  }
}
