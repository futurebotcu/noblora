import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/toast_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/premium.dart';
import '../../core/utils/mock_mode.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/storage_provider.dart';
import '../../shared/widgets/drum_date_picker.dart';
import '../../shared/widgets/city_search_screen.dart';

// ═══════════════════════════════════════════════════════════════════
// Onboarding Flow — step-based premium setup
//
// V1 final cleanup (2026-05-13):
//   - Removed the R13 Info step (TH/VN/PH flag-row intro); SEA scope
//     is now communicated through Welcome + product positioning, not a
//     mandatory ack screen.
//   - Location step is manual-only: the "Use my location" GPS button +
//     5 LocationStatus error branches were deleted along with the
//     location_service.dart dependency. Manual city search remains.
//   - Photo step is photo-upload-only: the AvatarPicker grid (50
//     custom-painted warrior avatars) was deleted; users must pick a
//     real photo, no fallback avatar.
//
// Current step order (7): Welcome -> Basics -> Occupation -> Location
//                          -> Photo -> Privacy -> Complete
// ═══════════════════════════════════════════════════════════════════

String? _detectImageType(List<int> bytes) {
  if (bytes.length < 4) return null;
  // JPEG: FF D8 FF
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return 'image/jpeg';
  // PNG: 89 50 4E 47
  if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'image/png';
  // WebP: RIFF....WEBP
  if (bytes.length >= 12 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 && bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) return 'image/webp';
  return null;
}

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});
  @override
  ConsumerState<OnboardingFlowScreen> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlowScreen> {
  final _pageCtrl = PageController();
  int _step = 0;
  // V1 final cleanup: was 8 (with R13 Info step); now 7 after removing
  // the flag-row info screen.
  static const _totalSteps = 7;

  // Data collected
  final _nameCtrl = TextEditingController();
  int _age = 25;
  int? _birthDay;
  int? _birthMonth;
  int? _birthYear;
  String _gender = 'female';
  String _occupation = '';
  String _city = '';
  String _country = '';
  // R13 — ISO 2-letter (TH/VN/PH or other) from manual city search.
  // `_country` is the full name (e.g. "Thailand"); `_countryCode` is the
  // ISO code expected by the swipe-gate. They are decoupled because the
  // CitySearchScreen callback returns both, but historically only
  // `_country` was persisted (separate ISO normalization bug tracked in
  // TRAVEL_LOCATION_REALITY_AUDIT.md).
  String? _countryCode;
  // V1 final cleanup: photo is now mandatory (no avatar fallback). The
  // _avatarId state + AvatarPicker grid were deleted along with the
  // avatar_picker widget.
  String? _photoUrl;

  @override
  void dispose() { _nameCtrl.dispose(); _pageCtrl.dispose(); super.dispose(); }

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

  /// Validate minimum requirements before allowing completion.
  /// V1 final cleanup: photo became mandatory (was photo OR avatar).
  String? _validateCompletion() {
    if (_nameCtrl.text.trim().isEmpty) return 'Name is required';
    if (_photoUrl == null) return 'A photo is required';
    return null;
  }

  /// Persist the onboarding draft to Supabase, then refresh the local
  /// profile provider so AppRouter can re-evaluate and advance to
  /// MainTabNavigator.
  ///
  /// Throws when the DB save retries are exhausted — the caller's
  /// CompletePage catch shows a retryable error and resets the loading
  /// state. Previously the function swallowed save failures, then went
  /// on to call createProfile/updateGender (which also failed silently
  /// because there was no row to refresh from), leaving the user stuck
  /// on the "You're all set" spinner with no path forward.
  Future<void> _complete() async {
    // Final validation
    final error = _validateCompletion();
    if (error != null) {
      if (mounted) {
        ToastService.show(context, message: error, type: ToastType.error);
      }
      throw Exception(error);
    }

    final uid = ref.read(authProvider).userId;
    if (uid == null) {
      throw Exception('Not signed in. Please sign in again to finish setup.');
    }

    if (!isMockMode) {
      // Upload photo to Supabase Storage if local path exists
      String? remotePhotoUrl = _photoUrl;
      if (_photoUrl != null && !_photoUrl!.startsWith('http')) {
        try {
          final bytes = await XFile(_photoUrl!).readAsBytes();
          // Validate size (max 10MB)
          if (bytes.length > 10 * 1024 * 1024) {
            if (mounted) {
              ToastService.show(context, message: 'Photo is too large (10 MB max)', type: ToastType.error);
            }
            remotePhotoUrl = null;
          } else {
            final contentType = _detectImageType(bytes) ?? 'image/jpeg';
            final path = 'avatars/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
            remotePhotoUrl = await ref.read(storageRepositoryProvider).uploadProfilePhoto(
              path: path,
              bytes: bytes,
              contentType: contentType,
            );
          }
        } catch (e) {
          debugPrint('Onboarding photo upload error: $e');
          remotePhotoUrl = null;
          if (mounted) {
            ToastService.show(context, message: 'Photo upload failed. Your profile will use the selected avatar instead.', type: ToastType.error);
          }
        }
      }

      // Retry DB save up to 2 times — abort the whole flow if exhausted
      // (caller's catch surfaces a retryable error). Previously the loop
      // silently fell through and the cascading createProfile call
      // covered up the real problem.
      Object? lastError;
      var saved = false;
      for (var attempt = 0; attempt < 2 && !saved; attempt++) {
        try {
          await ref.read(profileRepositoryProvider).updateProfile(uid, {
            'full_name': _nameCtrl.text.trim(),
            'display_name': _nameCtrl.text.trim(),
            'age': _age,
            'gender': _gender,
            // Onboarding location is optional — manual city fallback may
            // leave _city empty. Send null instead of '' so a NOT NULL
            // column doesn't blow up and an empty NOT NULL string doesn't
            // get persisted; the user can fill it from Profile Edit later.
            if (_city.isNotEmpty) 'city': _city,
            if (_country.isNotEmpty) 'country': _country,
            // R16 — `location_lat` / `location_lng` columns do NOT exist on
            // public.profiles (verified via information_schema; the only
            // migration that ever declared them was 20260401000002_social_events
            // on the events table, dropped 2026-05-04). Sending them caused
            // a 400 on every onboarding save since the file was written —
            // see R16_ROOT_CAUSE_AUDIT_REPORT.md and api logs at
            // 2026-05-11 15:35:38–39. The local lat/lng vars were also
            // removed.
            'bio': '',
            'date_avatar_url': remotePhotoUrl,
            'dating_active': true,
            'dating_visible': true,
            // R18 — `bff_avatar_url`, `bff_active`, `bff_visible` writes
            // removed (BFF pulled from V1). DB columns untouched.
            'looking_for': 'Serious relationship',
            // R-new(occupation-typo) — DB column is `occupation`; the prior
            // key `'profession'` PATCH'd a non-existent column and PostgREST
            // returned 42703 -> HTTP 400, surfacing as "We couldn't save
            // your profile" on the onboarding completion step. Verified via
            // SELECT profession FROM profiles -> ERROR 42703 (2026-05-13).
            if (_occupation.isNotEmpty) 'occupation': _occupation,
            // V1 final cleanup: avatar_id payload key removed alongside
            // the AvatarPicker UI; legacy DB column kept untouched.
            'is_onboarded': true,
            // Privacy defaults (explicit, not null)
            'incognito_mode': false,
            'calm_mode': false,
            'show_last_active': true,
            'show_status_badge': true,
            'reach_permission': 'everyone',
            'signal_permission': 'everyone',
            'note_permission': 'everyone',
            'message_preview': true,
            // R18 — 'bff' removed from active_modes; V1 only persists 'date'
            // (plus 'social' when kSocialEnabled flips on in a future build).
            'active_modes': kSocialEnabled ? ['date', 'social'] : ['date'],
          });
          saved = true;
        } catch (e) {
          lastError = e;
          debugPrint('Onboarding DB update error (attempt ${attempt + 1}): $e');
        }
      }

      if (!saved) {
        throw Exception(
          'Profile save failed: ${lastError ?? 'unknown'}',
        );
      }
    }

    // Refresh profile to trigger router re-evaluation. After a successful
    // save these calls should succeed — if they don't, surface the error
    // instead of proceeding with a partial state that would leave the
    // user stuck on the spinner.
    await ref.read(profileProvider.notifier).createProfile(
      fullName: _nameCtrl.text.trim(),
      currentMode: 'date',
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
                  child: ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: (_step + 1) / _totalSteps, minHeight: 3,
                        backgroundColor: context.borderSubtleColor, valueColor: AlwaysStoppedAnimation(context.accent))),
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
                  // V1 final cleanup: OnboardingInfoStep (TH/VN/PH flag
                  // intro) removed; SEA scope communicated via Welcome
                  // copy + product positioning rather than a mandatory
                  // ack screen.
                  _BasicsPage(
                      nameCtrl: _nameCtrl,
                      birthDay: _birthDay, birthMonth: _birthMonth, birthYear: _birthYear,
                      gender: _gender,
                      onBirthChanged: (d, m, y, age) => setState(() { _birthDay = d; _birthMonth = m; _birthYear = y; _age = age; }),
                      onGenderChanged: (v) => setState(() => _gender = v),
                      onNext: _next),
                  _OccupationPage(
                      occupation: _occupation,
                      onChanged: (v) => setState(() => _occupation = v),
                      onNext: _next),
                  _LocationPage(
                      city: _city,
                      country: _country,
                      countryCode: _countryCode,
                      onLocationSet: (city, country, lat, lng) => setState(() {
                        _city = city; _country = country;
                        // lat/lng intentionally dropped — R16; profiles
                        // table has no columns for them.
                      }),
                      onCountryCodeSet: (code) => setState(() => _countryCode = code),
                      onNext: _next),
                  _PhotoPage(
                      photoUrl: _photoUrl,
                      onPhotoSelected: (v) => setState(() => _photoUrl = v),
                      onNext: _next),
                  _PrivacyPage(onNext: _next),
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
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [context.accent.withValues(alpha: 0.12), context.accent.withValues(alpha: 0.04)],
            ),
            border: Border.all(color: context.accent.withValues(alpha: 0.20), width: 0.5),
            boxShadow: [
              ...Premium.emeraldGlow(intensity: 0.6),
              ...Premium.shadowMd,
            ],
          ),
          child: Icon(Icons.diamond_outlined, color: context.accent, size: 34),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        Text('Noblara', style: Theme.of(context).textTheme.displayMedium?.copyWith(
            color: context.textPrimary, fontWeight: FontWeight.w300, letterSpacing: 4)),
        const SizedBox(height: AppSpacing.lg),
        Text('A private space for\nmeaningful connections.',
            textAlign: TextAlign.center, style: TextStyle(color: context.textMuted, fontSize: 16, height: 1.6, letterSpacing: 0.2)),
        const Spacer(flex: 3),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            boxShadow: Premium.emeraldGlow(intensity: 0.7),
          ),
          child: ElevatedButton(
              onPressed: onNext, child: const Text('Begin', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: 0.5))),
        ),
        const SizedBox(height: AppSpacing.xxxxl),
    ]));
  }
}

class _BasicsPage extends StatefulWidget {
  final TextEditingController nameCtrl;
  final int? birthDay, birthMonth, birthYear;
  final String gender;
  final void Function(int d, int m, int y, int age) onBirthChanged;
  final ValueChanged<String> onGenderChanged;
  final VoidCallback onNext;
  const _BasicsPage({required this.nameCtrl, this.birthDay, this.birthMonth, this.birthYear,
      required this.gender, required this.onBirthChanged,
      required this.onGenderChanged, required this.onNext});
  @override
  State<_BasicsPage> createState() => _BasicsPageState();
}

class _BasicsPageState extends State<_BasicsPage> {

  int? get _calcAge {
    if (widget.birthDay == null || widget.birthMonth == null || widget.birthYear == null) return null;
    final now = DateTime.now();
    int age = now.year - widget.birthYear!;
    if (now.month < widget.birthMonth! || (now.month == widget.birthMonth! && now.day < widget.birthDay!)) age--;
    return age;
  }

  bool get _canContinue =>
      widget.nameCtrl.text.trim().length >= 2 &&
      _calcAge != null && _calcAge! >= 18 &&
      widget.gender.isNotEmpty;

  static const _months = ['January','February','March','April','May','June','July','August','September','October','November','December'];

  @override
  Widget build(BuildContext context) {
    final age = _calcAge;
    final ageInvalid = age != null && age < 18;
    final now = DateTime.now();

    return Padding(padding: const EdgeInsets.all(AppSpacing.xxl), child: ListView(children: [
      const SizedBox(height: AppSpacing.xxl),
      Text('About You', style: TextStyle(color: context.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
      const SizedBox(height: AppSpacing.xs),
      Text('Help others know the real you', style: TextStyle(color: context.textMuted, fontSize: 14)),
      const SizedBox(height: AppSpacing.xxxl),

      // Name
      TextField(controller: widget.nameCtrl, style: TextStyle(color: context.textPrimary),
          onChanged: (_) => setState(() {}),
          decoration: _deco(context, 'Your name')),
      if (widget.nameCtrl.text.isNotEmpty && widget.nameCtrl.text.trim().length < 2)
        Padding(padding: const EdgeInsets.only(top: 4),
            child: Text('Name must be at least 2 characters', style: TextStyle(color: AppColors.error, fontSize: 12))),
      const SizedBox(height: AppSpacing.xxl),

      // Date of Birth — 3D Drum Picker
      Text('Date of Birth', style: TextStyle(color: context.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
      const SizedBox(height: AppSpacing.sm),
      DrumDatePicker(
        day: widget.birthDay,
        month: widget.birthMonth,
        year: widget.birthYear,
        onChanged: (d, m, y) {
          widget.onBirthChanged(d, m, y, _calcAgeFrom(d, m, y));
        },
      ),
      if (age != null) ...[
        const SizedBox(height: AppSpacing.sm),
        Center(child: Text(
          '${_months[(widget.birthMonth ?? 1) - 1]} ${widget.birthDay ?? 1}, ${widget.birthYear ?? now.year - 25} · $age years old',
          style: TextStyle(color: ageInvalid ? AppColors.error : AppColors.emerald500, fontSize: 14, fontWeight: FontWeight.w600),
        )),
      ],
      if (ageInvalid)
        Padding(padding: const EdgeInsets.only(top: 4),
            child: Center(child: Text('You must be at least 18', style: TextStyle(color: AppColors.error, fontSize: 12)))),
      const SizedBox(height: AppSpacing.xxl),

      // Gender — 2 options
      Text('Gender', style: TextStyle(color: context.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
      const SizedBox(height: AppSpacing.sm),
      Row(children: [
        _GenderCard('Man', 'male', Icons.male_rounded, widget.gender, widget.onGenderChanged),
        const SizedBox(width: 12),
        _GenderCard('Woman', 'female', Icons.female_rounded, widget.gender, widget.onGenderChanged),
      ]),
      const SizedBox(height: AppSpacing.xxxl),
      ElevatedButton(onPressed: _canContinue ? widget.onNext : null,
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Continue')),
      const SizedBox(height: AppSpacing.xxl),
    ]));
  }

  int _calcAgeFrom(int d, int m, int y) {
    final now = DateTime.now();
    int age = now.year - y;
    if (now.month < m || (now.month == m && now.day < d)) age--;
    return age;
  }

}

class _GenderCard extends StatefulWidget {
  final String value;
  final IconData icon;
  final String current;
  final ValueChanged<String> onChanged;
  const _GenderCard(String _, this.value, this.icon, this.current, this.onChanged);
  @override
  State<_GenderCard> createState() => _GenderCardState();
}

class _GenderCardState extends State<_GenderCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sel = widget.current == widget.value;
    return Expanded(child: GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onChanged(widget.value); HapticFeedback.selectionClick(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: Premium.dFast,
          height: 72,
          decoration: BoxDecoration(
            color: sel ? context.accent.withValues(alpha: 0.08) : context.surfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: sel ? context.accent.withValues(alpha: 0.6) : context.borderColor.withValues(alpha: 0.5), width: sel ? 1.5 : 0.5),
            boxShadow: sel ? Premium.emeraldGlow(intensity: 0.3) : Premium.shadowSm,
          ),
          child: Center(child: Icon(widget.icon, size: 28, color: sel ? context.accent : context.textMuted)),
        ),
      ),
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Occupation Page (Step 2)
// ═══════════════════════════════════════════════════════════════════════════════

class _OccupationPage extends StatefulWidget {
  final String occupation;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  const _OccupationPage({required this.occupation, required this.onChanged, required this.onNext});
  @override
  State<_OccupationPage> createState() => _OccupationPageState();
}

class _OccupationPageState extends State<_OccupationPage> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.occupation;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
        builder: (ctx, scroll) => _OccupationSheet(
          scrollController: scroll,
          selected: widget.occupation,
          onSelected: (v) {
            widget.onChanged(v);
            _ctrl.text = v;
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(AppSpacing.xxl), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Text('What do you do?', style: TextStyle(color: context.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.xs),
        Text('This helps people find common ground', style: TextStyle(color: context.textMuted, fontSize: 14)),
        const SizedBox(height: AppSpacing.xxxl),

        // Dropdown selector
        GestureDetector(
          onTap: _showPicker,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.occupation.isNotEmpty ? context.accent.withValues(alpha: 0.3) : context.borderColor.withValues(alpha: 0.5), width: 0.5),
            ),
            child: Row(children: [
              Icon(Icons.work_outline_rounded, color: context.textMuted, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(
                widget.occupation.isNotEmpty ? widget.occupation : 'Select your occupation',
                style: TextStyle(color: widget.occupation.isNotEmpty ? context.textPrimary : context.textDisabled, fontSize: 14),
              )),
              Icon(Icons.keyboard_arrow_down_rounded, color: context.textMuted, size: 20),
            ]),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Manual input
        Text('Or type your own', style: TextStyle(color: context.textMuted, fontSize: 12)),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _ctrl,
          style: TextStyle(color: context.textPrimary, fontSize: 14),
          decoration: _deco(context, 'e.g. UX Designer at Google'),
          onChanged: (v) => widget.onChanged(v.trim()),
        ),

        const Spacer(),
        ElevatedButton(
          onPressed: widget.onNext,
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(widget.occupation.isNotEmpty ? 'Continue' : 'Skip for now'),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Occupation picker
// ═══════════════════════════════════════════════════════════════════════════════

const _occupationCategories = {
  'Students': ['Student', 'PhD Student', 'Medical Student', 'Law Student'],
  'Creative': ['Designer', 'Architect', 'Artist', 'Photographer', 'Writer / Author', 'Musician', 'Actor / Performer', 'Content Creator', 'Fashion Designer', 'Interior Designer'],
  'Tech': ['Software Engineer', 'Product Manager', 'Data Scientist', 'UX/UI Designer', 'DevOps Engineer', 'AI/ML Engineer', 'Cybersecurity Expert', 'Startup Founder', 'CTO / Tech Lead'],
  'Business': ['Entrepreneur', 'Business Owner', 'Consultant', 'Marketing Manager', 'Sales Manager', 'Finance Manager', 'Investment Banker', 'Venture Capitalist', 'Real Estate Agent', 'Lawyer', 'Accountant'],
  'Healthcare': ['Doctor', 'Dentist', 'Pharmacist', 'Nurse', 'Psychologist / Therapist', 'Veterinarian'],
  'Education': ['Teacher', 'Professor', 'Academic Researcher'],
  'Other': ['Engineer (Civil/Mechanical/etc.)', 'Chef', 'Pilot', 'Athlete', 'Military Officer', 'Police Officer', 'Journalist', 'Diplomat', 'NGO / Non-profit', 'Retired', 'Other'],
};

class _OccupationSheet extends StatefulWidget {
  final ScrollController scrollController;
  final String selected;
  final ValueChanged<String> onSelected;
  const _OccupationSheet({required this.scrollController, required this.selected, required this.onSelected});
  @override
  State<_OccupationSheet> createState() => _OccupationSheetState();
}

class _OccupationSheetState extends State<_OccupationSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: AppSpacing.lg),
      Container(width: 40, height: 4, decoration: Premium.sheetHandle()),
      const SizedBox(height: AppSpacing.lg),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: TextField(
          onChanged: (v) => setState(() => _q = v),
          style: TextStyle(color: context.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search occupation...',
            prefixIcon: Icon(Icons.search_rounded, color: context.textMuted, size: 20),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Expanded(
        child: ListView(
          controller: widget.scrollController,
          children: _q.isEmpty
              ? _occupationCategories.entries.expand((cat) => [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.xs),
                    child: Text(cat.key, style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ),
                  ...cat.value.map((o) => _occTile(context, o)),
                ]).toList()
              : _occupationCategories.values.expand((v) => v)
                  .where((o) => o.toLowerCase().contains(_q.toLowerCase()))
                  .map((o) => _occTile(context, o)).toList(),
        ),
      ),
    ]);
  }

  Widget _occTile(BuildContext context, String o) {
    final sel = o == widget.selected;
    return ListTile(
      title: Text(o, style: TextStyle(color: sel ? context.accent : context.textPrimary, fontSize: 14)),
      trailing: sel ? Icon(Icons.check_rounded, color: context.accent, size: 18) : null,
      onTap: () => widget.onSelected(o),
    );
  }
}

class _LocationPage extends StatefulWidget {
  final String city;
  final String country;
  final String? countryCode;                                          // R13
  final void Function(String city, String country, double? lat, double? lng) onLocationSet;
  final ValueChanged<String?>? onCountryCodeSet;                      // R13
  final VoidCallback onNext;
  const _LocationPage({
    required this.city,
    required this.country,
    required this.countryCode,
    required this.onLocationSet,
    required this.onCountryCodeSet,
    required this.onNext,
  });
  @override
  State<_LocationPage> createState() => _LocationPageState();
}

/// V1 final cleanup (2026-05-13): the GPS button + 4 LocationStatus
/// error branches + Open-Settings escalation were removed; manual city
/// search is the only path. `core/services/location_service.dart` is
/// no longer imported here; the geolocator dependency stays in
/// pubspec.yaml for now (flagged in FINAL_V1_CLEANUP_REPORT.md as a
/// follow-up). The Travel-Mode-suggestion dialog at the bottom is
/// retained as the only place we surface the SEA gate to the user
/// post-info-step removal.
class _LocationPageState extends State<_LocationPage> {
  void _openSearch() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CitySearchScreen(
        initialValue: widget.city.isNotEmpty ? widget.city : null,
        onSelected: (city, country, lat, lng, countryCode, placeId) {
          widget.onLocationSet(city, country, lat, lng);
          widget.onCountryCodeSet?.call(countryCode);   // R13
          // placeId currently unused in onboarding; ADIM 12 wires it for
          // travel mode. Home placeId can be propagated to the profile in
          // a follow-up (Profile.placeId field already exists from R13).
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = widget.city.isNotEmpty;
    return Padding(padding: const EdgeInsets.all(AppSpacing.xxl), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: AppSpacing.xxxl),
        Text('Where are you based?', style: TextStyle(color: context.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.sm),
        Text('Pick your city', style: TextStyle(color: context.textMuted, fontSize: 14)),
        const SizedBox(height: AppSpacing.xxxxl),

        // Manual city search — the only path post V1 cleanup.
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _openSearch,
            icon: const Icon(Icons.search_rounded, size: 20),
            label: Text(
              widget.city.isEmpty ? 'Search for your city' : 'Change city',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accent,
              foregroundColor: AppColors.textOnEmerald,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ),

        // Location result
        if (hasLocation) ...[
          const SizedBox(height: AppSpacing.xxxl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.accent.withValues(alpha: 0.15), width: 0.5),
              boxShadow: [
                ...Premium.shadowSm,
                BoxShadow(color: context.accent.withValues(alpha: 0.08), blurRadius: 16, spreadRadius: -2),
              ],
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.accent.withValues(alpha: 0.08),
                ),
                child: Icon(Icons.location_on_rounded, color: context.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.city, style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  if (widget.country.isNotEmpty)
                    Text(widget.country, style: TextStyle(color: context.textMuted, fontSize: 13)),
                ],
              )),
              Icon(Icons.check_circle_rounded, color: context.accent, size: 20),
            ]),
          ),
        ],

        const Spacer(),
        ElevatedButton(
          onPressed: hasLocation ? _onContinue : null,
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Continue'),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    ));
  }

  /// R13 — Country gate at the location step. If the resolved ISO 2-letter
  /// `countryCode` is one of TH/VN/PH the user proceeds straight to the next
  /// step. Otherwise we surface a Travel-Mode-suggestion dialog so the user
  /// understands the gate they'll hit later in Discover, and can choose to
  /// continue (account creation is allowed; only matching is gated) or
  /// cancel back to the city picker.
  Future<void> _onContinue() async {
    const supported = {'TH', 'VN', 'PH'};
    final code = widget.countryCode;
    if (code != null && supported.contains(code)) {
      widget.onNext();
      return;
    }
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Travel Mode Suggestion'),
        content: const Text(
          'Noblara is currently available in Thailand, Vietnam, and the Philippines. '
          "You can still continue, but to match with people you'll need to activate "
          'Travel Mode in Settings and select a city in one of these regions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (proceed == true && mounted) {
      widget.onNext();
    }
  }
}

/// V1 final cleanup (2026-05-13): the AvatarPicker grid (50
/// custom-painted warrior avatars) was removed. Photo upload is the
/// only path; users without a photo cannot complete onboarding (see
/// `_validateCompletion`).
class _PhotoPage extends StatelessWidget {
  final String? photoUrl;
  final ValueChanged<String?> onPhotoSelected;
  final VoidCallback onNext;
  const _PhotoPage({
    required this.photoUrl,
    required this.onPhotoSelected,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = photoUrl != null;
    return Padding(padding: const EdgeInsets.all(AppSpacing.xxl), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: AppSpacing.xxl),
        Text('Add a photo', style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.xs),
        Text('A real photo helps people trust your profile', style: TextStyle(color: context.textMuted, fontSize: 13)),
        const SizedBox(height: AppSpacing.xxxxl),

        // Upload photo button
        Center(child: GestureDetector(
          onTap: () async {
            final picker = ImagePicker();
            final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
            if (img != null) onPhotoSelected(img.path);
          },
          child: Container(width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.surfaceColor,
              border: Border.all(color: photoUrl != null ? context.accent : context.borderColor.withValues(alpha: 0.5), width: photoUrl != null ? 2.5 : 0.5),
              boxShadow: photoUrl != null ? Premium.emeraldGlow(intensity: 0.5) : Premium.shadowMd,
            ),
            child: photoUrl != null
                ? Center(child: Icon(Icons.check_rounded, color: context.accent, size: 40))
                : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_a_photo_rounded, color: context.textMuted, size: 28),
                    const SizedBox(height: 4),
                    Text('Upload', style: TextStyle(color: context.textMuted, fontSize: 11)),
                  ])),
          ),
        )),
        const Spacer(),
        const SizedBox(height: AppSpacing.lg),

        // Continue button — disabled until a photo is picked (no avatar
        // fallback after V1 final cleanup).
        ElevatedButton(
            onPressed: hasSelection ? onNext : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: hasSelection ? context.accent : context.surfaceColor,
              foregroundColor: hasSelection ? AppColors.textOnEmerald : context.textMuted,
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Continue')),
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
        const SizedBox(height: AppSpacing.xxl),
        Text('Your privacy', style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.lg),
        Expanded(child: ListView(children: [
          _InfoCard(Icons.favorite_outline_rounded, 'Dating interactions', 'Add a photo to swipe, match, and message. Without one you can only browse.'),
          _InfoCard(Icons.photo_camera_outlined, 'Add a photo to connect', 'Without a photo you can browse but cannot swipe, connect or message anyone.'),
          _InfoCard(Icons.auto_awesome_outlined, 'Photo to post Nobs', 'You can read and react to Nobs freely. Upload a photo to share your own.'),
          _InfoCard(Icons.visibility_off_rounded, 'Incognito available', 'You can browse invisibly anytime from Settings.'),
          _InfoCard(Icons.shield_rounded, 'Calm Mode available', 'Only quality profiles can reach you when enabled.'),
          _InfoCard(Icons.lock_rounded, 'Private by default', 'Your activity, interests, and score are never public.'),
          _InfoCard(Icons.tune_rounded, 'Full control', 'Adjust who can signal, note, or reach you in Settings.'),
        ])),
        const SizedBox(height: AppSpacing.md),
        ElevatedButton(onPressed: onNext,
            style: ElevatedButton.styleFrom(backgroundColor: context.accent, foregroundColor: AppColors.textOnEmerald,
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
    decoration: BoxDecoration(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      border: Border.all(color: AppColors.emerald600.withValues(alpha: 0.08), width: 0.5),
      boxShadow: Premium.shadowSm,
    ),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.accent.withValues(alpha: 0.06),
        ),
        child: Icon(icon, color: context.accent, size: 18),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        Text(sub, style: TextStyle(color: context.textMuted, fontSize: 12, height: 1.4)),
      ])),
    ]));
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
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [context.accent.withValues(alpha: 0.12), context.accent.withValues(alpha: 0.04)],
            ),
            border: Border.all(color: context.accent.withValues(alpha: 0.20), width: 0.5),
            boxShadow: Premium.emeraldGlow(intensity: 0.8),
          ),
          child: Icon(Icons.check_circle_outline_rounded, color: context.accent, size: 40),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text('You\'re all set${widget.name.isNotEmpty ? ', ${widget.name}' : ''}',
            style: TextStyle(color: context.textPrimary, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
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
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            boxShadow: (_loading || widget.validationError != null) ? null : Premium.emeraldGlow(intensity: 0.7),
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: (_loading || widget.validationError != null) ? null : () async {
              setState(() => _loading = true);
              try {
                await widget.onComplete().timeout(const Duration(seconds: 15));
                // Success: AppRouter listens to profileProvider and will
                // unmount this screen on the next frame. Reset _loading
                // defensively in case the router rebuild is delayed —
                // otherwise the spinner could keep spinning after a
                // successful save (the R15 "you're all set, stuck"
                // symptom).
                if (!mounted) return;
                setState(() => _loading = false);
              } catch (e) {
                if (!context.mounted) return;
                setState(() => _loading = false);
                // Surface the actual failure category — save vs network
                // vs timeout — so the user has a sense of whether to
                // check connection, location, or just retry.
                final msg = e is TimeoutException
                    ? 'This is taking longer than expected. Please check your connection and try again.'
                    : "We couldn't save your profile. Please check your location or try again.";
                ToastService.show(context, message: msg, type: ToastType.error);
              }
            },
            child: _loading
                ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: context.bgColor))
                : const Text('Enter Noblara', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
        ),
    ]));
  }
}

// Shared decoration
InputDecoration _deco(BuildContext context, String hint) => InputDecoration(
  hintText: hint, hintStyle: TextStyle(color: context.textDisabled),
  filled: true, fillColor: context.surfaceColor,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.borderColor.withValues(alpha: 0.5))),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.borderColor.withValues(alpha: 0.5))),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.accent)),
);
