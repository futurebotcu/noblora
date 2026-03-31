import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/noble_mode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/mock_mode.dart';
import '../../data/models/filter_state.dart';
import '../../providers/auth_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/mode_provider.dart';

// ═══════════════════════════════════════════════════════════════════
// Entry point
// ═══════════════════════════════════════════════════════════════════

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const FilterBottomSheet(),
    );
  }

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  late FilterState _local;
  int _realResultCount = -1; // -1 = loading
  Timer? _countDebounce;

  @override
  void initState() {
    super.initState();
    _local = ref.read(filterProvider);
    _fetchCount();
  }

  @override
  void dispose() {
    _countDebounce?.cancel();
    super.dispose();
  }

  void _apply() {
    ref.read(filterProvider.notifier).set(_local);
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() => _local = const FilterState());
    _debounceFetchCount();
  }

  void _update(FilterState s) {
    setState(() => _local = s.copyWith(clearPreset: true));
    _debounceFetchCount();
  }

  void _debounceFetchCount() {
    _countDebounce?.cancel();
    _countDebounce = Timer(const Duration(milliseconds: 300), _fetchCount);
  }

  Future<void> _fetchCount() async {
    if (isMockMode) {
      setState(() => _realResultCount = _local.estimatedResults(ref.read(modeProvider)));
      return;
    }
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    try {
      final repo = ref.read(feedRepositoryProvider);
      final count = await repo.countFilteredProfiles(
        userId: uid,
        mode: ref.read(modeProvider).name,
        filters: _local,
      );
      if (mounted) setState(() => _realResultCount = count);
    } catch (_) {
      if (mounted) setState(() => _realResultCount = _local.estimatedResults(ref.read(modeProvider)));
    }
  }

  void _applyPreset(FilterPreset preset) {
    setState(() {
      _local = preset.apply(const FilterState()).copyWith(activePreset: preset.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(modeProvider);
    final accent = mode.accentColor;
    final count = _local.activeCount(mode);
    final results = _realResultCount >= 0 ? _realResultCount : _local.estimatedResults(mode);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
          ),
          child: Column(
            children: [
              // ── Handle + Header ──
              _Header(accent: accent, count: count, onReset: _reset),

              // ── Presets ──
              _PresetBar(
                mode: mode,
                accent: accent,
                activePreset: _local.activePreset,
                onSelect: _applyPreset,
              ),

              // ── Filter body ──
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  children: [
                    const SizedBox(height: AppSpacing.md),

                    // ── Trust Shield ──
                    _TrustShield(
                      enabled: _local.trustShieldEnabled,
                      accent: accent,
                      onChanged: (v) => _update(_local.copyWith(trustShieldEnabled: v)),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Age Range ──
                    _SectionLabel('Age Range'),
                    _AgeLabel(range: _local.ageRange, accent: accent),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: accent,
                        thumbColor: accent,
                        inactiveTrackColor: AppColors.border,
                      ),
                      child: RangeSlider(
                        values: _local.ageRange,
                        min: 18, max: 65, divisions: 47,
                        onChanged: (v) => _update(_local.copyWith(ageRange: v)),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Distance ──
                    _SectionLabel('Distance'),
                    Text('Within ${_local.maxDistance.round()} km',
                        style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: accent,
                        thumbColor: accent,
                        inactiveTrackColor: AppColors.border,
                      ),
                      child: Slider(
                        value: _local.maxDistance,
                        min: 1, max: 100, divisions: 99,
                        onChanged: (v) => _update(_local.copyWith(maxDistance: v)),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Looking For / Social Energy ──
                    if (mode == NobleMode.date) ...[
                      _SectionLabel('Looking For'),
                      _ChipRow(
                        items: datingLookingForOptions,
                        selected: _local.lookingFor,
                        accent: accent,
                        isStrict: _local.isStrict('lookingFor'),
                        onTap: (v) => _update(_local.copyWith(
                          lookingFor: v == _local.lookingFor ? null : v,
                          clearLookingFor: v == _local.lookingFor,
                        )),
                        onLongPress: () => _update(_local.toggleStrict('lookingFor')),
                      ),
                    ],
                    if (mode == NobleMode.bff) ...[
                      _SectionLabel('Looking For'),
                      _ChipRow(
                        items: bffLookingForOptions,
                        selected: _local.bffLookingFor,
                        accent: accent,
                        isStrict: _local.isStrict('bffLookingFor'),
                        onTap: (v) => _update(_local.copyWith(
                          bffLookingFor: v == _local.bffLookingFor ? null : v,
                          clearBffLookingFor: v == _local.bffLookingFor,
                        )),
                        onLongPress: () => _update(_local.toggleStrict('bffLookingFor')),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xxxl),
                    _Divider(),
                    const SizedBox(height: AppSpacing.xxl),

                    // ════════════════════════════════════════
                    // ADVANCED FILTERS
                    // ════════════════════════════════════════

                    if (mode == NobleMode.date) ..._datingAdvanced(accent),
                    if (mode == NobleMode.bff) ..._bffAdvanced(accent),
                  ],
                ),
              ),

              // ── Oracle Counter + Apply ──
              _BottomBar(
                accent: accent,
                count: count,
                results: results,
                onApply: _apply,
                onReset: count > 0 ? _reset : null,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Dating advanced sections ──
  List<Widget> _datingAdvanced(Color accent) {
    return [
      _SectionTitle('Lifestyle'),
      const SizedBox(height: AppSpacing.md),

      _SectionLabel('Social Energy'),
      _ChipRow(
        items: socialEnergyOptions, selected: _local.socialEnergy, accent: accent,
        isStrict: _local.isStrict('socialEnergy'),
        onTap: (v) => _update(_local.copyWith(socialEnergy: v == _local.socialEnergy ? null : v, clearSocialEnergy: v == _local.socialEnergy)),
        onLongPress: () => _update(_local.toggleStrict('socialEnergy')),
      ),
      const SizedBox(height: AppSpacing.xl),

      _SectionLabel('Drinks'),
      _ChipRow(
        items: drinksOptions, selected: _local.drinks, accent: accent,
        isStrict: _local.isStrict('drinks'),
        onTap: (v) => _update(_local.copyWith(drinks: v == _local.drinks ? null : v, clearDrinks: v == _local.drinks)),
        onLongPress: () => _update(_local.toggleStrict('drinks')),
      ),
      const SizedBox(height: AppSpacing.xl),

      _SectionLabel('Smokes'),
      _ChipRow(
        items: smokesOptions, selected: _local.smokes, accent: accent,
        isStrict: _local.isStrict('smokes'),
        onTap: (v) => _update(_local.copyWith(smokes: v == _local.smokes ? null : v, clearSmokes: v == _local.smokes)),
        onLongPress: () => _update(_local.toggleStrict('smokes')),
      ),
      const SizedBox(height: AppSpacing.xl),

      _SectionLabel('Nightlife'),
      _ChipRow(
        items: nightlifeOptions, selected: _local.nightlife, accent: accent,
        isStrict: _local.isStrict('nightlife'),
        onTap: (v) => _update(_local.copyWith(nightlife: v == _local.nightlife ? null : v, clearNightlife: v == _local.nightlife)),
        onLongPress: () => _update(_local.toggleStrict('nightlife')),
      ),
      const SizedBox(height: AppSpacing.xl),

      _SectionLabel('Routine'),
      _ChipRow(
        items: routineOptions, selected: _local.routine, accent: accent,
        isStrict: _local.isStrict('routine'),
        onTap: (v) => _update(_local.copyWith(routine: v == _local.routine ? null : v, clearRoutine: v == _local.routine)),
        onLongPress: () => _update(_local.toggleStrict('routine')),
      ),
      const SizedBox(height: AppSpacing.xl),

      _SectionLabel('Faith Sensitivity'),
      _ChipRow(
        items: faithOptions, selected: _local.faithSensitivity, accent: accent,
        isStrict: _local.isStrict('faith'),
        onTap: (v) => _update(_local.copyWith(faithSensitivity: v == _local.faithSensitivity ? null : v, clearFaith: v == _local.faithSensitivity)),
        onLongPress: () => _update(_local.toggleStrict('faith')),
      ),

      const SizedBox(height: AppSpacing.xxxl),
      _SectionTitle('Profile Quality'),
      const SizedBox(height: AppSpacing.md),
      _ToggleRow('Verified only', _local.verifiedOnly, (v) => _update(_local.copyWith(verifiedOnly: v)), accent),
      _ToggleRow('Complete profiles only', _local.completeOnly, (v) => _update(_local.copyWith(completeOnly: v)), accent),
      _ToggleRow('Has Nob posts', _local.hasNobs, (v) => _update(_local.copyWith(hasNobs: v)), accent),
      _ToggleRow('Has prompts answered', _local.hasPrompts, (v) => _update(_local.copyWith(hasPrompts: v)), accent),
      _ToggleRow('6+ photos', _local.sixPlusPhotos, (v) => _update(_local.copyWith(sixPlusPhotos: v)), accent),

      const SizedBox(height: AppSpacing.xxxl),
      _SectionTitle('Background'),
      const SizedBox(height: AppSpacing.md),
      _SectionLabel('Languages'),
      _MultiChipRow(items: languageOptions, selected: _local.languages, accent: accent,
          onChanged: (v) => _update(_local.copyWith(languages: v))),
      const SizedBox(height: AppSpacing.xl),
      _SectionLabel('Status Badge'),
      _ChipRow(
        items: statusBadgeOptions, selected: _local.statusBadge, accent: accent,
        onTap: (v) => _update(_local.copyWith(statusBadge: v == _local.statusBadge ? null : v, clearStatusBadge: v == _local.statusBadge)),
      ),
      const SizedBox(height: AppSpacing.xxxxl),
    ];
  }

  // ── BFF advanced sections ──
  List<Widget> _bffAdvanced(Color accent) {
    return [
      _SectionTitle('Social Fit'),
      const SizedBox(height: AppSpacing.md),

      _SectionLabel('Social Energy'),
      _ChipRow(
        items: bffSocialEnergyOptions, selected: _local.socialEnergy, accent: accent,
        isStrict: _local.isStrict('socialEnergy'),
        onTap: (v) => _update(_local.copyWith(socialEnergy: v == _local.socialEnergy ? null : v, clearSocialEnergy: v == _local.socialEnergy)),
        onLongPress: () => _update(_local.toggleStrict('socialEnergy')),
      ),
      const SizedBox(height: AppSpacing.xl),

      _SectionLabel('Routine'),
      _ChipRow(
        items: routineOptions, selected: _local.routine, accent: accent,
        isStrict: _local.isStrict('routine'),
        onTap: (v) => _update(_local.copyWith(routine: v == _local.routine ? null : v, clearRoutine: v == _local.routine)),
        onLongPress: () => _update(_local.toggleStrict('routine')),
      ),
      const SizedBox(height: AppSpacing.xl),

      _SectionLabel('Vibe'),
      _MultiChipRow(items: vibeOptions, selected: _local.vibes, accent: accent,
          onChanged: (v) => _update(_local.copyWith(vibes: v))),

      const SizedBox(height: AppSpacing.xxxl),
      _SectionTitle('Activity & Interests'),
      const SizedBox(height: AppSpacing.md),
      _SectionLabel('Interests'),
      _MultiChipRow(items: bffInterestOptions, selected: _local.interests, accent: accent,
          onChanged: (v) => _update(_local.copyWith(interests: v))),

      const SizedBox(height: AppSpacing.xxxl),
      _SectionTitle('Profile Quality'),
      const SizedBox(height: AppSpacing.md),
      _ToggleRow('Verified only', _local.verifiedOnly, (v) => _update(_local.copyWith(verifiedOnly: v)), accent),
      _ToggleRow('Complete profiles only', _local.completeOnly, (v) => _update(_local.copyWith(completeOnly: v)), accent),
      _ToggleRow('Has Nob posts', _local.hasNobs, (v) => _update(_local.copyWith(hasNobs: v)), accent),

      const SizedBox(height: AppSpacing.xl),
      _SectionLabel('Status Badge'),
      _ChipRow(
        items: statusBadgeOptions, selected: _local.statusBadge, accent: accent,
        onTap: (v) => _update(_local.copyWith(statusBadge: v == _local.statusBadge ? null : v, clearStatusBadge: v == _local.statusBadge)),
      ),
      const SizedBox(height: AppSpacing.xxxxl),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════════
// Header
// ═══════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final Color accent;
  final int count;
  final VoidCallback onReset;
  const _Header({required this.accent, required this.count, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: Text('Discovery', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
              if (count > 0) TextButton(onPressed: onReset, child: Text('Reset ($count)', style: TextStyle(color: accent))),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Preset Bar
// ═══════════════════════════════════════════════════════════════════

class _PresetBar extends StatelessWidget {
  final NobleMode mode;
  final Color accent;
  final String? activePreset;
  final void Function(FilterPreset) onSelect;
  const _PresetBar({required this.mode, required this.accent, this.activePreset, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final presets = mode == NobleMode.date ? datingPresets : bffPresets;
    if (presets.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.sm),
        itemCount: presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final p = presets[i];
          final active = p.id == activePreset;
          return GestureDetector(
            onTap: () => onSelect(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: active ? accent.withValues(alpha: 0.15) : AppColors.bg,
                borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
                border: Border.all(color: active ? accent : AppColors.border),
                boxShadow: active
                    ? [BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 8)]
                    : null,
              ),
              child: Text(p.label, style: TextStyle(
                color: active ? accent : AppColors.textMuted,
                fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              )),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Trust Shield
// ═══════════════════════════════════════════════════════════════════

class _TrustShield extends StatelessWidget {
  final bool enabled;
  final Color accent;
  final ValueChanged<bool> onChanged;
  const _TrustShield({required this.enabled, required this.accent, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!enabled),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: enabled ? accent.withValues(alpha: 0.08) : AppColors.bg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: enabled ? accent.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Icon(Icons.shield_rounded,
                  color: enabled ? accent : AppColors.textMuted, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trust Shield', style: TextStyle(
                      color: enabled ? accent : AppColors.textPrimary,
                      fontWeight: FontWeight.w600, fontSize: 15)),
                  Text('Verified \u00B7 Complete \u00B7 Explorer+', style: TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            Switch.adaptive(
              value: enabled,
              activeTrackColor: accent,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Bottom Bar (Oracle Counter + Apply)
// ═══════════════════════════════════════════════════════════════════

class _BottomBar extends StatelessWidget {
  final Color accent;
  final int count;
  final int results;
  final VoidCallback onApply;
  final VoidCallback? onReset;
  const _BottomBar({required this.accent, required this.count, required this.results, required this.onApply, this.onReset});

  @override
  Widget build(BuildContext context) {
    String hint = '';
    if (results < 5) hint = 'Try expanding distance for more profiles';

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.xxxl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Oracle counter
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded, color: accent, size: 14),
              const SizedBox(width: 6),
              Text(
                '$results profiles match',
                style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (hint.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(hint, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (onReset != null) ...[
                TextButton(
                  onPressed: onReset,
                  child: Text('Reset', style: TextStyle(color: AppColors.textMuted)),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: AppColors.bg,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                  ),
                  onPressed: onApply,
                  child: Text(
                    count > 0 ? 'Apply ($count active)' : 'Apply Filters',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Shared widgets
// ═══════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textMuted, letterSpacing: 0.5)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700));
  }
}

class _AgeLabel extends StatelessWidget {
  final RangeValues range;
  final Color accent;
  const _AgeLabel({required this.range, required this.accent});
  @override
  Widget build(BuildContext context) {
    return Text('${range.start.round()} \u2013 ${range.end.round()} years',
        style: TextStyle(color: accent, fontWeight: FontWeight.w600));
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: AppColors.border);
  }
}

/// Single-select chip row with long-press strict mode.
class _ChipRow extends StatelessWidget {
  final List<String> items;
  final String? selected;
  final Color accent;
  final bool isStrict;
  final ValueChanged<String> onTap;
  final VoidCallback? onLongPress;
  const _ChipRow({required this.items, this.selected, required this.accent, this.isStrict = false, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: items.map((item) {
        final isSel = item == selected;
        return GestureDetector(
          onLongPress: isSel && onLongPress != null
              ? () { HapticFeedback.mediumImpact(); onLongPress!(); }
              : null,
          child: ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSel && isStrict) ...[
                  Icon(Icons.lock_rounded, size: 12, color: AppColors.bg),
                  const SizedBox(width: 4),
                ],
                Text(item),
              ],
            ),
            selected: isSel,
            selectedColor: accent,
            backgroundColor: AppColors.surfaceAlt,
            labelStyle: TextStyle(
              color: isSel ? AppColors.bg : AppColors.textSecondary,
              fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
            ),
            side: BorderSide(color: isSel ? (isStrict ? accent : accent.withValues(alpha: 0.5)) : AppColors.border),
            onSelected: (_) => onTap(item),
          ),
        );
      }).toList(),
    );
  }
}

/// Multi-select chip row.
class _MultiChipRow extends StatelessWidget {
  final List<String> items;
  final List<String> selected;
  final Color accent;
  final ValueChanged<List<String>> onChanged;
  const _MultiChipRow({required this.items, required this.selected, required this.accent, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: items.map((item) {
        final isSel = selected.contains(item);
        return FilterChip(
          label: Text(item),
          selected: isSel,
          selectedColor: accent,
          backgroundColor: AppColors.surfaceAlt,
          labelStyle: TextStyle(
            color: isSel ? AppColors.bg : AppColors.textSecondary,
            fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
          ),
          side: BorderSide(color: isSel ? accent : AppColors.border),
          checkmarkColor: AppColors.bg,
          onSelected: (val) {
            final next = [...selected];
            val ? next.add(item) : next.remove(item);
            onChanged(next);
          },
        );
      }).toList(),
    );
  }
}

/// Toggle row for boolean filters.
class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accent;
  const _ToggleRow(this.label, this.value, this.onChanged, this.accent);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: AppColors.textPrimary, fontSize: 14))),
          Switch.adaptive(value: value, activeTrackColor: accent, onChanged: onChanged),
        ],
      ),
    );
  }
}
