import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../edit_profile_provider.dart';
import '../profile_options.dart';
import '../widgets/edit_section_shell.dart';
import '../widgets/chip_selector.dart';

class RelationshipSection extends ConsumerWidget {
  const RelationshipSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(editProfileProvider).draft;

    void toggle(List<String> Function(dynamic d) getter, void Function(dynamic d, List<String> v) setter, String v) {
      ref.read(editProfileProvider.notifier).updateDraft((d) {
        final l = List<String>.from(getter(d));
        l.contains(v) ? l.remove(v) : l.add(v);
        setter(d, l);
        return d;
      });
    }

    return EditSectionShell(
      title: 'Relationship & Intent',
      description: 'What are you looking for? This helps us match you better.',
      saving: ref.watch(editProfileProvider).isSaving,
      onSave: () async {
        final ok = await ref.read(editProfileProvider.notifier).save();
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        children: [
          const SizedBox(height: AppSpacing.md),
          MultiChipSelector(label: 'What are you looking for?', options: ProfileOptions.lookingFor, selected: d.lookingFor,
            onToggle: (v) => toggle((d) => d.lookingFor, (d, l) => d.lookingFor = l, v)),
          const SizedBox(height: AppSpacing.xxl),
          MultiChipSelector(label: 'Relationship type', options: ProfileOptions.relationshipType, selected: d.relationshipType,
            onToggle: (v) => toggle((d) => d.relationshipType, (d, l) => d.relationshipType = l, v)),
          const SizedBox(height: AppSpacing.xxl),
          MultiChipSelector(label: 'Dating style', options: ProfileOptions.datingStyle, selected: d.datingStyle,
            onToggle: (v) => toggle((d) => d.datingStyle, (d, l) => d.datingStyle = l, v)),
          const SizedBox(height: AppSpacing.xxl),
          MultiChipSelector(label: 'Communication style', options: ProfileOptions.communicationStyle, selected: d.communicationStyle,
            onToggle: (v) => toggle((d) => d.communicationStyle, (d, l) => d.communicationStyle = l, v)),
          const SizedBox(height: AppSpacing.xxl),
          MultiChipSelector(label: 'First meet preference', options: ProfileOptions.firstMeetPreference, selected: d.firstMeetPreference,
            onToggle: (v) => toggle((d) => d.firstMeetPreference, (d, l) => d.firstMeetPreference = l, v)),
          const SizedBox(height: AppSpacing.xxl),
          MultiChipSelector(label: 'Love languages', options: ProfileOptions.loveLanguages, selected: d.loveLanguages,
            onToggle: (v) => toggle((d) => d.loveLanguages, (d, l) => d.loveLanguages = l, v)),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}
