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
import '../../shared/widgets/tier_badge.dart';
import '../../providers/posts_provider.dart';
import '../settings/settings_screen.dart';
import '../verification/verification_hub_screen.dart';
import 'edit/edit_profile_main_screen.dart';

// ---------------------------------------------------------------------------
// Profile-specific editorial surfaces — lighter than global dark theme
// to give the profile a "luxury magazine" feel without changing app-wide colors.
// ---------------------------------------------------------------------------

const _profileBg       = Color(0xFF1A211E);  // warm dark sage (editorial base)
const _profileCard     = Color(0xFF283130);  // lifted card (clearly distinct from bg)
const _profileElevated = Color(0xFF323B38);  // highlight card (prompts, chips)
const _profileBorder   = Color(0xFF445049);  // strong visible edge
const _profileDivider  = Color(0xFF3A4440);  // section divider

// ---------------------------------------------------------------------------
// Profile Screen
// ---------------------------------------------------------------------------

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final profile = ref.watch(profileProvider);
    final p = profile.profile;
    final displayName =
        p?.fullName.isNotEmpty == true
            ? p!.fullName
            : (auth.email?.split('@').first ?? 'Noblara User');
    final city = p?.city ?? '';
    final age = p?.age;
    final completeness = p?.profileCompletenessScore ?? 0;
    final isVerified = (p?.trustScore ?? 0) > 60;

    return Scaffold(
      backgroundColor: _profileBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: _profileBg,
            elevation: 0,
            title: Text(
              'Profile',
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.settings_outlined,
                    color: context.textPrimary, size: 22),
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
                age: age,
                tierLabel: p?.nobTier.label ?? 'Observer',
                tier: p?.nobTier,
                avatarUrl: p?.dateAvatarUrl ?? p?.bffAvatarUrl,
                userId: auth.userId,
                completeness: completeness,
                isVerified: isVerified,
                strengthLabel: p?.strengthLabel ?? 'Just starting',
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Identity snapshot (occupation + tagline) ──
                if (p != null && ((p.occupation ?? '').isNotEmpty || (p.tagline ?? '').isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((p.occupation ?? '').isNotEmpty)
                          Text(p.occupation!,
                              style: TextStyle(color: context.textSecondary, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.2)),
                        if ((p.tagline ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('"${p.tagline}"',
                              style: TextStyle(color: context.textPrimary.withValues(alpha: 0.7), fontSize: 13, fontStyle: FontStyle.italic, height: 1.4)),
                        ],
                      ],
                    ),
                  ),

                // ── Compact utility strip ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      _CompactAction(icon: Icons.edit_outlined, label: 'Edit',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileMainScreen()))),
                      const SizedBox(width: 8),
                      _CompactAction(icon: Icons.verified_outlined, label: 'Verify',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerificationHubScreen()))),
                      const SizedBox(width: 8),
                      _CompactAction(icon: Icons.settings_outlined, label: 'Settings',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
                      const Spacer(),
                      const _ActiveModesCompact(),
                    ],
                  ),
                ),

                // ── Photos (moved up — visual identity first) ──
                const SizedBox(height: 24),
                _RealGallerySection(profile: p),

                // ── About / Rich Profile Sections ──
                if (p != null) ...[
                  const SizedBox(height: 28),
                  _RichProfileSections(profile: p),
                ],

                // ── Profile Facts (interests, languages, etc.) ──
                const SizedBox(height: 24),
                _ProfileFactsSection(profile: p),

                // ── Mode Persona ──
                const SizedBox(height: 28),
                _PersonaSection(profile: p),

                // ── Badges & Signals ──
                const SizedBox(height: 28),
                _EarnedBadgesSection(profile: p),

                // ── Recent Nobs ──
                const SizedBox(height: 28),
                const _LastNobsSection(),
                const SizedBox(height: 40),
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
  final int? age;
  final String tierLabel;
  final dynamic tier; // NobTier
  final String? avatarUrl;
  final String? userId;
  final int completeness;
  final bool isVerified;
  final String strengthLabel;

  const _ProfileHeader({
    required this.displayName,
    required this.city,
    this.age,
    required this.tierLabel,
    this.tier,
    this.avatarUrl,
    this.userId,
    this.completeness = 0,
    this.isVerified = false,
    this.strengthLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(decoration: BoxDecoration(gradient: Premium.heroGradient())),
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Column(
            children: [
              // Avatar with completeness ring + verification badge
              SizedBox(
                width: 108,
                height: 108,
                child: Stack(
                  children: [
                    // Completeness ring
                    Positioned.fill(
                      child: CircularProgressIndicator(
                        value: completeness / 100,
                        strokeWidth: 2.5,
                        backgroundColor: AppColors.border.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation(
                            completeness >= 80
                                ? AppColors.emerald500
                                : completeness >= 40
                                    ? AppColors.emerald600
                                    : AppColors.textMuted),
                      ),
                    ),
                    // Avatar
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            ...Premium.shadowMd,
                            BoxShadow(
                              color: AppColors.emerald600.withValues(alpha: 0.12),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatarUrl ?? 'https://picsum.photos/seed/${userId ?? 'me'}/200/200',
                            fit: BoxFit.cover,
                            memCacheWidth: 600,
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.emerald600.withValues(alpha: 0.15),
                              child: Center(
                                child: Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : 'N',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    color: AppColors.emerald600,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Verified badge
                    if (isVerified)
                      Positioned(
                        bottom: 2,
                        right: 4,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.emerald600,
                            shape: BoxShape.circle,
                            border: Border.all(color: context.bgColor, width: 2.5),
                            boxShadow: Premium.shadowSm,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 13),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Name + age — editorial hero text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (age != null)
                    Text(
                      ', $age',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              // City + Tier badge + strength
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (city.isNotEmpty) ...[
                    Icon(Icons.location_on, size: 12, color: context.textMuted),
                    const SizedBox(width: 2),
                    Text(city, style: TextStyle(color: context.textMuted, fontSize: 12)),
                    Container(
                      width: 3, height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: context.textDisabled,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                  if (tier != null)
                    TierBadge(tier: tier, showLabel: true, size: 18),
                  if (strengthLabel.isNotEmpty) ...[
                    Container(
                      width: 3, height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: context.textDisabled,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(strengthLabel,
                        style: TextStyle(
                            color: context.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Quick action button for profile
class _CompactAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CompactAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _profileCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _profileBorder.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: context.textMuted, size: 14),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: context.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _ActiveModesCompact extends ConsumerWidget {
  const _ActiveModesCompact();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modes = ref.watch(activeModesProvider);
    final active = modes.modes;
    if (active.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (active.contains('date'))
          _ModePill(Icons.favorite_rounded, 'Date', AppColors.emerald500),
        if (active.contains('bff')) ...[
          const SizedBox(width: 6),
          _ModePill(Icons.people_rounded, 'BFF', AppColors.emerald600),
        ],
      ],
    );
  }
}

class _ModePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _ModePill(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active Modes Section (legacy — kept for mode toggle functionality)
// ---------------------------------------------------------------------------

// ignore: unused_element
class _ActiveModesSection extends ConsumerWidget {
  const _ActiveModesSection();

  static const _modeInfo = [
    (mode: 'date', label: 'Dating', icon: Icons.favorite_rounded, color: AppColors.emerald500),
    (mode: 'bff', label: 'BFF', icon: Icons.people_rounded, color: AppColors.emerald500),
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
            'MODE SELECTION',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Choose which modes you appear in.',
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
                        color: isActive ? accent : _profileElevated,
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
// Profile Facts — zodiac, country, occupation, interests
// ---------------------------------------------------------------------------

class _ProfileFactsSection extends StatelessWidget {
  final Profile? profile;
  const _ProfileFactsSection({this.profile});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (p == null) return const SizedBox.shrink();

    final facts = <(IconData, String, String)>[];
    if (p.occupation != null && p.occupation!.isNotEmpty) {
      facts.add((Icons.work_outline_rounded, 'Work', p.occupation!));
    }
    if (p.fromCountry != null && p.fromCountry!.isNotEmpty) {
      facts.add((Icons.public_rounded, 'From', p.fromCountry!));
    }
    if (p.zodiac != null && p.zodiac!.isNotEmpty) {
      facts.add((Icons.auto_awesome_outlined, 'Zodiac', p.zodiac!));
    }
    if (p.languages.isNotEmpty) {
      facts.add((Icons.translate_rounded, 'Languages', p.languages.join(', ')));
    }

    final hasInterests = p.interests.isNotEmpty;

    if (facts.isEmpty && !hasInterests) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.xxxl),
          decoration: BoxDecoration(
            color: _profileCard,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: _profileBorder.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _profileElevated,
                ),
                child: Icon(Icons.auto_awesome_outlined,
                    color: AppColors.emerald600.withValues(alpha: 0.7), size: 24),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Build your story',
                  style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              const SizedBox(height: 6),
              Text('The details you add shape how others discover you',
                  style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.4),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ABOUT', style: TextStyle(color: context.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2)),
          const SizedBox(height: AppSpacing.lg),
          if (facts.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _profileCard,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: _profileBorder.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 14, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: facts.asMap().entries.map((entry) {
                  final f = entry.value;
                  final isLast = entry.key == facts.length - 1;
                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _profileElevated,
                            ),
                            child: Icon(f.$1, size: 14, color: AppColors.emerald600),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(f.$2, style: TextStyle(color: context.textMuted.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w400, letterSpacing: 0.3)),
                          const Spacer(),
                          Flexible(child: Text(f.$3,
                              style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.end)),
                        ],
                      ),
                    ),
                    if (!isLast) Divider(height: 1, color: _profileDivider.withValues(alpha: 0.5), indent: 44),
                  ]);
                }).toList(),
              ),
            ),
          if (hasInterests) ...[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: p.interests.map((interest) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _profileElevated,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: _profileBorder.withValues(alpha: 0.35)),
                ),
                child: Text(interest,
                    style: TextStyle(color: context.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
              )).toList(),
            ),
          ],
        ],
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
              color: _profileCard,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border:
                  Border.all(color: _profileBorder.withValues(alpha: 0.4)),
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
                      backgroundColor: _profileElevated,
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
                backgroundColor: _profileElevated,
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
// Rich profile sections — prompts, relationship, lifestyle, career, etc.
// Only renders sections with data, matching UserProfileScreen richness.
// ---------------------------------------------------------------------------

class _RichProfileSections extends StatelessWidget {
  final Profile profile;
  const _RichProfileSections({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tagline ──
          if ((profile.tagline ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '"${profile.tagline}"',
                style: TextStyle(color: context.textPrimary, fontSize: 15, fontStyle: FontStyle.italic, height: 1.5),
              ),
            ),

          // ── Long Bio ──
          if ((profile.longBio ?? '').isNotEmpty)
            _RichCard(
              icon: Icons.auto_stories_rounded,
              title: 'About Me',
              child: Text(profile.longBio!,
                  style: TextStyle(color: context.textPrimary, fontSize: 13.5, height: 1.6)),
            ),

          // ── Current Focus ──
          if ((profile.currentFocus ?? '').isNotEmpty)
            _RichCard(
              icon: Icons.flag_rounded,
              title: 'Current Focus',
              child: Text(profile.currentFocus!,
                  style: TextStyle(color: context.textPrimary, fontSize: 14, height: 1.5, fontStyle: FontStyle.italic)),
            ),

          // ── Prompts — editorial prompt cards ──
          if (profile.prompts.any((p) => p.hasAnswer))
            ...profile.prompts.where((p) => p.hasAnswer).map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                decoration: BoxDecoration(
                  color: _profileElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.emerald600.withValues(alpha: 0.18)),
                  boxShadow: [
                    BoxShadow(color: AppColors.emerald600.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.question.toUpperCase(),
                        style: TextStyle(color: AppColors.emerald600, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                    const SizedBox(height: 10),
                    Text(p.answer, style: TextStyle(color: context.textPrimary, fontSize: 15, height: 1.55, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            )),

          // ── Relationship & Style ──
          if (profile.loveLanguages.isNotEmpty || profile.communicationStyle.isNotEmpty || profile.datingStyle.isNotEmpty)
            _RichCard(
              icon: Icons.favorite_border_rounded,
              title: 'Relationship & Style',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (profile.loveLanguages.isNotEmpty)
                    _FactRow('Love languages', profile.loveLanguages.join(', ')),
                  if (profile.communicationStyle.isNotEmpty)
                    _FactRow('Communication', profile.communicationStyle.join(', ')),
                  if (profile.datingStyle.isNotEmpty)
                    _FactRow('Dating style', profile.datingStyle.join(', ')),
                ],
              ),
            ),

          // ── Lifestyle ──
          if (profile.sleepStyle != null || profile.dietStyle != null || profile.fitnessRoutine != null)
            _RichCard(
              icon: Icons.self_improvement_rounded,
              title: 'Lifestyle',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (profile.sleepStyle != null) _FactRow('Sleep', profile.sleepStyle!),
                  if (profile.dietStyle != null) _FactRow('Diet', profile.dietStyle!),
                  if (profile.fitnessRoutine != null) _FactRow('Fitness', profile.fitnessRoutine!),
                ],
              ),
            ),

          // ── Career & Building ──
          if (profile.industry.isNotEmpty || profile.workStyle != null || profile.buildingNow.isNotEmpty)
            _RichCard(
              icon: Icons.rocket_launch_outlined,
              title: 'Career & Building',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (profile.industry.isNotEmpty) _FactRow('Industry', profile.industry.join(', ')),
                  if (profile.workStyle != null) _FactRow('Work style', profile.workStyle!),
                  if (profile.buildingNow.isNotEmpty) _FactRow('Building', profile.buildingNow.join(', ')),
                  if (profile.entrepreneurshipStatus != null) _FactRow('Status', profile.entrepreneurshipStatus!),
                ],
              ),
            ),

          // ── Culture & Taste ──
          if (profile.musicGenres.isNotEmpty || profile.weekendStyle.isNotEmpty)
            _RichCard(
              icon: Icons.palette_outlined,
              title: 'Culture & Taste',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (profile.musicGenres.isNotEmpty)
                    Wrap(spacing: 6, runSpacing: 6, children: profile.musicGenres.map((m) =>
                      _MiniChip(m)).toList()),
                  if (profile.weekendStyle.isNotEmpty) ...[
                    if (profile.musicGenres.isNotEmpty) const SizedBox(height: 10),
                    _FactRow('Weekends', profile.weekendStyle.join(', ')),
                  ],
                  if (profile.humorStyle.isNotEmpty)
                    _FactRow('Humor', profile.humorStyle.join(', ')),
                ],
              ),
            ),

          // ── Travel ──
          if (profile.countriesVisited.isNotEmpty || profile.travelStyle.isNotEmpty)
            _RichCard(
              icon: Icons.flight_outlined,
              title: 'Travel',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (profile.countriesVisited.isNotEmpty)
                    _FactRow('Visited', profile.countriesVisited.take(8).join(', ')),
                  if (profile.livedCountries.isNotEmpty)
                    _FactRow('Lived in', profile.livedCountries.join(', ')),
                  if (profile.travelStyle.isNotEmpty)
                    _FactRow('Style', profile.travelStyle.join(', ')),
                ],
              ),
            ),

          // ── Digital Life ──
          if (profile.aiTools.isNotEmpty)
            _RichCard(
              icon: Icons.memory_rounded,
              title: 'Digital Life',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 6, runSpacing: 6, children: profile.aiTools.map((t) =>
                    _MiniChip(t)).toList()),
                  if (profile.techRelation != null) ...[
                    const SizedBox(height: 10),
                    _FactRow('Tech', profile.techRelation!),
                  ],
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
// Real Gallery — user's actual photos
// ---------------------------------------------------------------------------

class _RealGallerySection extends StatelessWidget {
  final Profile? profile;
  const _RealGallerySection({this.profile});

  @override
  Widget build(BuildContext context) {
    final photos = profile?.photoUrls ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Text('PHOTOS', style: Premium.sectionHeader(context.textMuted)),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (photos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.xxxl),
              decoration: BoxDecoration(
                gradient: Premium.surfaceGradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.emerald600.withValues(alpha: 0.08)),
                boxShadow: Premium.shadowSm,
              ),
              child: Column(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.emerald600.withValues(alpha: 0.12), AppColors.emerald600.withValues(alpha: 0.04)],
                      ),
                    ),
                    child: Icon(Icons.camera_alt_outlined,
                        color: AppColors.emerald500.withValues(alpha: 0.6), size: 24),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Add your photos',
                      style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                  const SizedBox(height: 6),
                  Text('Profiles with photos get 10x more attention',
                      style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.4),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: photos.length == 1 ? 1 : 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: photos.length == 1 ? 1.1 : 0.75,
              ),
              itemCount: photos.length,
              itemBuilder: (_, i) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  boxShadow: Premium.shadowSm,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: photos[i],
                        fit: BoxFit.cover,
                        memCacheWidth: 500,
                        placeholder: (_, __) => Container(
                          decoration: BoxDecoration(
                            gradient: Premium.surfaceGradient,
                          ),
                          child: Center(child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.emerald500.withValues(alpha: 0.3))),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: _profileElevated,
                          child: Icon(Icons.image_outlined, color: context.textDisabled, size: 28),
                        ),
                      ),
                      // Subtle vignette for depth
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.0, 0.6, 1.0],
                              colors: [
                                Colors.transparent,
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
            ),
          ),
      ],
    );
  }
}

// (NoblaraGallery removed — LastNobsSection handles nob display)

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

