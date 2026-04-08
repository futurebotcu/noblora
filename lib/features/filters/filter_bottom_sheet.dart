import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/noble_mode.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/premium.dart';
import '../../core/utils/mock_mode.dart';
import '../../data/models/filter_state.dart';
import '../../providers/auth_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/mode_provider.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => const FilterBottomSheet(),
    );
  }

  @override
  ConsumerState<FilterBottomSheet> createState() => _State();
}

class _State extends ConsumerState<FilterBottomSheet> {
  late FilterState _f;
  bool _showAdvanced = false;
  int _count = -1;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _f = ref.read(filterProvider);
    _fetchCount();
  }

  @override
  void dispose() { _debounce?.cancel(); super.dispose(); }

  void _apply() { ref.read(filterProvider.notifier).set(_f); Navigator.pop(context); }
  void _reset() { setState(() { _f = const FilterState(); _showAdvanced = false; }); _debounceFetch(); }
  void _set(FilterState s) { setState(() => _f = s); _debounceFetch(); }

  void _debounceFetch() { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 300), _fetchCount); }

  Future<void> _fetchCount() async {
    if (isMockMode) { setState(() => _count = _f.estimatedResults(ref.read(modeProvider))); return; }
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;
    try {
      final repo = ref.read(feedRepositoryProvider);
      final c = await repo.countFilteredProfiles(userId: uid, mode: ref.read(modeProvider).name, filters: _f);
      if (mounted) setState(() => _count = c);
    } catch (e) {
      debugPrint('[filters] Count fetch failed: $e');
      if (mounted) setState(() => _count = -1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(modeProvider);
    final accent = mode.accentColor;
    final count = _f.activeCount(mode);

    return DraggableScrollableSheet(
      initialChildSize: 0.85, minChildSize: 0.4, maxChildSize: 0.95,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: accent.withValues(alpha: 0.12))),
          boxShadow: Premium.shadowLg,
        ),
        child: Column(children: [
          // Header
          Padding(padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0),
            child: Column(children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999))),
              const SizedBox(height: AppSpacing.lg),
              Row(children: [
                Text('Filter', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: AppSpacing.sm),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(mode == NobleMode.date ? 'Dating' : mode == NobleMode.bff ? 'BFF' : mode.shortLabel, style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w600))),
                const Spacer(),
                if (count > 0) TextButton(onPressed: _reset, child: Text('Reset ($count)', style: TextStyle(color: accent))),
              ]),
            ])),

          // Body
          Expanded(child: ListView(controller: scroll, padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl), children: [
            const SizedBox(height: AppSpacing.xxl),
            // ═══ QUICK FILTERS ═══
            Text('Quick filters', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: AppSpacing.md),

            // Age
            _Label('Age range'),
            _AgeLabel(range: _f.ageRange, accent: accent),
            SliderTheme(data: SliderTheme.of(context).copyWith(activeTrackColor: accent, thumbColor: accent, inactiveTrackColor: context.borderColor),
              child: RangeSlider(values: _f.ageRange, min: 18, max: 65, divisions: 47,
                  onChanged: (v) => _set(_f.copyWith(ageRange: v)))),
            const SizedBox(height: AppSpacing.lg),

            // City/distance
            _Label('Distance'),
            Text('Within ${_f.maxDistance.round()} km', style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w500)),
            SliderTheme(data: SliderTheme.of(context).copyWith(activeTrackColor: accent, thumbColor: accent, inactiveTrackColor: context.borderColor),
              child: Slider(value: _f.maxDistance, min: 1, max: 100, divisions: 99,
                  onChanged: (v) => _set(_f.copyWith(maxDistance: v)))),
            const SizedBox(height: AppSpacing.lg),

            // Has Nobs
            _Toggle('Has active Nobs', _f.hasNobs, (v) => _set(_f.copyWith(hasNobs: v)), accent),
            _Toggle('Has completed prompts', _f.hasPrompts, (v) => _set(_f.copyWith(hasPrompts: v)), accent),

            // Tier filters
            const SizedBox(height: AppSpacing.md),
            _Label('Tier'),
            Wrap(spacing: 8, children: [
              _Chip('All', _f.statusBadge == null, () => _set(_f.copyWith(clearStatusBadge: true)), accent),
              _Chip('Explorer+', _f.statusBadge == 'Explorer+', () => _set(_f.copyWith(statusBadge: 'Explorer+')), accent),
              _Chip('Noble only', _f.statusBadge == 'Noble only', () => _set(_f.copyWith(statusBadge: 'Noble only')), accent),
            ]),

            // Mode-specific quick
            const SizedBox(height: AppSpacing.lg),
            if (mode == NobleMode.date) ...[
              _Label('Looking for'),
              Wrap(spacing: 6, runSpacing: 6, children: datingLookingForOptions.map((o) =>
                  _Chip(o, _f.lookingFor == o, () => _set(_f.copyWith(
                      lookingFor: _f.lookingFor == o ? null : o, clearLookingFor: _f.lookingFor == o)), accent)).toList()),
            ],
            if (mode == NobleMode.bff) ...[
              _Label('Looking for'),
              Wrap(spacing: 6, runSpacing: 6, children: bffLookingForOptions.map((o) =>
                  _Chip(o, _f.bffLookingFor == o, () => _set(_f.copyWith(
                      bffLookingFor: _f.bffLookingFor == o ? null : o, clearBffLookingFor: _f.bffLookingFor == o)), accent)).toList()),
              const SizedBox(height: AppSpacing.md),
              _Label('Language (preference)'),
              Wrap(spacing: 6, runSpacing: 6, children: languageOptions.map((l) {
                final sel = _f.languages.contains(l);
                return _Chip(l, sel, () {
                  final next = [..._f.languages]; sel ? next.remove(l) : next.add(l);
                  _set(_f.copyWith(languages: next));
                }, accent);
              }).toList()),
            ],

            // ═══ ADVANCED TOGGLE ═══
            const SizedBox(height: AppSpacing.xxl),
            GestureDetector(
              onTap: () => setState(() => _showAdvanced = !_showAdvanced),
              child: Row(children: [
                Text(_showAdvanced ? 'Hide advanced' : 'More filters', style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(width: 4),
                Icon(_showAdvanced ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: accent, size: 18),
              ]),
            ),

            // ═══ ADVANCED FILTERS ═══
            if (_showAdvanced) ...[
              const SizedBox(height: AppSpacing.xxl),
              Text('Advanced', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: AppSpacing.md),

              _Label('Social energy'),
              Wrap(spacing: 6, runSpacing: 6, children: (mode == NobleMode.bff ? bffSocialEnergyOptions : socialEnergyOptions).map((o) =>
                  _Chip(o, _f.socialEnergy == o, () => _set(_f.copyWith(
                      socialEnergy: _f.socialEnergy == o ? null : o, clearSocialEnergy: _f.socialEnergy == o)), accent)).toList()),
              const SizedBox(height: AppSpacing.lg),

              _Label('Routine'),
              Wrap(spacing: 6, runSpacing: 6, children: routineOptions.map((o) =>
                  _Chip(o, _f.routine == o, () => _set(_f.copyWith(
                      routine: _f.routine == o ? null : o, clearRoutine: _f.routine == o)), accent)).toList()),
              const SizedBox(height: AppSpacing.lg),

              _Label('Drinks'),
              Wrap(spacing: 6, runSpacing: 6, children: drinksOptions.map((o) =>
                  _Chip(o, _f.drinks == o, () => _set(_f.copyWith(
                      drinks: _f.drinks == o ? null : o, clearDrinks: _f.drinks == o)), accent)).toList()),
              const SizedBox(height: AppSpacing.lg),

              _Label('Smokes'),
              Wrap(spacing: 6, runSpacing: 6, children: smokesOptions.map((o) =>
                  _Chip(o, _f.smokes == o, () => _set(_f.copyWith(
                      smokes: _f.smokes == o ? null : o, clearSmokes: _f.smokes == o)), accent)).toList()),
              const SizedBox(height: AppSpacing.lg),

              _Label('Nightlife'),
              Wrap(spacing: 6, runSpacing: 6, children: nightlifeOptions.map((o) =>
                  _Chip(o, _f.nightlife == o, () => _set(_f.copyWith(
                      nightlife: _f.nightlife == o ? null : o, clearNightlife: _f.nightlife == o)), accent)).toList()),
              const SizedBox(height: AppSpacing.lg),

              if (mode == NobleMode.date) ...[
                _Label('Faith sensitivity'),
                Wrap(spacing: 6, runSpacing: 6, children: faithOptions.map((o) =>
                    _Chip(o, _f.faithSensitivity == o, () => _set(_f.copyWith(
                        faithSensitivity: _f.faithSensitivity == o ? null : o, clearFaith: _f.faithSensitivity == o)), accent)).toList()),
                const SizedBox(height: AppSpacing.lg),
              ],

              if (mode == NobleMode.bff) ...[
                _Label('Interests (preference)'),
                Wrap(spacing: 6, runSpacing: 6, children: bffInterestOptions.map((i) {
                  final sel = _f.interests.contains(i);
                  return _Chip(i, sel, () { final next = [..._f.interests]; sel ? next.remove(i) : next.add(i); _set(_f.copyWith(interests: next)); }, accent);
                }).toList()),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Profile quality
              _Toggle('6+ photos', _f.sixPlusPhotos, (v) => _set(_f.copyWith(sixPlusPhotos: v)), accent),
              _Toggle('Has pinned Nob', _f.pinnedNobExists, (v) => _set(_f.copyWith(pinnedNobExists: v)), accent),
              _Toggle('Same city only', _f.sameCityOnly, (v) => _set(_f.copyWith(sameCityOnly: v)), accent),
            ],

            const SizedBox(height: AppSpacing.xxxl),
          ])),

          // Bottom: count + apply
          Container(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.xxxl),
            decoration: BoxDecoration(color: context.surfaceColor, border: Border(top: BorderSide(color: context.borderColor))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_count >= 0) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.auto_awesome_rounded, color: accent, size: 13),
                  const SizedBox(width: 6),
                  Text(
                    _count < 0 ? 'Counting...' : '${_f.hasExtraFilters ? "~" : ""}$_count profiles match',
                    style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ])),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  boxShadow: Premium.accentGlow(accent, intensity: 0.6),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd))),
                  onPressed: _apply,
                  child: Text(count > 0 ? 'Apply ($count active)' : 'Apply', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Shared widgets
// ═══════════════════════════════════════════════════════════════════

class _Label extends StatelessWidget {
  final String t; const _Label(this.t);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 4),
    child: Text(t, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.textMuted, fontSize: 12)));
}

class _AgeLabel extends StatelessWidget {
  final RangeValues range; final Color accent;
  const _AgeLabel({required this.range, required this.accent});
  @override
  Widget build(BuildContext context) => Text('${range.start.round()} \u2013 ${range.end.round()} years',
      style: TextStyle(color: accent, fontWeight: FontWeight.w600, fontSize: 13));
}

class _Chip extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap; final Color accent;
  const _Chip(this.label, this.active, this.onTap, this.accent);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: AnimatedContainer(
    duration: Premium.dFast,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: Premium.chipDecoration(
      bgColor: active ? accent.withValues(alpha: 0.08) : context.elevatedColor,
      borderColor: active ? accent.withValues(alpha: 0.3) : context.borderSubtleColor,
      selected: active,
    ),
    child: Text(label, style: TextStyle(color: active ? accent : context.textMuted, fontSize: 12,
        fontWeight: active ? FontWeight.w600 : FontWeight.w400, letterSpacing: 0.1))));
}

class _Toggle extends StatelessWidget {
  final String label; final bool value; final ValueChanged<bool> onChanged; final Color accent;
  const _Toggle(this.label, this.value, this.onChanged, this.accent);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: context.textPrimary, fontSize: 13))),
      Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: accent.withValues(alpha: 0.4))]));
}
