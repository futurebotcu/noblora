import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../edit_profile_provider.dart';
import '../profile_options.dart';
import '../widgets/edit_section_shell.dart';
import '../widgets/chip_selector.dart';
import '../widgets/searchable_multi_select.dart';

class TravelSection extends ConsumerWidget {
  const TravelSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(editProfileProvider).draft;

    Future<void> selectCountries(String title, List<String> current, void Function(List<String>) onDone) async {
      final result = await SearchableMultiSelectScreen.show(context,
        title: title, items: ProfileOptions.countries, selected: current, searchHint: 'Search countries...');
      if (result != null) onDone(result);
    }

    return EditSectionShell(
      title: 'Travel & World',
      description: 'Share your travel experience and dreams.',
      saving: ref.watch(editProfileProvider).isSaving,
      onSave: () async {
        final ok = await ref.read(editProfileProvider.notifier).save();
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        children: [
          const SizedBox(height: AppSpacing.md),
          _CountryButton(label: 'Countries visited', count: d.visitedCountries.length, onTap: () =>
            selectCountries('Countries Visited', d.visitedCountries, (r) =>
              ref.read(editProfileProvider.notifier).updateDraft((d) { d.visitedCountries = r; return d; }))),
          const SizedBox(height: AppSpacing.md),
          _CountryButton(label: 'Countries lived in', count: d.livedCountries.length, onTap: () =>
            selectCountries('Countries Lived In', d.livedCountries, (r) =>
              ref.read(editProfileProvider.notifier).updateDraft((d) { d.livedCountries = r; return d; }))),
          const SizedBox(height: AppSpacing.md),
          _CountryButton(label: 'Wishlist countries', count: d.wishlistCountries.length, onTap: () =>
            selectCountries('Wishlist Countries', d.wishlistCountries, (r) =>
              ref.read(editProfileProvider.notifier).updateDraft((d) { d.wishlistCountries = r; return d; }))),
          const SizedBox(height: AppSpacing.xxl),
          MultiChipSelector(label: 'Travel style', options: ProfileOptions.travelStyle, selected: d.travelStyle,
            onToggle: (v) => ref.read(editProfileProvider.notifier).updateDraft((d) {
              final l = List<String>.from(d.travelStyle); l.contains(v) ? l.remove(v) : l.add(v); d.travelStyle = l; return d;
            })),
          const SizedBox(height: AppSpacing.xxl),
          SingleChipSelector(label: 'Open to relocate?', options: ProfileOptions.relocationOpenness, selected: d.relocationOpenness,
            onSelected: (v) => ref.read(editProfileProvider.notifier).updateDraft((d) { d.relocationOpenness = d.relocationOpenness == v ? null : v; return d; })),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _CountryButton extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback onTap;
  const _CountryButton({required this.label, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: context.textPrimary, side: BorderSide(color: context.borderColor),
        minimumSize: const Size.fromHeight(48), alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
      ),
      child: Row(children: [
        Icon(Icons.public_rounded, size: 18, color: context.textMuted),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        if (count > 0) Text('$count', style: TextStyle(color: context.textMuted, fontSize: 12)),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right_rounded, size: 18, color: context.textMuted),
      ]),
    );
  }
}
