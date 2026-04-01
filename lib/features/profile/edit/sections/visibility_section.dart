import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../edit_profile_provider.dart';
import '../widgets/edit_section_shell.dart';

class VisibilitySection extends ConsumerWidget {
  const VisibilitySection({super.key});

  static const _fields = [
    ('age', 'Age', Icons.cake_outlined),
    ('city', 'City', Icons.location_on_outlined),
    ('religious_approach', 'Religion / Spirituality', Icons.self_improvement_outlined),
    ('wants_children', 'Children preference', Icons.child_care_outlined),
    ('smoking', 'Smoking', Icons.smoking_rooms_outlined),
    ('alcohol', 'Alcohol', Icons.local_bar_outlined),
    ('ai_tools', 'AI Tools', Icons.smart_toy_outlined),
    ('visited_countries', 'Countries visited', Icons.flight_outlined),
    ('secondary_role', 'Second profession', Icons.work_outline_rounded),
    ('looking_for', 'Looking for', Icons.favorite_outline_rounded),
  ];

  static const _options = ['Public', 'Matches only', 'Private'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(editProfileProvider).draft;

    return EditSectionShell(
      title: 'Privacy & Visibility',
      description: 'Control who can see each part of your profile.',
      saving: ref.watch(editProfileProvider).isSaving,
      onSave: () async {
        final ok = await ref.read(editProfileProvider.notifier).save();
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
        itemCount: _fields.length,
        itemBuilder: (_, i) {
          final (key, label, icon) = _fields[i];
          final current = d.visibility[key] ?? 'Public';

          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(color: context.borderColor, width: 0.5),
            ),
            child: Row(
              children: [
                Icon(icon, color: context.textMuted, size: 18),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(label, style: TextStyle(color: context.textPrimary, fontSize: 13))),
                DropdownButton<String>(
                  value: current,
                  dropdownColor: context.surfaceColor,
                  underline: const SizedBox.shrink(),
                  style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w500),
                  items: _options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    ref.read(editProfileProvider.notifier).updateDraft((d) {
                      final vis = Map<String, String>.from(d.visibility);
                      vis[key] = v;
                      d.visibility = vis;
                      return d;
                    });
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
