import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../edit_profile_provider.dart';
import '../profile_draft.dart';
import '../profile_options.dart';
import '../widgets/edit_section_shell.dart';
import '../widgets/chip_selector.dart';
import '../widgets/searchable_multi_select.dart';

class BasicInfoSection extends ConsumerStatefulWidget {
  const BasicInfoSection({super.key});
  @override
  ConsumerState<BasicInfoSection> createState() => _State();
}

class _State extends ConsumerState<BasicInfoSection> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _hometownCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  String? _zodiac;
  String? _education;
  bool _init = false;

  @override
  void dispose() {
    _nameCtrl.dispose(); _ageCtrl.dispose(); _heightCtrl.dispose();
    _cityCtrl.dispose(); _hometownCtrl.dispose(); _countryCtrl.dispose();
    super.dispose();
  }

  void _initFields() {
    if (_init) return; _init = true;
    final d = ref.read(editProfileProvider).draft;
    _nameCtrl.text = d.displayName;
    _ageCtrl.text = d.age?.toString() ?? '';
    _heightCtrl.text = d.height?.toString() ?? '';
    _cityCtrl.text = d.city ?? '';
    _hometownCtrl.text = d.hometown ?? '';
    _countryCtrl.text = d.country ?? '';
    _zodiac = d.zodiac;
    _education = d.educationLevel;
  }

  void _applyToProvider() {
    ref.read(editProfileProvider.notifier).updateDraft((d) {
      d.displayName = _nameCtrl.text.trim();
      d.age = int.tryParse(_ageCtrl.text.trim());
      d.height = int.tryParse(_heightCtrl.text.trim());
      d.city = _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim();
      d.hometown = _hometownCtrl.text.trim().isEmpty ? null : _hometownCtrl.text.trim();
      d.country = _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim();
      d.zodiac = _zodiac;
      d.educationLevel = _education;
      return d;
    });
  }

  @override
  Widget build(BuildContext context) {
    _initFields();
    final d = ref.watch(editProfileProvider).draft;

    return EditSectionShell(
      title: 'Basic Info',
      saving: ref.watch(editProfileProvider).isSaving,
      onSave: () async {
        _applyToProvider();
        final ok = await ref.read(editProfileProvider.notifier).save();
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        children: [
          const SizedBox(height: AppSpacing.md),
          EditField(label: 'Display name', controller: _nameCtrl),
          EditField(label: 'Age', controller: _ageCtrl, keyboardType: TextInputType.number),
          EditField(label: 'Height (cm)', controller: _heightCtrl, keyboardType: TextInputType.number),
          EditField(label: 'City', controller: _cityCtrl),
          EditField(label: 'Country', controller: _countryCtrl),
          EditField(label: 'Hometown / Origin', controller: _hometownCtrl),
          const SizedBox(height: AppSpacing.md),
          SingleChipSelector(label: 'Zodiac', options: ProfileOptions.zodiac, selected: _zodiac,
            onSelected: (v) => setState(() => _zodiac = _zodiac == v ? null : v)),
          const SizedBox(height: AppSpacing.lg),
          SingleChipSelector(label: 'Education', options: ProfileOptions.education, selected: _education,
            onSelected: (v) => setState(() => _education = _education == v ? null : v)),
          const SizedBox(height: AppSpacing.lg),
          // Languages
          SectionLabel('Languages (${d.languages.length})'),
          OutlinedButton.icon(
            icon: const Icon(Icons.translate_rounded, size: 16),
            label: Text(d.languages.isEmpty ? 'Add languages' : d.languages.map((l) => l.label).join(', ')),
            style: OutlinedButton.styleFrom(foregroundColor: context.textMuted, side: BorderSide(color: context.borderColor),
              minimumSize: const Size.fromHeight(44), alignment: Alignment.centerLeft),
            onPressed: () async {
              final current = d.languages.map((l) => l.label).toList();
              final result = await SearchableMultiSelectScreen.show(context,
                title: 'Languages',
                items: ProfileOptions.languages.map((l) => l.label).toList(),
                selected: current,
                searchHint: 'Search languages...',
              );
              if (result != null) {
                ref.read(editProfileProvider.notifier).updateDraft((d) {
                  d.languages = result.map((label) {
                    final opt = ProfileOptions.languages.firstWhere((l) => l.label == label, orElse: () => LangOption('', label));
                    return LanguageEntry(code: opt.code, label: label, level: 'Intermediate');
                  }).toList();
                  return d;
                });
              }
            },
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}
