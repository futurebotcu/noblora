import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../edit_profile_provider.dart';
import '../profile_options.dart';
import '../widgets/edit_section_shell.dart';
import '../widgets/chip_selector.dart';

class LifestyleSection extends ConsumerWidget {
  const LifestyleSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(editProfileProvider).draft;

    void single(String? Function(dynamic d) getter, void Function(dynamic d, String? v) setter, String v) {
      ref.read(editProfileProvider.notifier).updateDraft((d) {
        setter(d, getter(d) == v ? null : v);
        return d;
      });
    }

    return EditSectionShell(
      title: 'Lifestyle',
      description: 'Your daily rhythms and preferences.',
      saving: ref.watch(editProfileProvider).isSaving,
      onSave: () async {
        final ok = await ref.read(editProfileProvider.notifier).save();
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        children: [
          const SizedBox(height: AppSpacing.md),
          SingleChipSelector(label: 'Sleep schedule', options: ProfileOptions.sleepStyle, selected: d.sleepStyle,
            onSelected: (v) => single((d) => d.sleepStyle, (d, v) => d.sleepStyle = v, v)),
          const SizedBox(height: AppSpacing.xxl),
          SingleChipSelector(label: 'Diet', options: ProfileOptions.dietStyle, selected: d.dietStyle,
            onSelected: (v) => single((d) => d.dietStyle, (d, v) => d.dietStyle = v, v)),
          const SizedBox(height: AppSpacing.xxl),
          SingleChipSelector(label: 'Fitness routine', options: ProfileOptions.fitnessRoutine, selected: d.fitnessRoutine,
            onSelected: (v) => single((d) => d.fitnessRoutine, (d, v) => d.fitnessRoutine = v, v)),
          const SizedBox(height: AppSpacing.xxl),
          SingleChipSelector(label: 'Planning style', options: ProfileOptions.planningStyle, selected: d.planningStyle,
            onSelected: (v) => single((d) => d.planningStyle, (d, v) => d.planningStyle = v, v)),
          const SizedBox(height: AppSpacing.xxl),
          SingleChipSelector(label: 'Spending style', options: ProfileOptions.spendingStyle, selected: d.spendingStyle,
            onSelected: (v) => single((d) => d.spendingStyle, (d, v) => d.spendingStyle = v, v)),
          const SizedBox(height: AppSpacing.xxl),
          MultiChipSelector(label: 'Fashion style', options: ProfileOptions.fashionStyle, selected: d.fashionStyle,
            onToggle: (v) => ref.read(editProfileProvider.notifier).updateDraft((d) {
              final l = List<String>.from(d.fashionStyle); l.contains(v) ? l.remove(v) : l.add(v); d.fashionStyle = l; return d;
            })),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}
