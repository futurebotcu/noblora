import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/premium.dart';
import '../../core/enums/noble_mode.dart';
import '../../data/models/post.dart';
import '../../data/models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/active_modes_provider.dart';
import '../../providers/posts_provider.dart';
import '../settings/settings_screen.dart';
import 'edit/edit_profile_main_screen.dart';

// ---------------------------------------------------------------------------
// Profile-specific editorial surfaces — lighter than global dark theme
// to give the profile a "luxury magazine" feel without changing app-wide colors.
// ---------------------------------------------------------------------------

const _profileBg       = Color(0xFF1A211E);  // warm dark sage (editorial base)
const _profileCard     = Color(0xFF283130);  // lifted card (clearly distinct from bg)
const _profileElevated = Color(0xFF323B38);  // highlight card (prompts, chips)
const _profileBorder   = Color(0xFF445049);  // strong visible edge

// ═══════════════════════════════════════════════════════════════════════════
// CURATED PROFILE — display model layer
// ═══════════════════════════════════════════════════════════════════════════
// The visible profile MUST NOT render directly from `Profile`. This class is
// the only bridge between raw edit-profile data and what the user sees. It:
//   • filters obviously-weak content (empty / blocklist / repeated / no-letter)
//   • applies the owner's per-field visibility map (Public / Matches / Private)
//   • respects viewer context (self / match / stranger) so the owner always
//     sees their own data even if marked Private
//   • prioritizes strong identity signals
//   • collapses low-signal facts (zodiac / fromCountry / languages / height)
//   • exposes per-section booleans so empty sections never render
// If you find yourself reading `profile.someField` directly inside a widget,
// add a curated getter instead. No exceptions.
// ═══════════════════════════════════════════════════════════════════════════

enum _ViewerContext {
  self,
}

class _CuratedProfile {
  final Profile? raw;
  final Set<String> activeModes;
  final String displayName;
  final String? userId;
  final _ViewerContext viewerContext;

  const _CuratedProfile({
    required this.raw,
    required this.activeModes,
    required this.displayName,
    required this.userId,
    this.viewerContext = _ViewerContext.self,
  });

  // ── filtering helpers ─────────────────────────────────────────────────
  // Hard rejects only: empty, single char, blocklist match, pure
  // repetition ("aaaa"), or no-letter strings ("...", "—", "1234").
  // No length thresholds — short content like "calm", "yes", "freelance"
  // passes through. Use _substantive() for fields where length matters.
  static const _weakBlocklist = <String>{
    '', '.', '..', '...', '-', '—', '_',
    'first', 'test', 'asdf', 'sdf', 'qwe', 'qwer',
    'a', 'aa', 'aaa', 'x', 'xx', 'xxx',
    'todo', 'tbd', 'na', 'n/a', 'none', 'null', 'lorem', 'ipsum',
  };
  static final _repeatedRe = RegExp(r'^(.)\1+$');
  static final _hasLetterRe =
      RegExp(r'[A-Za-zÇĞİıÖŞÜçğöşü]', unicode: true);

  static String? _strong(String? s) {
    if (s == null) return null;
    final t = s.trim();
    if (t.length < 2) return null;
    if (_weakBlocklist.contains(t.toLowerCase())) return null;
    if (_repeatedRe.hasMatch(t)) return null;
    if (!_hasLetterRe.hasMatch(t)) return null;
    return t;
  }

  /// For long-form fields where a single short word is too thin to qualify
  /// as a story (longBio, current focus, prompt answers). Accepts content
  /// that EITHER passes a char threshold OR has enough words.
  static String? _substantive(
    String? s, {
    int minChars = 14,
    int minWords = 3,
  }) {
    final base = _strong(s);
    if (base == null) return null;
    if (base.length >= minChars) return base;
    final words = base.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.length >= minWords) return base;
    return null;
  }

  static List<String> _strongList(List<String>? list) {
    if (list == null || list.isEmpty) return const [];
    return list.map(_strong).whereType<String>().toList();
  }

  // ── visibility gate ───────────────────────────────────────────────────
  // Owner always sees everything. Otherwise consult Profile.canViewField
  // with the snake_case field key from the visibility map.
  bool _canSee(String fieldKey) {
    if (viewerContext == _ViewerContext.self) return true;
    final p = raw;
    if (p == null) return false;
    return p.canViewField(
      fieldKey,
      isMatch: false,
    );
  }

  T? _gate<T>(String fieldKey, T? value) =>
      _canSee(fieldKey) ? value : null;

  List<String> _gateList(String fieldKey, List<String> value) =>
      _canSee(fieldKey) ? value : const [];

  // ── identity ──────────────────────────────────────────────────────────
  int? get age => _gate('age', raw?.age);
  String? get profession => _strong(raw?.occupation);
  String? get secondProfession =>
      _gate('secondary_role', _strong(raw?.secondaryRole));
  String? get city => _gate('city', _strong(raw?.city));

  /// One short identity line — first available of vibe / lookingFor.
  String? get descriptor =>
      _strong(raw?.vibe) ?? _gate('looking_for', _strong(raw?.lookingFor));

  /// Compact bio under the descriptor (different from longBio).
  String? get shortBio => _strong(raw?.bio);

  /// One short manifesto line — the tagline if substantial.
  String? get manifesto => _strong(raw?.tagline);

  // ── photos ────────────────────────────────────────────────────────────
  List<String> get _photos => (raw?.photoUrls ?? const <String>[])
      .where((u) => u.trim().isNotEmpty)
      .toList();

  bool get hasHeroPhoto => _photos.isNotEmpty;
  String? get heroPhoto => _photos.isEmpty ? null : _photos.first;
  List<String> get supportingPhotos =>
      _photos.length <= 1 ? const [] : _photos.sublist(1);

  // ── interests / openness ──────────────────────────────────────────────
  List<String> get topInterests =>
      _strongList(raw?.interests).take(3).toList();

  List<({IconData icon, String label})> get openness {
    final out = <({IconData icon, String label})>[];
    if (activeModes.contains('date')) {
      out.add((icon: Icons.favorite_rounded, label: 'Noble Date Open'));
    }
    if (activeModes.contains('bff')) {
      out.add((icon: Icons.people_rounded, label: 'Noble BFF Open'));
    }
    if (activeModes.contains('social')) {
      out.add((icon: Icons.event_rounded, label: 'Social Open'));
    }
    return out;
  }

  // ── core trait fields ─────────────────────────────────────────────────
  String? get aboutMe =>
      _substantive(raw?.longBio, minChars: 18, minWords: 4);
  String? get currentFocus =>
      _substantive(raw?.currentFocus, minChars: 8, minWords: 2);

  String? get sleepStyle => _strong(raw?.sleepStyle);
  String? get dietStyle => _strong(raw?.dietStyle);
  String? get fitnessRoutine => _strong(raw?.fitnessRoutine);

  List<String> get industry => _strongList(raw?.industry);
  String? get workStyle => _strong(raw?.workStyle);
  List<String> get buildingNow => _strongList(raw?.buildingNow);
  String? get entrepreneurshipStatus =>
      _strong(raw?.entrepreneurshipStatus);
  String? get workIntensity => _strong(raw?.workIntensity);
  String? get educationLevel => _strong(raw?.educationLevel);

  List<String> get musicGenres => _strongList(raw?.musicGenres);
  List<String> get movieGenres => _strongList(raw?.movieGenres);
  List<String> get weekendStyle => _strongList(raw?.weekendStyle);
  List<String> get humorStyle => _strongList(raw?.humorStyle);

  List<String> get countriesVisited =>
      _gateList('visited_countries', _strongList(raw?.countriesVisited));
  List<String> get livedCountries => _strongList(raw?.livedCountries);
  List<String> get wishlistCountries => _strongList(raw?.wishlistCountries);
  List<String> get travelStyle => _strongList(raw?.travelStyle);
  String? get relocationOpenness => _strong(raw?.relocationOpenness);

  List<String> get aiTools => _gateList('ai_tools', _strongList(raw?.aiTools));
  String? get techRelation => _strong(raw?.techRelation);
  String? get socialMediaUsage => _strong(raw?.socialMediaUsage);

  // ── connection style (separated section) ──────────────────────────────
  List<String> get loveLanguages => _strongList(raw?.loveLanguages);
  List<String> get communicationStyle => _strongList(raw?.communicationStyle);
  List<String> get datingStyle => _strongList(raw?.datingStyle);
  List<String> get relationshipType => _strongList(raw?.relationshipType);
  List<String> get firstMeetPreference =>
      _strongList(raw?.firstMeetPreference);
  List<String> get interestedIn => _strongList(raw?.interestedIn);
  String? get socialEnergy => _strong(raw?.socialEnergy);

  // ── prompts (substantive answers only) ────────────────────────────────
  // R3 fix (2026-04-24): prompt answers use `_strong` only — short legitimate
  // answers like "İstanbul" / "kahve" / "evet" carry information and must
  // render. `_substantive` thresholds belong on long-form story fields
  // (longBio, dateBio, currentFocus), not on Q&A prompts.
  List<PromptAnswer> get strongPrompts =>
      (raw?.prompts ?? const <PromptAnswer>[]).where(isPromptVisible).toList();

  // ── personas (substantive bios only) ──────────────────────────────────
  String? get dateBio =>
      _substantive(raw?.dateBio, minChars: 16, minWords: 3);
  String? get bffBio => _substantive(raw?.bffBio, minChars: 16, minWords: 3);
  String? get socialBio =>
      _substantive(raw?.socialBio, minChars: 16, minWords: 3);

  // ── proof ─────────────────────────────────────────────────────────────
  bool get isVerified => (raw?.trustScore ?? 0) > 60;
  int get profileCompleteness => raw?.profileCompletenessScore ?? 0;

  // ── per-section render guards ─────────────────────────────────────────
  bool get hasIdentitySummary =>
      profession != null ||
      secondProfession != null ||
      city != null ||
      descriptor != null ||
      shortBio != null ||
      manifesto != null ||
      openness.isNotEmpty ||
      topInterests.isNotEmpty;

  bool get hasAboutMe => aboutMe != null;
  bool get hasLifestyle =>
      sleepStyle != null || dietStyle != null || fitnessRoutine != null;
  bool get hasCareer =>
      industry.isNotEmpty ||
      workStyle != null ||
      buildingNow.isNotEmpty ||
      entrepreneurshipStatus != null ||
      secondProfession != null ||
      workIntensity != null ||
      educationLevel != null;
  bool get hasCulture =>
      musicGenres.isNotEmpty ||
      movieGenres.isNotEmpty ||
      weekendStyle.isNotEmpty ||
      humorStyle.isNotEmpty;
  bool get hasTravel =>
      countriesVisited.isNotEmpty ||
      livedCountries.isNotEmpty ||
      wishlistCountries.isNotEmpty ||
      travelStyle.isNotEmpty ||
      relocationOpenness != null;
  bool get hasDigital =>
      aiTools.isNotEmpty ||
      techRelation != null ||
      socialMediaUsage != null;

  bool get hasCoreTraits =>
      hasAboutMe ||
      currentFocus != null ||
      hasLifestyle ||
      hasCareer ||
      hasCulture ||
      hasTravel ||
      hasDigital;

  bool get hasConnectionStyle =>
      loveLanguages.isNotEmpty ||
      communicationStyle.isNotEmpty ||
      datingStyle.isNotEmpty ||
      relationshipType.isNotEmpty ||
      firstMeetPreference.isNotEmpty ||
      interestedIn.isNotEmpty ||
      socialEnergy != null;

  bool get hasPrompts => strongPrompts.isNotEmpty;
  bool get hasPersonas =>
      dateBio != null || bffBio != null || socialBio != null;
}

/// Whether a prompt Q&A pair is substantial enough to render in
/// `_PromptStoriesSection`. Uses `_strong` for both fields — no length or
/// word-count threshold. Short legitimate answers ("İstanbul", "kahve",
/// "evet") carry information; spam ("asdf", "aaaa", "1234") is already
/// blocked by `_strong`. Top-level so guardrail tests can import it.
@visibleForTesting
bool isPromptVisible(PromptAnswer p) {
  if (!p.hasAnswer) return false;
  if (_CuratedProfile._strong(p.question) == null) return false;
  if (_CuratedProfile._strong(p.answer) == null) return false;
  return true;
}

// ═══════════════════════════════════════════════════════════════════════════
// NOBLARA PROFILE PAGE — LOCKED ARCHITECTURE
// ═══════════════════════════════════════════════════════════════════════════
// Visible-profile flow is LOCKED. Section order:
//
//   1. HERO PHOTO         → _HeroPhotoBlock      (one dominant photo)
//   2. IDENTITY SUMMARY   → _IdentitySummaryBlock (under the hero photo)
//   3. SUPPORTING PHOTOS  → _SupportingPhotosBlock (only if 2+ photos)
//   4. CORE TRAITS        → _CoreTraitsSection
//   5. PROMPT STORIES     → _PromptStoriesSection
//   6. CONNECTION STYLE   → _ConnectionStyleSection
//   7. PERSONAS / MODES   → _PersonaSection
//   8. PROOF LAYER        → _EarnedBadgesSection
//   9. NOBS / THOUGHTS    → _LastNobsSection
//
// EVERY widget must read from _CuratedProfile, never from Profile directly.
// Sections that have no curated content must render SizedBox.shrink() — never
// placeholders or "Build your story" empty states inside a viewable profile.
// ═══════════════════════════════════════════════════════════════════════════

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final profile = ref.watch(profileProvider);
    final modesState = ref.watch(activeModesProvider);

    final displayName = profile.profile?.fullName.isNotEmpty == true
        ? profile.profile!.fullName
        : (auth.email?.split('@').first ?? 'Noblara User');

    final curated = _CuratedProfile(
      raw: profile.profile,
      activeModes: modesState.modes.toSet(),
      displayName: displayName,
      userId: auth.userId,
      viewerContext: _ViewerContext.self,
    );

    return Scaffold(
      backgroundColor: _profileBg,
      body: CustomScrollView(
        slivers: [
          // ── Top action bar — back (when poppable) · edit · settings ──────
          SliverAppBar(
            pinned: true,
            toolbarHeight: 48,
            backgroundColor: _profileBg,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: Navigator.canPop(context),
            iconTheme: IconThemeData(color: context.textPrimary),
            titleSpacing: 0,
            title: const SizedBox.shrink(),
            actions: [
              IconButton(
                tooltip: 'Edit',
                icon: Icon(Icons.edit_outlined,
                    color: context.textPrimary, size: 20),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const EditProfileMainScreen()),
                ),
              ),
              IconButton(
                tooltip: 'Settings',
                icon: Icon(Icons.settings_outlined,
                    color: context.textPrimary, size: 20),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),

          // ── 1. HERO PHOTO (one dominant) ─────────────────────────────────
          SliverToBoxAdapter(child: _HeroPhotoBlock(curated: curated)),

          // ── 2. IDENTITY SUMMARY (directly under the hero photo) ──────────
          if (curated.hasIdentitySummary)
            SliverToBoxAdapter(child: _IdentitySummaryBlock(curated: curated)),

          // ── 3. SUPPORTING PHOTOS (only if 2+ photos) ─────────────────────
          if (curated.supportingPhotos.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 28),
                child: _SupportingPhotosBlock(curated: curated),
              ),
            ),

          // ── 4. CORE TRAITS ───────────────────────────────────────────────
          if (curated.hasCoreTraits)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 32),
                child: _CoreTraitsSection(curated: curated),
              ),
            ),

          // ── 5. PROMPT STORIES ────────────────────────────────────────────
          if (curated.hasPrompts)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 32),
                child: _PromptStoriesSection(curated: curated),
              ),
            ),

          // ── 6. CONNECTION STYLE ──────────────────────────────────────────
          if (curated.hasConnectionStyle)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 32),
                child: _ConnectionStyleSection(curated: curated),
              ),
            ),

          // ── 7. PERSONAS / MODES ──────────────────────────────────────────
          if (curated.hasPersonas)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 32),
                child: _PersonaSection(profile: curated.raw),
              ),
            ),

          // ── 8. PROOF LAYER ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 32),
              child: _EarnedBadgesSection(profile: curated.raw),
            ),
          ),

          // ── 9. NOBS / THOUGHTS ───────────────────────────────────────────
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 32, bottom: 48),
              child: _LastNobsSection(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 1 — HERO PHOTO
// One dominant 4:5 image, name+age overlaid bottom-left. The visual is the
// identity. Falls back to a calm fallback card if no photo is set.
// ---------------------------------------------------------------------------

class _HeroPhotoBlock extends StatelessWidget {
  final _CuratedProfile curated;
  const _HeroPhotoBlock({required this.curated});

  @override
  Widget build(BuildContext context) {
    final hero = curated.heroPhoto;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: Premium.shadowMd,
            ),
            child: hero != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: hero,
                        fit: BoxFit.cover,
                        memCacheWidth: 1100,
                        placeholder: (_, __) =>
                            Container(color: _profileCard),
                        errorWidget: (_, __, ___) => _fallback(context),
                      ),
                      // Bottom vignette so the name+age stays legible
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.45, 1.0],
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.55),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Name + age — strongest text on the page
                      Positioned(
                        left: 22,
                        right: 22,
                        bottom: 20,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(
                                curated.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.7,
                                  height: 1.05,
                                  shadows: [
                                    Shadow(
                                        blurRadius: 14,
                                        color: Colors.black54),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (curated.age != null)
                              Text(
                                ', ${curated.age}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (curated.isVerified)
                        Positioned(
                          top: 14,
                          right: 14,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.emerald600,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
                              boxShadow: Premium.shadowSm,
                            ),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white, size: 14),
                          ),
                        ),
                    ],
                  )
                : _fallback(context),
          ),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) => Container(
        color: _profileCard,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.emerald600.withValues(alpha: 0.15),
                ),
                child: Icon(Icons.camera_alt_outlined,
                    color: AppColors.emerald500.withValues(alpha: 0.7),
                    size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                curated.displayName,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add a photo to start your story',
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// SECTION 2 — IDENTITY SUMMARY
// Directly under the hero photo. Strongest identity signals in the locked
// order: profession·city → descriptor → openness chips → top 3 interests →
// manifesto. Renders nothing for fields the curated model marks weak/empty.
// ---------------------------------------------------------------------------

class _IdentitySummaryBlock extends StatelessWidget {
  final _CuratedProfile curated;
  const _IdentitySummaryBlock({required this.curated});

  @override
  Widget build(BuildContext context) {
    // profession (+ secondary) · city — merge primary and second profession
    // with a slim separator so a designer/musician shows both sides.
    final professionLine = [
      if (curated.profession != null) curated.profession!,
      if (curated.secondProfession != null) curated.secondProfession!,
    ].join(' / ');
    final professionCity = [
      if (professionLine.isNotEmpty) professionLine,
      if (curated.city != null) curated.city!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (professionCity.isNotEmpty)
            Text(
              professionCity,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          if (curated.descriptor != null) ...[
            const SizedBox(height: 6),
            Text(
              curated.descriptor!,
              style: TextStyle(
                color: context.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (curated.shortBio != null &&
              curated.shortBio != curated.descriptor) ...[
            const SizedBox(height: 8),
            Text(
              curated.shortBio!,
              style: TextStyle(
                color: context.textSecondary.withValues(alpha: 0.85),
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (curated.openness.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: curated.openness
                  .map((o) => _OpennessChip(icon: o.icon, label: o.label))
                  .toList(),
            ),
          ],
          if (curated.topInterests.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: curated.topInterests
                  .map((i) => _InterestChip(label: i))
                  .toList(),
            ),
          ],
          if (curated.manifesto != null) ...[
            const SizedBox(height: 18),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                '"${curated.manifesto!}"',
                style: TextStyle(
                  color: context.textPrimary.withValues(alpha: 0.82),
                  fontSize: 14.5,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                  letterSpacing: 0.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OpennessChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _OpennessChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.emerald600.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.emerald600.withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.emerald500),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.emerald500,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  final String label;
  const _InterestChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: _profileElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _profileBorder.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Persona Section — shows real mode-specific bios from profile
// ---------------------------------------------------------------------------

class _PersonaSection extends StatefulWidget {
  final Profile? profile;
  const _PersonaSection({this.profile});

  @override
  State<_PersonaSection> createState() => _PersonaSectionState();
}

class _PersonaSectionState extends State<_PersonaSection> {
  NobleMode _selectedMode = NobleMode.date;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Row(
            children: [
              Text('YOUR PERSONAS', style: Premium.sectionHeader(context.textMuted)),
              const Spacer(),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Mode selector pills (persona modes only — excludes noblara)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Row(
            children: NobleMode.values
                .where((m) =>
                    m != NobleMode.noblara &&
                    m != NobleMode.social)
                .map((mode) {
              final isActive = mode == _selectedMode;
              return GestureDetector(
                onTap: () => setState(() => _selectedMode = mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive
                        ? mode.accentColor.withValues(alpha: 0.15)
                        : _profileCard,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusCircle),
                    border: Border.all(
                      color: isActive ? mode.accentColor : _profileBorder.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(mode.icon,
                          size: 11,
                          color: isActive
                              ? mode.accentColor
                              : context.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        mode.label,
                        style: TextStyle(
                          color: isActive
                              ? mode.accentColor
                              : context.textMuted,
                          fontSize: 11,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildPersonaCard(context, _selectedMode),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonaCard(BuildContext context, NobleMode mode) {
    final p = widget.profile;
    final bio = switch (mode) {
      NobleMode.date => p?.dateBio,
      NobleMode.bff => p?.bffBio,
      NobleMode.social => p?.socialBio,
      _ => null,
    };
    final avatarUrl = switch (mode) {
      NobleMode.date => p?.dateAvatarUrl,
      NobleMode.bff => p?.bffAvatarUrl,
      NobleMode.social => p?.socialAvatarUrl,
      _ => null,
    };
    final hasBio = bio != null && bio.trim().isNotEmpty;

    return Container(
      key: ValueKey(mode),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: Premium.surfaceGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: mode.accentColor.withValues(alpha: 0.15)),
        boxShadow: Premium.shadowSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: mode.accentColor, width: 1.5),
            ),
            child: ClipOval(
              child: avatarUrl != null
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: mode.accentColor.withValues(alpha: 0.15),
                        child: Icon(mode.icon, color: mode.accentColor, size: 24),
                      ),
                    )
                  : Container(
                      color: mode.accentColor.withValues(alpha: 0.15),
                      child: Icon(mode.icon, color: mode.accentColor, size: 24),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(mode.icon, size: 12, color: mode.accentColor),
                    const SizedBox(width: 4),
                    Text(
                      '${mode.label} Persona',
                      style: TextStyle(
                        color: mode.accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  hasBio ? bio : 'Tell the world who you are in ${mode.label} mode.',
                  style: TextStyle(
                    color: hasBio ? context.textSecondary : context.textDisabled,
                    fontSize: 13,
                    height: 1.5,
                    fontStyle: hasBio ? FontStyle.normal : FontStyle.italic,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 4 — CORE TRAITS
// Curated information islands. Reads only from _CuratedProfile, so weak/empty
// fields never reach the screen. Connection-style fields live in their own
// section so they get the weight they deserve.
// ---------------------------------------------------------------------------

class _CoreTraitsSection extends StatelessWidget {
  final _CuratedProfile curated;
  const _CoreTraitsSection({required this.curated});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CORE TRAITS', style: Premium.sectionHeader(context.textMuted)),
          const SizedBox(height: AppSpacing.lg),

          if (curated.hasAboutMe)
            _RichCard(
              icon: Icons.auto_stories_rounded,
              title: 'About Me',
              child: Text(curated.aboutMe!,
                  style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 13.5,
                      height: 1.6)),
            ),

          if (curated.currentFocus != null)
            _RichCard(
              icon: Icons.flag_rounded,
              title: 'Current Focus',
              child: Text(curated.currentFocus!,
                  style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                      height: 1.5,
                      fontStyle: FontStyle.italic)),
            ),

          if (curated.hasLifestyle)
            _RichCard(
              icon: Icons.self_improvement_rounded,
              title: 'Lifestyle',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (curated.sleepStyle != null)
                    _FactRow('Sleep', curated.sleepStyle!),
                  if (curated.dietStyle != null)
                    _FactRow('Diet', curated.dietStyle!),
                  if (curated.fitnessRoutine != null)
                    _FactRow('Fitness', curated.fitnessRoutine!),
                ],
              ),
            ),

          if (curated.hasCareer)
            _RichCard(
              icon: Icons.rocket_launch_outlined,
              title: 'Career & Building',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (curated.secondProfession != null)
                    _FactRow('Second side', curated.secondProfession!),
                  if (curated.industry.isNotEmpty)
                    _FactRow('Industry', curated.industry.join(', ')),
                  if (curated.workStyle != null)
                    _FactRow('Work style', curated.workStyle!),
                  if (curated.workIntensity != null)
                    _FactRow('Intensity', curated.workIntensity!),
                  if (curated.entrepreneurshipStatus != null)
                    _FactRow('Status', curated.entrepreneurshipStatus!),
                  if (curated.buildingNow.isNotEmpty)
                    _FactRow('Building', curated.buildingNow.join(', ')),
                  if (curated.educationLevel != null)
                    _FactRow('Education', curated.educationLevel!),
                ],
              ),
            ),

          if (curated.hasCulture)
            _RichCard(
              icon: Icons.palette_outlined,
              title: 'Culture & Taste',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (curated.musicGenres.isNotEmpty) ...[
                    _FactLabel('Music'),
                    Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children:
                            curated.musicGenres.map(_MiniChip.new).toList()),
                    const SizedBox(height: 12),
                  ],
                  if (curated.movieGenres.isNotEmpty) ...[
                    _FactLabel('Films'),
                    Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children:
                            curated.movieGenres.map(_MiniChip.new).toList()),
                    const SizedBox(height: 12),
                  ],
                  if (curated.weekendStyle.isNotEmpty)
                    _FactRow('Weekends', curated.weekendStyle.join(', ')),
                  if (curated.humorStyle.isNotEmpty)
                    _FactRow('Humor', curated.humorStyle.join(', ')),
                ],
              ),
            ),

          if (curated.hasTravel)
            _RichCard(
              icon: Icons.flight_outlined,
              title: 'Travel',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (curated.countriesVisited.isNotEmpty)
                    _FactRow('Visited',
                        curated.countriesVisited.take(8).join(', ')),
                  if (curated.livedCountries.isNotEmpty)
                    _FactRow('Lived in', curated.livedCountries.join(', ')),
                  if (curated.wishlistCountries.isNotEmpty)
                    _FactRow('Wishlist',
                        curated.wishlistCountries.take(8).join(', ')),
                  if (curated.travelStyle.isNotEmpty)
                    _FactRow('Style', curated.travelStyle.join(', ')),
                  if (curated.relocationOpenness != null)
                    _FactRow('Relocation', curated.relocationOpenness!),
                ],
              ),
            ),

          if (curated.hasDigital)
            _RichCard(
              icon: Icons.memory_rounded,
              title: 'Digital Life',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (curated.aiTools.isNotEmpty) ...[
                    _FactLabel('AI tools'),
                    Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children:
                            curated.aiTools.map(_MiniChip.new).toList()),
                    const SizedBox(height: 12),
                  ],
                  if (curated.techRelation != null)
                    _FactRow('Tech', curated.techRelation!),
                  if (curated.socialMediaUsage != null)
                    _FactRow('Social media', curated.socialMediaUsage!),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 5 — PROMPT STORIES
// Substantive prompt cards only. Curated rejects empty/test answers.
// ---------------------------------------------------------------------------

class _PromptStoriesSection extends StatelessWidget {
  final _CuratedProfile curated;
  const _PromptStoriesSection({required this.curated});

  @override
  Widget build(BuildContext context) {
    final answered = curated.strongPrompts;
    if (answered.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PROMPT STORIES',
              style: Premium.sectionHeader(context.textMuted)),
          const SizedBox(height: AppSpacing.lg),
          ...answered.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  decoration: BoxDecoration(
                    color: _profileElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.emerald600.withValues(alpha: 0.18)),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.emerald600.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.question.toUpperCase(),
                          style: const TextStyle(
                              color: AppColors.emerald600,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 10),
                      Text(p.answer,
                          style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 15,
                              height: 1.55,
                              fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 6 — CONNECTION STYLE
// Lifted out of Core Traits because intention/communication/love languages
// are the strongest signals about *how* this person wants to connect.
// ---------------------------------------------------------------------------

class _ConnectionStyleSection extends StatelessWidget {
  final _CuratedProfile curated;
  const _ConnectionStyleSection({required this.curated});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CONNECTION STYLE',
              style: Premium.sectionHeader(context.textMuted)),
          const SizedBox(height: AppSpacing.lg),
          _RichCard(
            icon: Icons.favorite_border_rounded,
            title: 'How I Connect',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (curated.relationshipType.isNotEmpty)
                  _FactRow(
                      'Looking for', curated.relationshipType.join(', ')),
                if (curated.interestedIn.isNotEmpty)
                  _FactRow(
                      'Interested in', curated.interestedIn.join(', ')),
                if (curated.firstMeetPreference.isNotEmpty)
                  _FactRow('First meet',
                      curated.firstMeetPreference.join(', ')),
                if (curated.loveLanguages.isNotEmpty)
                  _FactRow('Love languages', curated.loveLanguages.join(', ')),
                if (curated.communicationStyle.isNotEmpty)
                  _FactRow(
                      'Communication', curated.communicationStyle.join(', ')),
                if (curated.datingStyle.isNotEmpty)
                  _FactRow('Dating style', curated.datingStyle.join(', ')),
                if (curated.socialEnergy != null)
                  _FactRow('Social energy', curated.socialEnergy!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RichCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _RichCard({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: _profileCard,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: _profileBorder.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: AppColors.emerald600, size: 15),
              const SizedBox(width: 8),
              Text(title.toUpperCase(), style: TextStyle(color: context.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            ]),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  final String label;
  final String value;
  const _FactRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: context.textMuted.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w400)),
          ),
          Expanded(child: Text(value, style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w500, height: 1.3))),
        ],
      ),
    );
  }
}

class _FactLabel extends StatelessWidget {
  final String label;
  const _FactLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: context.textMuted.withValues(alpha: 0.7),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  const _MiniChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: _profileElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: _profileBorder.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: context.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 3 — SUPPORTING PHOTOS
// Only the photos *after* the hero. Editorial rhythm: 2-col → wide → 2-col →
// wide. Never a tall photo directly under the dominant hero. Empty when the
// curated profile has 0 or 1 photos (hero handles the singleton).
// ---------------------------------------------------------------------------

class _SupportingPhotosBlock extends StatelessWidget {
  final _CuratedProfile curated;
  const _SupportingPhotosBlock({required this.curated});

  @override
  Widget build(BuildContext context) {
    final photos = curated.supportingPhotos;
    if (photos.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    int i = 0;
    bool wideNext = false;

    while (i < photos.length) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));

      if (wideNext || (photos.length - i) == 1) {
        // single wide
        rows.add(_EditorialPhoto(
            url: photos[i], aspectRatio: 16 / 9, radius: 18));
        i += 1;
        wideNext = false;
      } else {
        // 2-col 4:5
        rows.add(Row(
          children: [
            Expanded(
              child: _EditorialPhoto(
                  url: photos[i], aspectRatio: 4 / 5, radius: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _EditorialPhoto(
                  url: photos[i + 1], aspectRatio: 4 / 5, radius: 18),
            ),
          ],
        ));
        i += 2;
        wideNext = true;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: rows),
    );
  }
}

class _EditorialPhoto extends StatelessWidget {
  final String url;
  final double aspectRatio;
  final double radius;

  const _EditorialPhoto({
    required this.url,
    required this.aspectRatio,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: Premium.shadowSm,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: 600,
                placeholder: (_, __) => Container(color: _profileCard),
                errorWidget: (_, __, ___) => Container(
                  color: _profileElevated,
                  child: Icon(Icons.image_outlined,
                      color: context.textDisabled, size: 28),
                ),
              ),
              // Soft bottom vignette for depth
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.55, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.15),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Earned Badges — only real, earned badges
// ---------------------------------------------------------------------------

class _EarnedBadgesSection extends StatelessWidget {
  final Profile? profile;
  const _EarnedBadgesSection({this.profile});

  @override
  Widget build(BuildContext context) {
    final badges = <_Badge>[];
    final p = profile;
    if (p == null) return const SizedBox.shrink();

    // Only show badges that are actually earned
    badges.add(const _Badge(Icons.star_rounded, 'Early Member', AppColors.emerald500));
    if ((p.trustScore) > 60) {
      badges.add(const _Badge(Icons.verified_rounded, 'Verified', AppColors.emerald500));
    }
    if (p.nobTier == NobTier.explorer || p.nobTier == NobTier.noble) {
      badges.add(_Badge(Icons.explore_rounded, p.nobTier.label, AppColors.emerald500));
    }
    if (p.profileCompletenessScore >= 80) {
      badges.add(const _Badge(Icons.workspace_premium_rounded, 'Complete Profile', Color(0xFFAB47BC)));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Text('BADGES', style: Premium.sectionHeader(context.textMuted)),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: badges.map((b) => _BadgeChip(badge: b)).toList(),
          ),
        ),
      ],
    );
  }
}

class _Badge {
  final IconData icon;
  final String label;
  final Color color;
  const _Badge(this.icon, this.label, this.color);
}

class _BadgeChip extends StatelessWidget {
  final _Badge badge;
  const _BadgeChip({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: badge.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
        border: Border.all(color: badge.color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: badge.color.withValues(alpha: 0.06), blurRadius: 12, spreadRadius: 1)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badge.color.withValues(alpha: 0.1),
            ),
            child: Icon(badge.icon, size: 11, color: badge.color),
          ),
          const SizedBox(width: 6),
          Text(
            badge.label,
            style: TextStyle(
              color: badge.color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Last 3 Nobs section — minimal, low-opacity character signal
// ---------------------------------------------------------------------------

class _LastNobsSection extends ConsumerWidget {
  const _LastNobsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authProvider).userId;
    if (userId == null) return const SizedBox.shrink();

    final nobsAsync = ref.watch(lastNobsProvider(userId));

    return nobsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (nobs) {
        if (nobs.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'N O B S',
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ...nobs.map((nob) {
                final text = nob.isThought ? nob.content : (nob.caption ?? '');
                return Opacity(
                  opacity: 0.6,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: _profileCard,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: nob.isPinned
                            ? AppColors.emerald600.withValues(alpha: 0.3)
                            : _profileBorder.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (nob.isPinned)
                          const Padding(
                            padding: EdgeInsets.only(right: AppSpacing.xs),
                            child: Icon(Icons.push_pin_rounded,
                                color: AppColors.emerald600, size: 10),
                          ),
                        Expanded(
                          child: Text(
                            text.isEmpty ? '(Moment Nob)' : text,
                            style: TextStyle(
                              color: context.textMuted,
                              fontSize: 12,
                              height: 1.45,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

