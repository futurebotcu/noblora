import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../edit_profile_provider.dart';
import '../profile_options.dart';
import '../widgets/edit_section_shell.dart';
import '../widgets/chip_selector.dart';

class IdentityLifeSection extends ConsumerStatefulWidget {
  const IdentityLifeSection({super.key});
  @override
  ConsumerState<IdentityLifeSection> createState() => _State();
}

class _State extends ConsumerState<IdentityLifeSection> {
  @override
  Widget build(BuildContext context) {
    final d = ref.watch(editProfileProvider).draft;

    return EditSectionShell(
      title: 'Identity & Life',
      description: 'These help us find more compatible people for you.',
      saving: ref.watch(editProfileProvider).isSaving,
      onSave: () async {
        final ok = await ref.read(editProfileProvider.notifier).save();
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        children: [
          const SizedBox(height: AppSpacing.md),
          SingleChipSelector(label: 'Gender', options: ProfileOptions.genders, selected: d.gender,
            onSelected: (v) => _update((d) => d.gender = d.gender == v ? null : v)),
          const SizedBox(height: AppSpacing.xxl),
          MultiChipSelector(label: 'Interested in', options: ProfileOptions.interestedIn, selected: d.interestedIn,
            onToggle: (v) => _update((d) { final l = List<String>.from(d.interestedIn); l.contains(v) ? l.remove(v) : l.add(v); d.interestedIn = l; })),
          const SizedBox(height: AppSpacing.xxl),
          SingleChipSelector(label: 'Pronouns', options: ProfileOptions.pronouns, selected: d.pronouns,
            onSelected: (v) => _update((d) => d.pronouns = d.pronouns == v ? null : v)),
          const SizedBox(height: AppSpacing.xxl),
          SingleChipSelector(label: 'Religious / spiritual approach', options: ProfileOptions.religiousApproach, selected: d.religiousApproach,
            onSelected: (v) => _update((d) => d.religiousApproach = d.religiousApproach == v ? null : v)),
          const SizedBox(height: AppSpacing.xxl),
          SingleChipSelector(label: 'Wants children', options: ProfileOptions.wantsChildren, selected: d.wantsChildren,
            onSelected: (v) => _update((d) => d.wantsChildren = d.wantsChildren == v ? null : v)),
          const SizedBox(height: AppSpacing.xxl),
          SingleChipSelector(label: 'Pets', options: ProfileOptions.petsStatus, selected: d.petsStatus,
            onSelected: (v) => _update((d) => d.petsStatus = d.petsStatus == v ? null : v)),
          const SizedBox(height: AppSpacing.xxl),
          SingleChipSelector(label: 'Smoking', options: ProfileOptions.smoking, selected: d.smoking,
            onSelected: (v) => _update((d) => d.smoking = d.smoking == v ? null : v)),
          const SizedBox(height: AppSpacing.xxl),
          SingleChipSelector(label: 'Alcohol', options: ProfileOptions.alcohol, selected: d.alcohol,
            onSelected: (v) => _update((d) => d.alcohol = d.alcohol == v ? null : v)),
          const SizedBox(height: AppSpacing.xxl),
          SingleChipSelector(label: 'Nightlife', options: ProfileOptions.nightlife, selected: d.nightlife,
            onSelected: (v) => _update((d) => d.nightlife = d.nightlife == v ? null : v)),
          const SizedBox(height: AppSpacing.xxl),
          SingleChipSelector(label: 'Social energy', options: ProfileOptions.socialEnergy, selected: d.socialEnergy,
            onSelected: (v) => _update((d) => d.socialEnergy = d.socialEnergy == v ? null : v)),
          const SizedBox(height: AppSpacing.xxl),
          SingleChipSelector(label: 'Personality', options: ProfileOptions.personalityStyle, selected: d.personalityStyle,
            onSelected: (v) => _update((d) => d.personalityStyle = d.personalityStyle == v ? null : v)),
          const SizedBox(height: AppSpacing.xxl),
          SingleChipSelector(label: 'Organization style', options: ProfileOptions.organizationStyle, selected: d.organizationStyle,
            onSelected: (v) => _update((d) => d.organizationStyle = d.organizationStyle == v ? null : v)),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  void _update(void Function(dynamic d) fn) {
    ref.read(editProfileProvider.notifier).updateDraft((d) { fn(d); return d; });
  }
}
