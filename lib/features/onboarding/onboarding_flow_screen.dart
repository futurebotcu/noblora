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

// ═══════════════════════════════════════════════════════════════════
// Onboarding Flow — step-based premium setup
// Steps: Welcome → Basics → Modes → City → Photo → Bio → Privacy → Preferences → Complete
// ═══════════════════════════════════════════════════════════════════

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});
  @override
  ConsumerState<OnboardingFlowScreen> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlowScreen> {
  final _pageCtrl = PageController();
  int _step = 0;
  static const _totalSteps = 9;

  // Data collected
  final _nameCtrl = TextEditingController();
  int _age = 25;
  String _gender = 'female';
  String _city = '';
  final _bioCtrl = TextEditingController();
  String? _photoUrl;
  bool _datingActive = true;
  bool _bffActive = true;
  bool _socialActive = true;
  String _lookingFor = 'Serious relationship';
  int _ageMin = 20;
  int _ageMax = 40;

  @override
  void dispose() { _nameCtrl.dispose(); _bioCtrl.dispose(); _pageCtrl.dispose(); super.dispose(); }

  void _next() {
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
      _pageCtrl.animateToPage(_step, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.animateToPage(_step, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  /// Validate minimum requirements before allowing completion
  String? _validateCompletion() {
    if (_nameCtrl.text.trim().isEmpty) return 'Name is required';
    if (_datingActive && _photoUrl == null) return 'A photo is required for Dating mode';
    if (!_datingActive && !_bffActive && !_socialActive) return 'Select at least one mode';
    return null;
  }

  Future<void> _complete() async {
    // Final validation
    final error = _validateCompletion();
    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error));
      }
      return;
    }

    final uid = ref.read(authProvider).userId;
    if (uid == null) return;

    if (!isMockMode) {
      // Upload photo to Supabase Storage if local path exists
      String? remotePhotoUrl = _photoUrl;
      if (_photoUrl != null && !_photoUrl!.startsWith('http')) {
        try {
          final bytes = await XFile(_photoUrl!).readAsBytes();
          final path = 'avatars/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
          await Supabase.instance.client.storage.from('profile-photos').uploadBinary(path, bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'));
          remotePhotoUrl = Supabase.instance.client.storage.from('profile-photos').getPublicUrl(path);
        } catch (_) {
          // Upload failed — continue without photo
          remotePhotoUrl = null;
        }
      }

      await Supabase.instance.client.from('profiles').update({
        'full_name': _nameCtrl.text.trim(),
        'display_name': _nameCtrl.text.trim(),
        'age': _age,
        'gender': _gender,
        'city': _city,
        'bio': _bioCtrl.text.trim(),
        'date_avatar_url': remotePhotoUrl,
        'bff_avatar_url': remotePhotoUrl,
        'dating_active': _datingActive,
        'dating_visible': _datingActive,
        'bff_active': _bffActive,
        'bff_visible': _bffActive,
        'social_active': _socialActive,
        'social_visible': _socialActive,
        'looking_for': _lookingFor,
        'is_onboarded': true,
        // Privacy defaults (explicit, not null)
        'incognito_mode': false,
        'calm_mode': false,
        'show_city_only': false,
        'hide_exact_distance': false,
        'show_last_active': true,
        'show_status_badge': true,
        'reach_permission': 'everyone',
        'signal_permission': 'everyone',
        'note_permission': 'everyone',
        'message_preview': true,
        'active_modes': [
          if (_datingActive) 'date',
          if (_bffActive) 'bff',
          if (_socialActive) 'social',
        ],
      }).eq('id', uid);
    }

    // Refresh profile to trigger router re-evaluation
    await ref.read(profileProvider.notifier).createProfile(
      fullName: _nameCtrl.text.trim(),
      currentMode: _datingActive ? 'date' : (_bffActive ? 'bff' : 'social'),
    );
    await ref.read(profileProvider.notifier).updateGender(_gender);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0),
              child: Row(children: [
                if (_step > 0) IconButton(icon: Icon(Icons.arrow_back_rounded, color: context.textMuted, size: 20),
                    onPressed: _back, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                if (_step > 0) const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ClipRRect(borderRadius: BorderRadius.circular(1),
                    child: LinearProgressIndicator(value: (_step + 1) / _totalSteps, minHeight: 2,
                        backgroundColor: context.borderSubtleColor, valueColor: const AlwaysStoppedAnimation(AppColors.gold))),
                ),
              ]),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _WelcomePage(onNext: _next),
                  _BasicsPage(nameCtrl: _nameCtrl, age: _age, gender: _gender,
                      onAgeChanged: (v) => setState(() => _age = v),
                      onGenderChanged: (v) => setState(() => _gender = v),
                      onNext: _next),
                  _ModesPage(dating: _datingActive, bff: _bffActive, social: _socialActive,
                      onDating: (v) => setState(() => _datingActive = v),
                      onBff: (v) => setState(() => _bffActive = v),
                      onSocial: (v) => setState(() => _socialActive = v),
                      onNext: _next),
                  _CityPage(city: _city, onChanged: (v) => setState(() => _city = v), onNext: _next),
                  _PhotoPage(photoUrl: _photoUrl, onPhotoSelected: (v) => setState(() => _photoUrl = v), onNext: _next),
                  _BioPage(bioCtrl: _bioCtrl, onNext: _next),
                  _PrivacyPage(onNext: _next),
                  _PrefsPage(lookingFor: _lookingFor, ageMin: _ageMin, ageMax: _ageMax,
                      onLookingForChanged: (v) => setState(() => _lookingFor = v),
                      onAgeRangeChanged: (min, max) => setState(() { _ageMin = min; _ageMax = max; }),
                      onNext: _next),
                  _CompletePage(name: _nameCtrl.text, onComplete: _complete,
                      validationError: _validateCompletion()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Step pages
// ═══════════════════════════════════════════════════════════════════

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
        const Spacer(flex: 2),
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.gold.withValues(alpha: 0.06),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
          ),
          child: const Icon(Icons.diamond_outlined, color: AppColors.gold, size: 32),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        Text('Noblara', style: Theme.of(context).textTheme.displayMedium?.copyWith(
            color: context.textPrimary, fontWeight: FontWeight.w300, letterSpacing: 2)),
        const SizedBox(height: AppSpacing.lg),
        Text('A private space for\nmeaningful connections.',
            textAlign: TextAlign.center, style: TextStyle(color: context.textMuted, fontSize: 16, height: 1.6, letterSpacing: 0.2)),
        const Spacer(flex: 3),
        SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: context.bgColor,
                minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd))),
            onPressed: onNext, child: const Text('Begin', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: 0.5)))),
        const SizedBox(height: AppSpacing.xxxxl),
    ]));
  }
}

class _BasicsPage extends StatelessWidget {
  final TextEditingController nameCtrl; final int age; final String gender;
  final ValueChanged<int> onAgeChanged; final ValueChanged<String> onGenderChanged; final VoidCallback onNext;
  const _BasicsPage({required this.nameCtrl, required this.age, required this.gender,
      required this.onAgeChanged, required this.onGenderChanged, required this.onNext});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(AppSpacing.xxl), child: ListView(children: [
      const SizedBox(height: AppSpacing.xxxl),
      Text('About you', style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.xxl),
      TextField(controller: nameCtrl, style: TextStyle(color: context.textPrimary),
          decoration: _deco(context, 'Your name')),
      const SizedBox(height: AppSpacing.xxl),
      Text('Age: $age', style: TextStyle(color: context.textPrimary, fontSize: 14)),
      Slider(value: age.toDouble(), min: 18, max: 65, divisions: 47, activeColor: AppColors.gold,
          onChanged: (v) => onAgeChanged(v.round())),
      const SizedBox(height: AppSpacing.xxl),
      Text('Gender', style: TextStyle(color: context.textMuted, fontSize: 12)),
      const SizedBox(height: AppSpacing.sm),
      Wrap(spacing: 8, children: [
        _GChip('Woman', 'female', gender, onGenderChanged),
        _GChip('Man', 'male', gender, onGenderChanged),
        _GChip('Other', 'other', gender, onGenderChanged),
      ]),
      const SizedBox(height: AppSpacing.xxxl),
      ElevatedButton(onPressed: nameCtrl.text.trim().isNotEmpty ? onNext : null,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: context.bgColor,
              minimumSize: const Size.fromHeight(50)),
          child: const Text('Continue')),
    ]));
  }
}

class _GChip extends StatelessWidget {
  final String label; final String value; final String current; final ValueChanged<String> onChanged;
  const _GChip(this.label, this.value, this.current, this.onChanged);
  @override
  Widget build(BuildContext context) => ChoiceChip(label: Text(label), selected: current == value,
      selectedColor: AppColors.gold, backgroundColor: context.surfaceColor,
      labelStyle: TextStyle(color: current == value ? context.bgColor : context.textSecondary),
      onSelected: (_) => onChanged(value));
}

class _ModesPage extends StatelessWidget {
  final bool dating, bff, social;
  final ValueChanged<bool> onDating, onBff, onSocial; final VoidCallback onNext;
  const _ModesPage({required this.dating, required this.bff, required this.social,
      required this.onDating, required this.onBff, required this.onSocial, required this.onNext});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(AppSpacing.xxl), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: AppSpacing.xxxl),
        Text('How would you like to use Noblara?', style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.sm),
        Text('You can change these anytime in Settings.', style: TextStyle(color: context.textMuted, fontSize: 13)),
        const SizedBox(height: AppSpacing.xxl),
        _ModeToggle(Icons.favorite_rounded, 'Dating', 'Find meaningful connections', AppColors.gold, dating, onDating),
        _ModeToggle(Icons.people_rounded, 'BFF', 'Build your social circle', const Color(0xFF26C6DA), bff, onBff),
        _ModeToggle(Icons.explore_rounded, 'Social', 'Join real-life events', const Color(0xFFAB47BC), social, onSocial),
        const Spacer(),
        ElevatedButton(onPressed: (dating || bff || social) ? onNext : null,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: context.bgColor,
                minimumSize: const Size.fromHeight(50)),
            child: const Text('Continue')),
        const SizedBox(height: AppSpacing.xxl),
    ]));
  }
}

class _ModeToggle extends StatelessWidget {
  final IconData icon; final String title; final String sub; final Color color; final bool value; final ValueChanged<bool> onChanged;
  const _ModeToggle(this.icon, this.title, this.sub, this.color, this.value, this.onChanged);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    decoration: BoxDecoration(color: value ? color.withValues(alpha: 0.08) : context.surfaceColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: value ? color.withValues(alpha: 0.4) : context.borderColor)),
    child: ListTile(leading: Icon(icon, color: value ? color : context.textMuted),
        title: Text(title, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Text(sub, style: TextStyle(color: context.textMuted, fontSize: 12)),
        trailing: Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: color.withValues(alpha: 0.4))));
}

class _CityPage extends StatelessWidget {
  final String city; final ValueChanged<String> onChanged; final VoidCallback onNext;
  const _CityPage({required this.city, required this.onChanged, required this.onNext});
  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(text: city);
    return Padding(padding: const EdgeInsets.all(AppSpacing.xxl), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: AppSpacing.xxxl),
        Text('Where are you based?', style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.sm),
        Text('This helps us show people near you.', style: TextStyle(color: context.textMuted, fontSize: 13)),
        const SizedBox(height: AppSpacing.xxl),
        TextField(controller: ctrl, onChanged: onChanged, style: TextStyle(color: context.textPrimary),
            decoration: _deco(context, 'Your city (e.g. Istanbul)')),
        const Spacer(),
        ElevatedButton(onPressed: onNext,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: context.bgColor,
                minimumSize: const Size.fromHeight(50)),
            child: const Text('Continue')),
        const SizedBox(height: AppSpacing.xxl),
    ]));
  }
}

class _PhotoPage extends StatelessWidget {
  final String? photoUrl; final ValueChanged<String?> onPhotoSelected; final VoidCallback onNext;
  const _PhotoPage({required this.photoUrl, required this.onPhotoSelected, required this.onNext});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(AppSpacing.xxl), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: AppSpacing.xxxl),
        Text('Add a photo', style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.sm),
        Text('Your first impression matters. Pick a clear, recent photo.', style: TextStyle(color: context.textMuted, fontSize: 13)),
        const SizedBox(height: AppSpacing.xxl),
        Center(child: GestureDetector(
          onTap: () async {
            final picker = ImagePicker();
            final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
            if (img != null) {
              // In real: upload to Supabase Storage
              onPhotoSelected(img.path);
            }
          },
          child: Container(width: 160, height: 200,
            decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: photoUrl != null ? AppColors.gold : context.borderColor, width: photoUrl != null ? 2 : 1)),
            child: photoUrl != null
                ? ClipRRect(borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    child: Image.asset(photoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
                        const Center(child: Icon(Icons.check_rounded, color: AppColors.gold, size: 48))))
                : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_a_photo_rounded, color: context.textMuted, size: 32),
                    const SizedBox(height: 8),
                    Text('Tap to add', style: TextStyle(color: context.textMuted, fontSize: 12)),
                  ]))),
        )),
        const Spacer(),
        ElevatedButton(onPressed: onNext,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: context.bgColor,
                minimumSize: const Size.fromHeight(50)),
            child: Text(photoUrl != null ? 'Continue' : 'Skip for now')),
        const SizedBox(height: AppSpacing.xxl),
    ]));
  }
}

class _BioPage extends StatelessWidget {
  final TextEditingController bioCtrl; final VoidCallback onNext;
  const _BioPage({required this.bioCtrl, required this.onNext});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(AppSpacing.xxl), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: AppSpacing.xxxl),
        Text('Tell us about yourself', style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.sm),
        Text('A short bio helps others understand who you are.', style: TextStyle(color: context.textMuted, fontSize: 13)),
        const SizedBox(height: AppSpacing.xxl),
        TextField(controller: bioCtrl, maxLines: 4, maxLength: 300, style: TextStyle(color: context.textPrimary),
            decoration: _deco(context, 'Write something about yourself...')),
        const Spacer(),
        ElevatedButton(onPressed: onNext,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: context.bgColor,
                minimumSize: const Size.fromHeight(50)),
            child: Text(bioCtrl.text.trim().isNotEmpty ? 'Continue' : 'Skip for now')),
        const SizedBox(height: AppSpacing.xxl),
    ]));
  }
}

class _PrivacyPage extends StatelessWidget {
  final VoidCallback onNext;
  const _PrivacyPage({required this.onNext});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(AppSpacing.xxl), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: AppSpacing.xxxl),
        Text('Your privacy', style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.lg),
        _InfoCard(Icons.visibility_off_rounded, 'Incognito available', 'You can browse invisibly anytime from Settings.'),
        _InfoCard(Icons.shield_rounded, 'Calm Mode available', 'Only quality profiles can reach you when enabled.'),
        _InfoCard(Icons.lock_rounded, 'Private by default', 'Your activity, interests, and score are never public.'),
        _InfoCard(Icons.tune_rounded, 'Full control', 'Adjust who can signal, note, or reach you in Settings.'),
        const Spacer(),
        ElevatedButton(onPressed: onNext,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: context.bgColor,
                minimumSize: const Size.fromHeight(50)),
            child: const Text('Continue')),
        const SizedBox(height: AppSpacing.xxl),
    ]));
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon; final String title; final String sub;
  const _InfoCard(this.icon, this.title, this.sub);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: context.borderColor)),
    child: Row(children: [
      Icon(icon, color: AppColors.gold, size: 20),
      const SizedBox(width: AppSpacing.md),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        Text(sub, style: TextStyle(color: context.textMuted, fontSize: 12)),
      ])),
    ]));
}

class _PrefsPage extends StatelessWidget {
  final String lookingFor; final int ageMin; final int ageMax;
  final ValueChanged<String> onLookingForChanged;
  final void Function(int, int) onAgeRangeChanged; final VoidCallback onNext;
  const _PrefsPage({required this.lookingFor, required this.ageMin, required this.ageMax,
      required this.onLookingForChanged, required this.onAgeRangeChanged, required this.onNext});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(AppSpacing.xxl), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: AppSpacing.xxxl),
        Text('Your preferences', style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.sm),
        Text('Just enough to make your first experience meaningful.', style: TextStyle(color: context.textMuted, fontSize: 13)),
        const SizedBox(height: AppSpacing.xxl),
        Text('Looking for', style: TextStyle(color: context.textMuted, fontSize: 12)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(spacing: 6, runSpacing: 6, children: ['Serious relationship', 'Long-term', 'Intentional', 'Open'].map((o) =>
            ChoiceChip(label: Text(o), selected: lookingFor == o,
                selectedColor: AppColors.gold, backgroundColor: context.surfaceColor,
                labelStyle: TextStyle(color: lookingFor == o ? context.bgColor : context.textSecondary, fontSize: 12),
                onSelected: (_) => onLookingForChanged(o))).toList()),
        const SizedBox(height: AppSpacing.xxl),
        Text('Preferred age: $ageMin – $ageMax', style: TextStyle(color: context.textPrimary, fontSize: 14)),
        RangeSlider(values: RangeValues(ageMin.toDouble(), ageMax.toDouble()), min: 18, max: 65, divisions: 47,
            activeColor: AppColors.gold, onChanged: (v) => onAgeRangeChanged(v.start.round(), v.end.round())),
        const Spacer(),
        ElevatedButton(onPressed: onNext,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: context.bgColor,
                minimumSize: const Size.fromHeight(50)),
            child: const Text('Continue')),
        const SizedBox(height: AppSpacing.xxl),
    ]));
  }
}

class _CompletePage extends StatefulWidget {
  final String name; final Future<void> Function() onComplete; final String? validationError;
  const _CompletePage({required this.name, required this.onComplete, this.validationError});
  @override
  State<_CompletePage> createState() => _CompletePageState();
}

class _CompletePageState extends State<_CompletePage> {
  bool _loading = false;
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(AppSpacing.xxxl), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.check_circle_outline_rounded, color: AppColors.gold, size: 64),
        const SizedBox(height: AppSpacing.xxl),
        Text('You\'re all set${widget.name.isNotEmpty ? ', ${widget.name}' : ''}',
            style: TextStyle(color: context.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.md),
        Text(widget.validationError != null ? '' : 'Your private world is ready.',
            style: TextStyle(color: context.textMuted, fontSize: 14)),
        if (widget.validationError != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Container(padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
            child: Row(children: [
              const Icon(Icons.warning_rounded, color: AppColors.error, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.validationError!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
            ])),
        ],
        const SizedBox(height: AppSpacing.xxxxl),
        SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: widget.validationError != null ? context.textMuted : AppColors.gold,
                foregroundColor: context.bgColor, minimumSize: const Size.fromHeight(52)),
            onPressed: (_loading || widget.validationError != null) ? null : () async {
              setState(() => _loading = true);
              await widget.onComplete();
            },
            child: _loading
                ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: context.bgColor))
                : const Text('Enter Noblara', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)))),
    ]));
  }
}

// Shared decoration
InputDecoration _deco(BuildContext context, String hint) => InputDecoration(
  hintText: hint, hintStyle: TextStyle(color: context.textDisabled),
  filled: true, fillColor: context.surfaceColor,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm), borderSide: BorderSide(color: context.borderColor)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm), borderSide: BorderSide(color: context.borderColor)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm), borderSide: const BorderSide(color: AppColors.gold)),
);
