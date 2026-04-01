import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/mock_mode.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

// ---------------------------------------------------------------------------
// Edit Profile Screen — full profile editor
// ---------------------------------------------------------------------------

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _philosophyCtrl = TextEditingController();
  final _fromCountryCtrl = TextEditingController();
  final _countryTagCtrl = TextEditingController();

  String? _zodiac;
  String? _drinks;
  String? _smokes;
  String? _faith;
  String? _vibe;
  String? _lookingFor;
  List<String> _languages = [];
  List<String> _countriesVisited = [];
  List<String> _interests = [];
  List<String> _photoUrls = [];
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _cityCtrl.dispose();
    _occupationCtrl.dispose();
    _heightCtrl.dispose();
    _bioCtrl.dispose();
    _philosophyCtrl.dispose();
    _fromCountryCtrl.dispose();
    _countryTagCtrl.dispose();
    super.dispose();
  }

  void _initFromProfile() {
    if (_initialized) return;
    final p = ref.read(profileProvider).profile;
    if (p == null) return;
    _initialized = true;
    _nameCtrl.text = p.displayName;
    _ageCtrl.text = p.age?.toString() ?? '';
    _cityCtrl.text = p.city ?? '';
    _occupationCtrl.text = p.occupation ?? '';
    _heightCtrl.text = p.height?.toString() ?? '';
    _bioCtrl.text = p.bio ?? '';
    _philosophyCtrl.text = p.philosophy ?? '';
    _fromCountryCtrl.text = p.fromCountry ?? '';
    _zodiac = p.zodiac;
    _drinks = p.drinks;
    _smokes = p.smokes;
    _faith = p.faithSensitivity;
    _vibe = p.vibe;
    _lookingFor = p.lookingFor;
    _languages = List.from(p.languages);
    _countriesVisited = List.from(p.countriesVisited);
    _interests = List.from(p.interests);
    _photoUrls = List.from(p.photoUrls);
  }

  Future<void> _pickPhoto(int index) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (img == null) return;

    if (isMockMode) {
      setState(() {
        if (index < _photoUrls.length) {
          _photoUrls[index] = img.path;
        } else {
          _photoUrls.add(img.path);
        }
      });
      return;
    }

    final uid = ref.read(authProvider).userId;
    if (uid == null) return;

    try {
      final bytes = await img.readAsBytes();
      final path = 'avatars/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage.from('profile-photos').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );
      final url = Supabase.instance.client.storage.from('profile-photos').getPublicUrl(path);
      setState(() {
        if (index < _photoUrls.length) {
          _photoUrls[index] = url;
        } else {
          _photoUrls.add(url);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() => _photoUrls.removeAt(index));
  }

  Future<void> _save() async {
    final uid = ref.read(authProvider).userId;
    if (uid == null) return;

    setState(() => _saving = true);

    final updates = <String, dynamic>{
      'display_name': _nameCtrl.text.trim(),
      'bio': _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
      'city': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      'occupation': _occupationCtrl.text.trim().isEmpty ? null : _occupationCtrl.text.trim(),
      'philosophy': _philosophyCtrl.text.trim().isEmpty ? null : _philosophyCtrl.text.trim(),
      'from_country': _fromCountryCtrl.text.trim().isEmpty ? null : _fromCountryCtrl.text.trim(),
      'zodiac': _zodiac,
      'drinks': _drinks,
      'smokes': _smokes,
      'faith_sensitivity': _faith,
      'vibe': _vibe,
      'looking_for': _lookingFor,
      'languages': _languages,
      'countries_visited': _countriesVisited,
      'interests': _interests,
      'photo_urls': _photoUrls,
    };

    final ageText = _ageCtrl.text.trim();
    if (ageText.isNotEmpty) updates['age'] = int.tryParse(ageText);

    final heightText = _heightCtrl.text.trim();
    if (heightText.isNotEmpty) updates['height'] = int.tryParse(heightText);

    // Set first photo as avatar
    if (_photoUrls.isNotEmpty) {
      updates['date_avatar_url'] = _photoUrls.first;
      updates['bff_avatar_url'] = _photoUrls.first;
    }

    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.updateProfile(uid, updates);
      await ref.read(profileProvider.notifier).loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved'), backgroundColor: AppColors.gold),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _initFromProfile();

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit Profile', style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text('Save', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
        children: [
          // ═══ 1. PHOTOS ═══
          _SectionHeader('PHOTOS'),
          const SizedBox(height: AppSpacing.md),
          _PhotoGrid(
            photoUrls: _photoUrls,
            onPickPhoto: _pickPhoto,
            onRemovePhoto: _removePhoto,
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // ═══ 2. BASICS ═══
          _SectionHeader('BASICS'),
          const SizedBox(height: AppSpacing.md),
          _Field(label: 'Display name', controller: _nameCtrl),
          _Field(label: 'Age', controller: _ageCtrl, keyboardType: TextInputType.number),
          _Field(label: 'City', controller: _cityCtrl),
          _Field(label: 'Occupation', controller: _occupationCtrl),
          _Field(label: 'Height (cm)', controller: _heightCtrl, keyboardType: TextInputType.number),
          _DropdownField(
            label: 'Zodiac',
            value: _zodiac,
            options: const ['Aries','Taurus','Gemini','Cancer','Leo','Virgo','Libra','Scorpio','Sagittarius','Capricorn','Aquarius','Pisces'],
            onChanged: (v) => setState(() => _zodiac = v),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // ═══ 3. ABOUT ═══
          _SectionHeader('ABOUT'),
          const SizedBox(height: AppSpacing.md),
          _MultilineField(label: 'Bio', controller: _bioCtrl, maxLength: 300),
          const SizedBox(height: AppSpacing.md),
          _MultilineField(label: 'Philosophy / Quote', controller: _philosophyCtrl, maxLength: 200),

          const SizedBox(height: AppSpacing.xxxl),

          // ═══ 4. LIFESTYLE ═══
          _SectionHeader('LIFESTYLE'),
          const SizedBox(height: AppSpacing.md),
          _ChipSelector(
            label: 'Drinks',
            options: const ['Never', 'Rarely', 'Socially', 'Often'],
            selected: _drinks,
            onSelected: (v) => setState(() => _drinks = _drinks == v ? null : v),
          ),
          const SizedBox(height: AppSpacing.lg),
          _ChipSelector(
            label: 'Smokes',
            options: const ['Never', 'Sometimes', 'Often'],
            selected: _smokes,
            onSelected: (v) => setState(() => _smokes = _smokes == v ? null : v),
          ),
          const SizedBox(height: AppSpacing.lg),
          _ChipSelector(
            label: 'Faith',
            options: const ['Not important', 'Somewhat', 'Important'],
            selected: _faith,
            onSelected: (v) => setState(() => _faith = _faith == v ? null : v),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // ═══ 5. BACKGROUND ═══
          _SectionHeader('BACKGROUND'),
          const SizedBox(height: AppSpacing.md),
          _MultiChipSelector(
            label: 'Languages',
            options: const ['EN','TR','FR','DE','ES','IT','AR','RU','JA','ZH'],
            selected: _languages,
            onToggle: (v) => setState(() {
              _languages.contains(v) ? _languages.remove(v) : _languages.add(v);
            }),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Field(label: 'From country', controller: _fromCountryCtrl),
          const SizedBox(height: AppSpacing.sm),
          _TagInput(
            label: 'Countries visited',
            tags: _countriesVisited,
            controller: _countryTagCtrl,
            onAdd: (v) => setState(() => _countriesVisited.add(v)),
            onRemove: (v) => setState(() => _countriesVisited.remove(v)),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // ═══ 6. INTERESTS ═══
          _SectionHeader('INTERESTS'),
          const SizedBox(height: AppSpacing.md),
          _MultiChipSelector(
            label: null,
            options: const [
              'Reading','Coffee','Walking','Gym','Running','Coding','Design','Startups',
              'Gaming','Museums','Travel','Writing','Language','Nature','Music','Art',
              'Film','Food','Photography','Architecture','Philosophy',
            ],
            selected: _interests,
            onToggle: (v) => setState(() {
              _interests.contains(v) ? _interests.remove(v) : _interests.add(v);
            }),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // ═══ 7. VIBE ═══
          _SectionHeader('VIBE'),
          const SizedBox(height: AppSpacing.md),
          _ChipSelector(
            label: null,
            options: const ['Calm','Reflective','Social','Grounded','Structured','Curious','Creative','Playful'],
            selected: _vibe,
            onSelected: (v) => setState(() => _vibe = _vibe == v ? null : v),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // ═══ 8. LOOKING FOR ═══
          _SectionHeader('LOOKING FOR'),
          const SizedBox(height: AppSpacing.md),
          _ChipSelector(
            label: null,
            options: const ['Serious','Long-term','Intentional','Open'],
            selected: _lookingFor,
            onSelected: (v) => setState(() => _lookingFor = _lookingFor == v ? null : v),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          // ═══ SAVE BUTTON ═══
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          const SizedBox(height: AppSpacing.xxxxl),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Photo Grid — 6 slots, 3 columns
// ═══════════════════════════════════════════════════════════════════════════════

class _PhotoGrid extends StatelessWidget {
  final List<String> photoUrls;
  final void Function(int index) onPickPhoto;
  final void Function(int index) onRemovePhoto;

  const _PhotoGrid({
    required this.photoUrls,
    required this.onPickPhoto,
    required this.onRemovePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: 6,
      itemBuilder: (context, i) {
        final hasPhoto = i < photoUrls.length && photoUrls[i].isNotEmpty;
        if (hasPhoto) {
          return GestureDetector(
            onTap: () => _showRemoveDialog(context, i),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: Image.network(
                    photoUrls[i],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: context.surfaceColor,
                      child: Icon(Icons.broken_image_rounded, color: context.textDisabled),
                    ),
                  ),
                ),
                if (i == 0)
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Main', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          );
        }

        return GestureDetector(
          onTap: () => onPickPhoto(i),
          child: Container(
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: context.borderColor, width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined, color: context.textMuted, size: 28),
                const SizedBox(height: 4),
                Text('Add', style: TextStyle(color: context.textMuted, fontSize: 11)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRemoveDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Remove photo?', style: TextStyle(color: context.textPrimary, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: context.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onRemovePhoto(index);
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared form widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: context.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;

  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: context.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: context.textMuted, fontSize: 13),
          filled: true,
          fillColor: context.surfaceColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: BorderSide(color: context.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: BorderSide(color: context.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: const BorderSide(color: AppColors.gold),
          ),
        ),
      ),
    );
  }
}

class _MultilineField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLength;

  const _MultilineField({
    required this.label,
    required this.controller,
    required this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: 4,
      style: TextStyle(color: context.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.textMuted, fontSize: 13),
        alignLabelWithHint: true,
        filled: true,
        fillColor: context.surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterStyle: TextStyle(color: context.textDisabled, fontSize: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: context.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: context.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        dropdownColor: context.surfaceColor,
        style: TextStyle(color: context.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: context.textMuted, fontSize: 13),
          filled: true,
          fillColor: context.surfaceColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: BorderSide(color: context.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: BorderSide(color: context.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: const BorderSide(color: AppColors.gold),
          ),
        ),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _ChipSelector extends StatelessWidget {
  final String? label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _ChipSelector({
    this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: AppSpacing.sm),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final active = selected == o;
            return GestureDetector(
              onTap: () => onSelected(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.gold.withValues(alpha: 0.12) : context.surfaceColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
                  border: Border.all(
                    color: active ? AppColors.gold.withValues(alpha: 0.5) : context.borderColor,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  o,
                  style: TextStyle(
                    color: active ? AppColors.gold : context.textMuted,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _MultiChipSelector extends StatelessWidget {
  final String? label;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  const _MultiChipSelector({
    this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: AppSpacing.sm),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final active = selected.contains(o);
            return GestureDetector(
              onTap: () => onToggle(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.gold.withValues(alpha: 0.12) : context.surfaceColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
                  border: Border.all(
                    color: active ? AppColors.gold.withValues(alpha: 0.5) : context.borderColor,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  o,
                  style: TextStyle(
                    color: active ? AppColors.gold : context.textMuted,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _TagInput extends StatelessWidget {
  final String label;
  final List<String> tags;
  final TextEditingController controller;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  const _TagInput({
    required this.label,
    required this.tags,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: AppSpacing.sm),
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.map((t) => Chip(
                label: Text(t, style: TextStyle(color: context.textPrimary, fontSize: 12)),
                deleteIcon: Icon(Icons.close, size: 14, color: context.textMuted),
                onDeleted: () => onRemove(t),
                backgroundColor: context.surfaceColor,
                side: BorderSide(color: context.borderColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusCircle)),
              )).toList(),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: TextStyle(color: context.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Add country...',
                  hintStyle: TextStyle(color: context.textDisabled, fontSize: 13),
                  filled: true,
                  fillColor: context.surfaceColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    borderSide: BorderSide(color: context.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    borderSide: BorderSide(color: context.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    borderSide: const BorderSide(color: AppColors.gold),
                  ),
                ),
                onSubmitted: (v) {
                  final trimmed = v.trim();
                  if (trimmed.isNotEmpty && !tags.contains(trimmed)) {
                    onAdd(trimmed);
                    controller.clear();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                final v = controller.text.trim();
                if (v.isNotEmpty && !tags.contains(v)) {
                  onAdd(v);
                  controller.clear();
                }
              },
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.gold),
            ),
          ],
        ),
      ],
    );
  }
}
