import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../edit_profile_provider.dart';
import '../profile_options.dart';
import '../widgets/edit_section_shell.dart';
import '../widgets/chip_selector.dart';

class DigitalLifeSection extends ConsumerWidget {
  const DigitalLifeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(editProfileProvider).draft;

    return EditSectionShell(
      title: 'Digital Life',
      description: 'Your relationship with technology and the digital world.',
      saving: ref.watch(editProfileProvider).isSaving,
      onSave: () async {
        final ok = await ref.read(editProfileProvider.notifier).save();
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        children: [
          const SizedBox(height: AppSpacing.md),
          MultiChipSelector(label: 'AI tools you use', options: ProfileOptions.aiTools, selected: d.aiTools,
            onToggle: (v) => _toggle(ref, (d) => d.aiTools, (d, l) => d.aiTools = l, v)),
          const SizedBox(height: AppSpacing.xxl),
          SingleChipSelector(label: 'Social media usage', options: ProfileOptions.socialMediaUsage, selected: d.socialMediaUsage,
            onSelected: (v) => ref.read(editProfileProvider.notifier).updateDraft((d) { d.socialMediaUsage = d.socialMediaUsage == v ? null : v; return d; })),
          const SizedBox(height: AppSpacing.xxl),
          MultiChipSelector(label: 'Online communication style', options: ProfileOptions.onlineStyle, selected: d.onlineStyle,
            onToggle: (v) => _toggle(ref, (d) => d.onlineStyle, (d, l) => d.onlineStyle = l, v)),
          const SizedBox(height: AppSpacing.xxl),
          SingleChipSelector(label: 'Tech relationship', options: ProfileOptions.techRelation, selected: d.techRelation,
            onSelected: (v) => ref.read(editProfileProvider.notifier).updateDraft((d) { d.techRelation = d.techRelation == v ? null : v; return d; })),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  void _toggle(WidgetRef ref, List<String> Function(dynamic d) getter, void Function(dynamic d, List<String> v) setter, String v) {
    ref.read(editProfileProvider.notifier).updateDraft((d) {
      final l = List<String>.from(getter(d));
      l.contains(v) ? l.remove(v) : l.add(v);
      setter(d, l);
      return d;
    });
  }
}
