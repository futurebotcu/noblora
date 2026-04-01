import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../edit_profile_provider.dart';
import '../profile_options.dart';
import '../widgets/edit_section_shell.dart';
import '../widgets/chip_selector.dart';

class CareerSection extends ConsumerStatefulWidget {
  const CareerSection({super.key});
  @override
  ConsumerState<CareerSection> createState() => _State();
}

class _State extends ConsumerState<CareerSection> {
  final _primaryCtrl = TextEditingController();
  final _secondaryCtrl = TextEditingController();
  bool _init = false;

  @override
  void dispose() { _primaryCtrl.dispose(); _secondaryCtrl.dispose(); super.dispose(); }

  void _initFields() {
    if (_init) return; _init = true;
    final d = ref.read(editProfileProvider).draft;
    _primaryCtrl.text = d.primaryRole ?? '';
    _secondaryCtrl.text = d.secondaryRole ?? '';
  }

  void _apply() {
    ref.read(editProfileProvider.notifier).updateDraft((d) {
      d.primaryRole = _primaryCtrl.text.trim().isEmpty ? null : _primaryCtrl.text.trim();
      d.secondaryRole = _secondaryCtrl.text.trim().isEmpty ? null : _secondaryCtrl.text.trim();
      return d;
    });
  }

  @override
  Widget build(BuildContext context) {
    _initFields();
    final d = ref.watch(editProfileProvider).draft;

    return EditSectionShell(
      title: 'Career & Building',
      description: 'What you do and what you are building.',
      saving: ref.watch(editProfileProvider).isSaving,
      onSave: () async {
        _apply();
        final ok = await ref.read(editProfileProvider.notifier).save();
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        children: [
          const SizedBox(height: AppSpacing.md),
          EditField(label: 'Primary role / profession', controller: _primaryCtrl),
          EditField(label: 'Secondary role (optional)', controller: _secondaryCtrl),
          const SizedBox(height: AppSpacing.md),
          SingleChipSelector(label: 'Work style', options: ProfileOptions.workStyle, selected: d.workStyle,
            onSelected: (v) => _u((d) => d.workStyle = d.workStyle == v ? null : v)),
          const SizedBox(height: AppSpacing.xxl),
          SingleChipSelector(label: 'Entrepreneurship', options: ProfileOptions.entrepreneurshipStatus, selected: d.entrepreneurshipStatus,
            onSelected: (v) => _u((d) => d.entrepreneurshipStatus = d.entrepreneurshipStatus == v ? null : v)),
          const SizedBox(height: AppSpacing.xxl),
          MultiChipSelector(label: 'Currently building', options: ProfileOptions.buildingNow, selected: d.buildingNow,
            onToggle: (v) => _u((d) { final l = List<String>.from(d.buildingNow); l.contains(v) ? l.remove(v) : l.add(v); d.buildingNow = l; })),
          const SizedBox(height: AppSpacing.xxl),
          SingleChipSelector(label: 'Work intensity', options: ProfileOptions.workIntensity, selected: d.workIntensity,
            onSelected: (v) => _u((d) => d.workIntensity = d.workIntensity == v ? null : v)),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  void _u(void Function(dynamic d) fn) {
    ref.read(editProfileProvider.notifier).updateDraft((d) { fn(d); return d; });
  }
}
