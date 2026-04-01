import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../edit_profile_provider.dart';
import '../widgets/edit_section_shell.dart';

class AboutMeSection extends ConsumerStatefulWidget {
  const AboutMeSection({super.key});
  @override
  ConsumerState<AboutMeSection> createState() => _State();
}

class _State extends ConsumerState<AboutMeSection> {
  final _shortBioCtrl = TextEditingController();
  final _longBioCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _focusCtrl = TextEditingController();
  bool _init = false;

  @override
  void dispose() {
    _shortBioCtrl.dispose(); _longBioCtrl.dispose();
    _taglineCtrl.dispose(); _focusCtrl.dispose();
    super.dispose();
  }

  void _initFields() {
    if (_init) return; _init = true;
    final d = ref.read(editProfileProvider).draft;
    _shortBioCtrl.text = d.shortBio ?? '';
    _longBioCtrl.text = d.longBio ?? '';
    _taglineCtrl.text = d.tagline ?? '';
    _focusCtrl.text = d.currentFocus ?? '';
  }

  void _apply() {
    ref.read(editProfileProvider.notifier).updateDraft((d) {
      d.shortBio = _shortBioCtrl.text.trim().isEmpty ? null : _shortBioCtrl.text.trim();
      d.longBio = _longBioCtrl.text.trim().isEmpty ? null : _longBioCtrl.text.trim();
      d.tagline = _taglineCtrl.text.trim().isEmpty ? null : _taglineCtrl.text.trim();
      d.currentFocus = _focusCtrl.text.trim().isEmpty ? null : _focusCtrl.text.trim();
      return d;
    });
  }

  @override
  Widget build(BuildContext context) {
    _initFields();
    return EditSectionShell(
      title: 'About Me',
      description: 'Tell people who you are. Be authentic.',
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
          EditField(label: 'Short bio', controller: _shortBioCtrl, maxLength: 120, maxLines: 2),
          const SizedBox(height: AppSpacing.sm),
          EditField(label: 'Long bio', controller: _longBioCtrl, maxLength: 500, maxLines: 5),
          const SizedBox(height: AppSpacing.sm),
          EditField(label: 'Tagline — what describes you best', controller: _taglineCtrl, maxLength: 80),
          const SizedBox(height: AppSpacing.sm),
          EditField(label: 'Current focus in life', controller: _focusCtrl, maxLength: 120),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}
