import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../edit_profile_provider.dart';
import '../profile_options.dart';
import '../widgets/edit_section_shell.dart';
import '../widgets/chip_selector.dart';

class CultureSocialSection extends ConsumerWidget {
  const CultureSocialSection({super.key});

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
      title: 'Culture & Social',
      description: 'Your cultural tastes and social preferences.',
      saving: ref.watch(editProfileProvider).isSaving,
      onSave: () async {
        final ok = await ref.read(editProfileProvider.notifier).save();
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        children: [
          const SizedBox(height: AppSpacing.md),
          MultiChipSelector(label: 'Music', options: ProfileOptions.musicGenres, selected: d.musicGenres,
            onToggle: (v) => toggle((d) => d.musicGenres, (d, l) => d.musicGenres = l, v)),
          const SizedBox(height: AppSpacing.xxl),
          MultiChipSelector(label: 'Movies & Series', options: ProfileOptions.movieGenres, selected: d.movieGenres,
            onToggle: (v) => toggle((d) => d.movieGenres, (d, l) => d.movieGenres = l, v)),
          const SizedBox(height: AppSpacing.xxl),
          MultiChipSelector(label: 'Weekend style', options: ProfileOptions.weekendStyle, selected: d.weekendStyle,
            onToggle: (v) => toggle((d) => d.weekendStyle, (d, l) => d.weekendStyle = l, v)),
          const SizedBox(height: AppSpacing.xxl),
          MultiChipSelector(label: 'Humor style', options: ProfileOptions.humorStyle, selected: d.humorStyle,
            onToggle: (v) => toggle((d) => d.humorStyle, (d, l) => d.humorStyle = l, v)),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}
