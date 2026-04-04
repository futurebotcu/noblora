import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/enums/noble_mode.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mode_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/active_modes_provider.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/tier_badge.dart';
import '../../providers/posts_provider.dart';
import '../noblara_feed/nob_drafts_screen.dart';
import '../noblara_feed/nob_archive_screen.dart';
import '../settings/settings_screen.dart';
import 'edit/edit_profile_main_screen.dart';

// ---------------------------------------------------------------------------
// Profile Screen
// ---------------------------------------------------------------------------

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final profile = ref.watch(profileProvider);
    final activeMode = ref.watch(modeProvider);

    final displayName =
        profile.profile?.fullName.isNotEmpty == true
            ? profile.profile!.fullName
            : (auth.email?.split('@').first ?? 'Noblara User');
    const city = '';

    return Scaffold(
      backgroundColor: context.bgColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: context.bgColor,
            elevation: 0,
            title: Text(
              'Profile',
              style: TextStyle(color: context.textPrimary, fontSize: 16),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.settings_outlined,
                    color: context.textPrimary),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _ProfileHeader(
                displayName: displayName,
                city: city,
                activeMode: activeMode,
                avatarUrl: profile.profile?.dateAvatarUrl ?? profile.profile?.bffAvatarUrl,
                userId: auth.userId,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                // Edit Profile button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Profile'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.emerald500,
                      side: const BorderSide(color: AppColors.emerald500, width: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileMainScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                const _ActiveModesSection(),
                const SizedBox(height: AppSpacing.xxxl),
                // Compact tier badge (full details in Status tab)
                if (profile.profile != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                    child: Row(
                      children: [
                        TierBadge(tier: profile.profile!.nobTier, showLabel: true),
                        const Spacer(),
                        Text('${profile.profile!.strengthLabel} profile',
                            style: TextStyle(color: context.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.xxxl),
                const _PersonaSection(),
                const SizedBox(height: AppSpacing.xxxl),
                const _NobleScorecardSection(),
                const SizedBox(height: AppSpacing.xxxl),
                const _GallerySection(),
                const SizedBox(height: AppSpacing.xxxl),
                const _BadgesSection(),
                const SizedBox(height: AppSpacing.xxxl),
                const _LastNobsSection(),
                const SizedBox(height: AppSpacing.xxxl),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: AppButton(
                    label: 'Sign Out',
                    variant: AppButtonVariant.outline,
                    onPressed: () async {
                      await ref.read(authProvider.notifier).signOut();
                      ref.read(profileProvider.notifier).clear();
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxxl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile Header — cover gradient + avatar + name/city/mode badge
// ---------------------------------------------------------------------------

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String city;
  final NobleMode activeMode;
  final String? avatarUrl;
  final String? userId;

  const _ProfileHeader({
    required this.displayName,
    required this.city,
    required this.activeMode,
    this.avatarUrl,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Cinematic gradient cover
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.35, 1.0],
              colors: [
                AppColors.emerald900.withValues(alpha: 0.15),
                AppColors.emerald900.withValues(alpha: 0.06),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // Avatar + info block
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 4))],
                  border:
                      Border.all(color: activeMode.accentColor, width: 2.5),
                ),
                child: ClipOval(
                  child: Image.network(
                    avatarUrl ?? 'https://picsum.photos/seed/${userId ?? 'me'}/200/200',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: activeMode.accentColor.withValues(alpha: 0.2),
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'N',
                          style: TextStyle(
                            fontSize: 36,
                            color: activeMode.accentColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                displayName,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on,
                      size: 13, color: context.textMuted),
                  const SizedBox(width: 3),
                  Text(
                    city,
                    style: TextStyle(
                        color: context.textMuted, fontSize: 13),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Active mode badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: activeMode.accentColor.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusCircle),
                      border: Border.all(
                          color: activeMode.accentColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(activeMode.icon,
                            size: 10, color: activeMode.accentColor),
                        const SizedBox(width: 4),
                        Text(
                          activeMode.label,
                          style: TextStyle(
                            color: activeMode.accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}


// ---------------------------------------------------------------------------
// Active Modes Section — toggle which modes you participate in
// ---------------------------------------------------------------------------

class _ActiveModesSection extends ConsumerWidget {
  const _ActiveModesSection();

  static const _modeInfo = [
    (mode: 'date', label: 'Dating', icon: Icons.favorite_rounded, color: AppColors.emerald500),
    (mode: 'bff', label: 'BFF', icon: Icons.people_rounded, color: AppColors.info),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modesState = ref.watch(activeModesProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MOD SEÇİMİ',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Hangi modlarda görünmek istediğini seç.',
            style: TextStyle(color: context.textDisabled, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...(_modeInfo.map((info) {
            final isActive = modesState.has(info.mode);
            final accent = info.color;
            return GestureDetector(
              onTap: () => ref.read(activeModesProvider.notifier).toggle(info.mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: isActive
                      ? accent.withValues(alpha: 0.12)
                      : context.surfaceColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: isActive
                        ? accent.withValues(alpha: 0.5)
                        : context.borderColor,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isActive ? 0.2 : 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(info.icon,
                          color: isActive ? accent : context.textMuted,
                          size: 18),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        info.label,
                        style: TextStyle(
                          color: isActive
                              ? context.textPrimary
                              : context.textMuted,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    // Toggle indicator
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 44,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isActive ? accent : context.surfaceAltColor,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusCircle),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 180),
                        alignment: isActive
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 18,
                          height: 18,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          })),
          if (modesState.error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                modesState.error!,
                style: const TextStyle(color: AppColors.error, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Persona Section — Multi-mode bio + photo editor
// ---------------------------------------------------------------------------

class _PersonaData {
  String bio;
  String avatarSeed;
  _PersonaData({required this.bio, required this.avatarSeed});
}

class _PersonaSection extends StatefulWidget {
  const _PersonaSection();

  @override
  State<_PersonaSection> createState() => _PersonaSectionState();
}

class _PersonaSectionState extends State<_PersonaSection> {
  NobleMode _selectedMode = NobleMode.date;

  final Map<NobleMode, _PersonaData> _personas = {
    NobleMode.date: _PersonaData(
      bio: 'Art lover & sunset chaser. Looking for someone to explore hidden '
          'galleries and share quiet evenings with. Probably overthinking the '
          'next travel destination.',
      avatarSeed: 'noble_me_date',
    ),
    NobleMode.bff: _PersonaData(
      bio: 'Design Lead obsessed with user psychology and minimalism. Always '
          'up for a coffee to talk product, creativity, or the best running '
          'trails in the city.',
      avatarSeed: 'noble_me_bff',
    ),
    NobleMode.social: _PersonaData(
      bio: 'Rooftop dinners, jazz bars, and spontaneous gallery openings. I '
          'curate experiences as carefully as my playlist. Let\'s build '
          'something memorable.',
      avatarSeed: 'noble_me_social',
    ),
  };

  void _openEdit(BuildContext context) {
    final current = _personas[_selectedMode]!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditPersonaSheet(
        mode: _selectedMode,
        initialBio: current.bio,
        initialSeed: current.avatarSeed,
        onSave: (bio, seed) {
          setState(() {
            _personas[_selectedMode] = _PersonaData(bio: bio, avatarSeed: seed);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final persona = _personas[_selectedMode]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Row(
            children: [
              Text(
                'YOUR PERSONAS',
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _openEdit(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusCircle),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined,
                          size: 12, color: context.textMuted),
                      const SizedBox(width: 4),
                      Text('Edit',
                          style: TextStyle(
                              color: context.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Mode selector pills (persona modes only — excludes noblara)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Row(
            children: NobleMode.values
                .where((m) => m != NobleMode.noblara)
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
                        : context.surfaceColor,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusCircle),
                    border: Border.all(
                      color: isActive ? mode.accentColor : context.borderColor,
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
            child: _PersonaCard(
              key: ValueKey(_selectedMode),
              persona: persona,
              mode: _selectedMode,
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonaCard extends StatelessWidget {
  final _PersonaData persona;
  final NobleMode mode;

  const _PersonaCard(
      {super.key, required this.persona, required this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border:
            Border.all(color: mode.accentColor.withValues(alpha: 0.25)),
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
              child: Image.network(
                'https://picsum.photos/seed/${persona.avatarSeed}/100/100',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: mode.accentColor.withValues(alpha: 0.15),
                  child: Icon(mode.icon, color: mode.accentColor, size: 24),
                ),
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
                  persona.bio,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 13,
                    height: 1.5,
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

class _EditPersonaSheet extends StatefulWidget {
  final NobleMode mode;
  final String initialBio;
  final String initialSeed;
  final void Function(String bio, String seed) onSave;

  const _EditPersonaSheet({
    required this.mode,
    required this.initialBio,
    required this.initialSeed,
    required this.onSave,
  });

  @override
  State<_EditPersonaSheet> createState() => _EditPersonaSheetState();
}

class _EditPersonaSheetState extends State<_EditPersonaSheet> {
  late final TextEditingController _bioCtrl;

  @override
  void initState() {
    super.initState();
    _bioCtrl = TextEditingController(text: widget.initialBio);
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xxl,
            AppSpacing.xxl,
            MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
          ),
          decoration: BoxDecoration(
            color: context.surfaceColor.withValues(alpha: 0.96),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                  color: mode.accentColor.withValues(alpha: 0.4), width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Icon(mode.icon, color: mode.accentColor, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Edit ${mode.label} Persona',
                    style: TextStyle(
                      color: mode.accentColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'BIO',
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _bioCtrl,
                maxLines: 4,
                maxLength: 300,
                style: TextStyle(
                    color: context.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText:
                      'Write your ${mode.label.toLowerCase()} persona bio...',
                  hintStyle:
                      TextStyle(color: context.textDisabled),
                  filled: true,
                  fillColor: context.surfaceAltColor,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  counterStyle: TextStyle(
                      color: context.textMuted, fontSize: 11),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onSave(_bioCtrl.text.trim(), widget.initialSeed);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mode.accentColor,
                    foregroundColor: context.bgColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  child: const Text(
                    'Save Persona',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
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
// Noble Scorecard — percentile + animated breakdown bars (AI explains tier)
// ---------------------------------------------------------------------------

class _NobleScorecardSection extends ConsumerStatefulWidget {
  const _NobleScorecardSection();

  @override
  ConsumerState<_NobleScorecardSection> createState() =>
      _NobleScorecardSectionState();
}

class _NobleScorecardSectionState extends ConsumerState<_NobleScorecardSection> {
  bool _animate = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _animate = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(profileProvider).profile;
    if (p == null) return const SizedBox.shrink();

    final maturity = p.maturityScore.round().clamp(0, 100);
    final bars = [
      _ScoreBar('Profile', p.profileCompletenessScore / 100),
      _ScoreBar('Community', p.communityScore / 100),
      _ScoreBar('Depth', p.depthScore / 100),
      _ScoreBar('Follow-through', p.followThroughScore / 100),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MATURITY SCORE',
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Based on your real activity',
                    style: TextStyle(
                        color: context.textDisabled, fontSize: 11),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.emerald500.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusCircle),
                  border: Border.all(
                      color: AppColors.emerald500.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 10, color: AppColors.emerald500),
                    const SizedBox(width: 4),
                    Text(
                      p.nobTier.label,
                      style: const TextStyle(
                          color: AppColors.emerald500,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border:
                  Border.all(color: AppColors.emerald500.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                // Score display
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$maturity',
                      style: const TextStyle(
                        color: AppColors.emerald500,
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    Text(
                      '/100',
                      style: TextStyle(
                        color: context.textMuted,
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'maturity',
                          style: TextStyle(
                              color: context.textMuted, fontSize: 12),
                        ),
                        Text(
                          p.strengthLabel,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Main bar
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusCircle),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                        begin: 0,
                        end: _animate ? maturity / 100.0 : 0),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, __) => LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      backgroundColor: context.surfaceAltColor,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.emerald500),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                // Breakdown bars
                ...bars.map((bar) =>
                    _ScoreBarRow(bar: bar, animate: _animate)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreBar {
  final String label;
  final double value;
  const _ScoreBar(this.label, this.value);
}

class _ScoreBarRow extends StatelessWidget {
  final _ScoreBar bar;
  final bool animate;

  const _ScoreBarRow({required this.bar, required this.animate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                bar.label,
                style: TextStyle(
                    color: context.textSecondary, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '${(bar.value * 100).toInt()}',
                style: const TextStyle(
                  color: AppColors.emerald500,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
            child: TweenAnimationBuilder<double>(
              tween:
                  Tween(begin: 0, end: animate ? bar.value : 0),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: context.surfaceAltColor,
                valueColor: AlwaysStoppedAnimation(
                    AppColors.emerald500.withValues(alpha: 0.6)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gallery Section — Mode-specific photo layouts
// ---------------------------------------------------------------------------

class _GallerySection extends StatefulWidget {
  const _GallerySection();

  @override
  State<_GallerySection> createState() => _GallerySectionState();
}

class _GallerySectionState extends State<_GallerySection> {
  NobleMode _galleryMode = NobleMode.date;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Row(
            children: [
              Text(
                'THE GALLERY',
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: NobleMode.values.map((mode) {
                  final isActive = mode == _galleryMode;
                  return GestureDetector(
                    onTap: () => setState(() => _galleryMode = mode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin:
                          const EdgeInsets.only(left: AppSpacing.xs),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? mode.accentColor
                            : context.surfaceColor,
                        border: Border.all(
                          color: isActive
                              ? mode.accentColor
                              : context.borderColor,
                        ),
                      ),
                      child: Icon(
                        mode.icon,
                        size: 13,
                        color: isActive
                            ? context.bgColor
                            : context.textMuted,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: _buildGallery(_galleryMode),
          ),
        ),
      ],
    );
  }

  Widget _buildGallery(NobleMode mode) {
    switch (mode) {
      case NobleMode.date:
        return const _DateGallery(key: ValueKey('date'));
      case NobleMode.bff:
        return const _BffGallery(key: ValueKey('bff'));
      case NobleMode.social:
        return const _SocialGallery(key: ValueKey('social'));
      case NobleMode.noblara:
        return const _DateGallery(key: ValueKey('noblara'));
    }
  }
}

// Art Gallery — Date mode
class _DateGallery extends StatelessWidget {
  const _DateGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GalleryFrame(
          seed: 'noble_date_1',
          caption: 'Santorini, 2024',
          title: 'Golden Hour',
          height: 260,
          accentColor: AppColors.emerald500,
          featured: true,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _GalleryFrame(
                seed: 'noble_date_2',
                caption: 'Istanbul Modern, 2024',
                title: 'Gallery Opening',
                height: 140,
                accentColor: AppColors.emerald500,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _GalleryFrame(
                seed: 'noble_date_3',
                caption: 'Bebek, Istanbul',
                title: 'Rooftop Soirée',
                height: 140,
                accentColor: AppColors.emerald500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GalleryFrame extends StatelessWidget {
  final String seed;
  final String title;
  final String caption;
  final double height;
  final Color accentColor;
  final bool featured;

  const _GalleryFrame({
    required this.seed,
    required this.title,
    required this.caption,
    required this.height,
    required this.accentColor,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border:
            Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius:
                BorderRadius.circular(AppSpacing.radiusMd - 1),
            child: Image.network(
              'https://picsum.photos/seed/$seed/400/${height.toInt()}',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: context.surfaceAltColor,
                child: Icon(Icons.image_outlined,
                    color: context.textDisabled),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppSpacing.radiusMd - 1)),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 24, 10, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.82),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (featured)
                      Text(
                        title,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    Text(
                      caption,
                      style: TextStyle(
                          color: context.textMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Professional Portfolio — BFF mode
class _BffGallery extends StatelessWidget {
  const _BffGallery({super.key});

  static const _seeds = [
    'noble_bff_1',
    'noble_bff_2',
    'noble_bff_3',
    'noble_bff_4',
  ];
  static const _labels = [
    'Product Launch',
    'Panel Talk',
    'Studio Session',
    'Team Offsite',
  ];

  @override
  Widget build(BuildContext context) {
    const teal = AppColors.info;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.0,
      ),
      itemCount: 4,
      itemBuilder: (_, i) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: teal.withValues(alpha: 0.25)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(AppSpacing.radiusMd - 1),
              child: Image.network(
                'https://picsum.photos/seed/${_seeds[i]}/300/300',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: context.surfaceAltColor),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    bottom:
                        Radius.circular(AppSpacing.radiusMd - 1)),
                child: Container(
                  padding:
                      const EdgeInsets.fromLTRB(8, 18, 8, 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                  child: Text(
                    _labels[i],
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Social Scene — Social mode
class _SocialGallery extends StatelessWidget {
  const _SocialGallery({super.key});

  static const _thumbSeeds = [
    'noble_social_1',
    'noble_social_2',
    'noble_social_3',
    'noble_social_4',
  ];
  static const _thumbLabels = ['Jazz Night', 'Art Walk', 'Wine Club', 'Rooftop'];

  @override
  Widget build(BuildContext context) {
    const violet = Color(0xFFAB47BC);
    return Column(
      children: [
        // Wide event cover
        Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
                color: violet.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusMd - 1),
                child: Image.network(
                  'https://picsum.photos/seed/noble_social_cover/800/400',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: context.surfaceAltColor),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      bottom:
                          Radius.circular(AppSpacing.radiusMd - 1)),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: violet.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'FEATURED EVENT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rooftop Sessions · Nişantaşı',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Event thumbnail strip
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppSpacing.md),
            itemBuilder: (_, i) => Container(
              width: 90,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(
                    color: violet.withValues(alpha: 0.25)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm - 1),
                    child: Image.network(
                      'https://picsum.photos/seed/${_thumbSeeds[i]}/200/200',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: context.surfaceAltColor),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    left: 4,
                    right: 4,
                    child: Text(
                      _thumbLabels[i],
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 4),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Badges Section — Elite credentials
// ---------------------------------------------------------------------------

class _BadgesSection extends StatelessWidget {
  const _BadgesSection();

  static const _badges = [
    _Badge(Icons.verified_rounded, 'Verified', AppColors.emerald500),
    _Badge(
        Icons.rocket_launch_rounded, 'Verified Founder', AppColors.info),
    _Badge(Icons.flight_rounded, 'World Traveler', Color(0xFF7986CB)),
    _Badge(Icons.palette_rounded, 'Art Collector', Color(0xFFAB47BC)),
    _Badge(Icons.star_rounded, 'Early Member', AppColors.emerald500),
    _Badge(Icons.emoji_events_rounded, 'Top 10%', AppColors.emerald200),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Text(
            'ELITE CREDENTIALS',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children:
                _badges.map((b) => _BadgeChip(badge: b)).toList(),
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
        color: badge.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCircle),
        border: Border.all(color: badge.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badge.icon, size: 13, color: badge.color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            badge.label,
            style: TextStyle(
              color: badge.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const NobDraftsScreen())),
                    child: const Text(
                      'Drafts',
                      style: TextStyle(
                        color: AppColors.noblaraGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const NobArchiveScreen())),
                    child: const Text(
                      'Archive',
                      style: TextStyle(
                        color: AppColors.noblaraGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
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
                      color: context.surfaceColor,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                        color: nob.isPinned
                            ? AppColors.noblaraGold.withValues(alpha: 0.25)
                            : context.borderColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (nob.isPinned)
                          const Padding(
                            padding: EdgeInsets.only(right: AppSpacing.xs),
                            child: Icon(Icons.push_pin_rounded,
                                color: AppColors.noblaraGold, size: 10),
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

