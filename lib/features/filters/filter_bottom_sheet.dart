import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/noble_mode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/filter_options.dart';
import '../../providers/filter_provider.dart';
import '../../providers/mode_provider.dart';

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

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet>
    with SingleTickerProviderStateMixin {
  late FilterOptions _local;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _local = ref.read(filterProvider);
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    ref.read(filterProvider.notifier).update((_) => _local);
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() => _local = const FilterOptions());
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(modeProvider);
    final activeCount = _local.activeCount(mode);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXl),
            ),
          ),
          child: Column(
            children: [
              // Handle + header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                  0,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusCircle),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filters',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (activeCount > 0)
                          TextButton(
                            onPressed: _reset,
                            child: Text(
                              'Reset ($activeCount)',
                              style: TextStyle(color: mode.accentColor),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Tab bar
                    TabBar(
                      controller: _tabCtrl,
                      indicatorColor: mode.accentColor,
                      labelColor: mode.accentColor,
                      unselectedLabelColor: AppColors.textMuted,
                      dividerColor: AppColors.border,
                      tabs: const [
                        Tab(text: 'Common'),
                        Tab(text: 'Specific'),
                        Tab(text: 'Lifestyle'),
                      ],
                    ),
                  ],
                ),
              ),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _CommonFilters(
                      local: _local,
                      onChanged: (f) => setState(() => _local = f),
                      accentColor: mode.accentColor,
                    ),
                    _SpecificFilters(
                      local: _local,
                      mode: mode,
                      onChanged: (f) => setState(() => _local = f),
                      accentColor: mode.accentColor,
                    ),
                    _LifestyleFilters(
                      local: _local,
                      mode: mode,
                      onChanged: (f) => setState(() => _local = f),
                      accentColor: mode.accentColor,
                    ),
                  ],
                ),
              ),
              // Apply button
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.md,
                  AppSpacing.xxl,
                  AppSpacing.xxxl,
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mode.accentColor,
                    foregroundColor: AppColors.bg,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  onPressed: _apply,
                  child: Text(
                    activeCount > 0
                        ? 'Apply ($activeCount active)'
                        : 'Apply Filters',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Common Filters Tab
// ---------------------------------------------------------------------------

class _CommonFilters extends StatelessWidget {
  final FilterOptions local;
  final ValueChanged<FilterOptions> onChanged;
  final Color accentColor;

  const _CommonFilters({
    required this.local,
    required this.onChanged,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        _SectionLabel('Age Range'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${local.ageRange.start.round()} – ${local.ageRange.end.round()}',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'years',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: accentColor,
            thumbColor: accentColor,
            inactiveTrackColor: AppColors.border,
          ),
          child: RangeSlider(
            values: local.ageRange,
            min: 18,
            max: 65,
            divisions: 47,
            onChanged: (v) => onChanged(local.copyWith(ageRange: v)),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        _SectionLabel('Max Distance'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${local.maxDistance.round()} km',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: accentColor,
            thumbColor: accentColor,
            inactiveTrackColor: AppColors.border,
          ),
          child: Slider(
            value: local.maxDistance,
            min: 5,
            max: 500,
            divisions: 99,
            onChanged: (v) => onChanged(local.copyWith(maxDistance: v)),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        _SectionLabel('City'),
        _FilterTextField(
          hint: 'e.g. Istanbul',
          initial: local.city ?? '',
          onChanged: (v) => onChanged(
            v.isEmpty
                ? local.copyWith(clearCity: true)
                : local.copyWith(city: v),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Specific Filters Tab (mode-aware)
// ---------------------------------------------------------------------------

class _SpecificFilters extends StatelessWidget {
  final FilterOptions local;
  final NobleMode mode;
  final ValueChanged<FilterOptions> onChanged;
  final Color accentColor;

  const _SpecificFilters({
    required this.local,
    required this.mode,
    required this.onChanged,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        if (mode == NobleMode.date) ...[
          _SectionLabel('Relationship Goal'),
          _ChoiceChips<RelationshipGoal>(
            items: RelationshipGoal.values,
            selected: local.relationshipGoal,
            labelOf: (e) => e.label,
            accentColor: accentColor,
            onChanged: (v) => onChanged(local.copyWith(relationshipGoal: v)),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _SectionLabel('Education'),
          _ChoiceChips<EducationLevel>(
            items: EducationLevel.values,
            selected: local.education,
            labelOf: (e) => e.label,
            accentColor: accentColor,
            onChanged: (v) => onChanged(local.copyWith(education: v)),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _SectionLabel('Family Plans'),
          _ChoiceChips<FamilyPlan>(
            items: FamilyPlan.values,
            selected: local.familyPlan,
            labelOf: (e) => e.label,
            accentColor: accentColor,
            onChanged: (v) => onChanged(local.copyWith(familyPlan: v)),
          ),
        ],
        if (mode == NobleMode.bff || mode == NobleMode.social) ...[
          _SectionLabel('Interests'),
          _MultiChips(
            items: allInterests,
            selected: local.interests,
            accentColor: accentColor,
            onChanged: (v) => onChanged(local.copyWith(interests: v)),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _SectionLabel('Languages'),
          _MultiChips(
            items: allLanguages,
            selected: local.languages,
            accentColor: accentColor,
            onChanged: (v) => onChanged(local.copyWith(languages: v)),
          ),
        ],
        if (mode == NobleMode.social) ...[
          const SizedBox(height: AppSpacing.xxl),
          _SectionLabel('Event Types'),
          _MultiChips(
            items: EventType.values.map((e) => e.label).toList(),
            selected: local.eventTypes.map((e) => e.label).toList(),
            accentColor: accentColor,
            onChanged: (labels) {
              final types = EventType.values
                  .where((e) => labels.contains(e.label))
                  .toList();
              onChanged(local.copyWith(eventTypes: types));
            },
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Lifestyle Filters Tab
// ---------------------------------------------------------------------------

class _LifestyleFilters extends StatelessWidget {
  final FilterOptions local;
  final NobleMode mode;
  final ValueChanged<FilterOptions> onChanged;
  final Color accentColor;

  const _LifestyleFilters({
    required this.local,
    required this.mode,
    required this.onChanged,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (mode != NobleMode.date) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                color: accentColor, size: 48),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No lifestyle filters for this mode.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        _SectionLabel('Smoking'),
        _ChoiceChips<LifestyleSmoke>(
          items: LifestyleSmoke.values,
          selected: local.smoking,
          labelOf: (e) => e.label,
          accentColor: accentColor,
          onChanged: (v) => onChanged(local.copyWith(smoking: v)),
        ),
        const SizedBox(height: AppSpacing.xxl),
        _SectionLabel('Drinking'),
        _ChoiceChips<LifestyleDrink>(
          items: LifestyleDrink.values,
          selected: local.drinking,
          labelOf: (e) => e.label,
          accentColor: accentColor,
          onChanged: (v) => onChanged(local.copyWith(drinking: v)),
        ),
        const SizedBox(height: AppSpacing.xxl),
        _SectionLabel('Availability'),
        _MultiChips(
          items: allDays,
          selected: local.availabilityDays,
          accentColor: accentColor,
          onChanged: (v) => onChanged(local.copyWith(availabilityDays: v)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helper widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
      ),
    );
  }
}

class _ChoiceChips<T> extends StatelessWidget {
  final List<T> items;
  final T? selected;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;
  final Color accentColor;

  const _ChoiceChips({
    required this.items,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: items.map((item) {
        final isSel = item == selected;
        return ChoiceChip(
          label: Text(labelOf(item)),
          selected: isSel,
          selectedColor: accentColor,
          backgroundColor: AppColors.surfaceAlt,
          labelStyle: TextStyle(
            color: isSel ? AppColors.bg : AppColors.textSecondary,
            fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
          ),
          side: BorderSide(
            color: isSel ? accentColor : AppColors.border,
          ),
          onSelected: (_) => onChanged(isSel ? null : item),
        );
      }).toList(),
    );
  }
}

class _MultiChips extends StatelessWidget {
  final List<String> items;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final Color accentColor;

  const _MultiChips({
    required this.items,
    required this.selected,
    required this.onChanged,
    required this.accentColor,
  });

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
          selectedColor: accentColor,
          backgroundColor: AppColors.surfaceAlt,
          labelStyle: TextStyle(
            color: isSel ? AppColors.bg : AppColors.textSecondary,
            fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
          ),
          side: BorderSide(
            color: isSel ? accentColor : AppColors.border,
          ),
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

class _FilterTextField extends StatefulWidget {
  final String hint;
  final String initial;
  final ValueChanged<String> onChanged;

  const _FilterTextField({
    required this.hint,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<_FilterTextField> createState() => _FilterTextFieldState();
}

class _FilterTextFieldState extends State<_FilterTextField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: widget.hint,
        isDense: true,
      ),
    );
  }
}
