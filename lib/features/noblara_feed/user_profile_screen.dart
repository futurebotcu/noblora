import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/mock_mode.dart';
import '../../data/models/post.dart';
import '../../data/models/profile.dart';
import '../../providers/posts_provider.dart';
import '../../providers/profile_provider.dart';

// ---------------------------------------------------------------------------
// UserProfileScreen — view another user's public profile from Noblara
//
// Privacy: only shows profiles that RLS SELECT allows (is_onboarded &&
// !is_paused). Anonymous Nob authors never reach this screen because
// their user_id is NULL in the client model.
// ---------------------------------------------------------------------------

final _otherProfileProvider =
    FutureProvider.autoDispose.family<Profile?, String>((ref, userId) async {
  if (isMockMode) return null;
  final repo = ref.watch(profileRepositoryProvider);
  return repo.fetchProfile(userId);
});

class UserProfileScreen extends ConsumerWidget {
  final String userId;
  final String? initialName;
  final String? initialAvatarUrl;
  final NobTier initialTier;
  /// Whether the viewer has an active match/connection with this user.
  /// Affects 'Matches only' field visibility. Defaults to false (stranger).
  final bool isMatch;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.initialName,
    this.initialAvatarUrl,
    this.initialTier = NobTier.observer,
    this.isMatch = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(_otherProfileProvider(userId));
    final nobsAsync = ref.watch(lastNobsProvider(userId));

    return Scaffold(
      backgroundColor: context.bgColor,
      body: CustomScrollView(
        slivers: [
          // ── App bar with avatar ──
          SliverAppBar(
            backgroundColor: context.bgColor,
            surfaceTintColor: Colors.transparent,
            expandedHeight: 280,
            pinned: true,
            leading: BackButton(color: context.textPrimary),
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroHeader(
                name: initialName,
                avatarUrl: initialAvatarUrl,
                tier: initialTier,
                profile: profileAsync.asData?.value,
              ),
            ),
          ),

          // ── Profile body ──
          profileAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.emerald600)),
              ),
            ),
            error: (_, __) => SliverFillRemaining(
              child: Center(
                child: Text('Could not load profile.',
                    style: TextStyle(color: context.textMuted, fontSize: 13)),
              ),
            ),
            data: (profile) {
              if (profile == null) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text('Profile not available.',
                        style: TextStyle(color: context.textMuted, fontSize: 13)),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Occupation + Identity ──
                    if ((profile.occupation ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(profile.occupation!,
                            style: TextStyle(color: context.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
                      ),

                    // ── Bio ──
                    if ((profile.bio ?? '').isNotEmpty) ...[
                      Text(profile.bio!,
                          style: TextStyle(color: context.textPrimary, fontSize: 15, height: 1.6)),
                      const SizedBox(height: 4),
                    ],
                    if ((profile.currentFocus ?? '').isNotEmpty && profile.canViewField('current_focus', isMatch: isMatch))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(children: [
                          Icon(Icons.flag_rounded, color: AppColors.emerald600.withValues(alpha: 0.6), size: 14),
                          const SizedBox(width: 6),
                          Expanded(child: Text(profile.currentFocus!,
                              style: TextStyle(color: context.textSecondary, fontSize: 13, fontStyle: FontStyle.italic))),
                        ]),
                      ),

                    // ── Info chips ──
                    _InfoSection(profile: profile),

                    // ── Photos ──
                    if (profile.photoUrls.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _SectionLabel('Photos'),
                      const SizedBox(height: 10),
                      _PhotoGrid(urls: profile.photoUrls),
                    ],

                    // ── Prompts / Conversation starters ──
                    if (profile.prompts.any((p) => p.hasAnswer) && profile.canViewField('prompts', isMatch: isMatch)) ...[
                      const SizedBox(height: 24),
                      _SectionLabel('Conversation Starters'),
                      const SizedBox(height: 10),
                      ...profile.prompts.where((p) => p.hasAnswer).map((p) =>
                        _PromptCard(question: p.question, answer: p.answer)),
                    ],

                    // ── Interests ──
                    if (profile.interests.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _SectionLabel('Interests'),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8,
                        children: profile.interests.map((i) => _Chip(i)).toList()),
                    ],

                    // ── Relationship & Style ──
                    if (profile.canViewField('relationship', isMatch: isMatch) && _hasRelationshipData(profile)) ...[
                      const SizedBox(height: 24),
                      _SectionLabel('Relationship & Style'),
                      const SizedBox(height: 10),
                      if (profile.loveLanguages.isNotEmpty)
                        _MiniRow(Icons.favorite_border_rounded, 'Love languages', profile.loveLanguages.join(', ')),
                      if (profile.communicationStyle.isNotEmpty)
                        _MiniRow(Icons.chat_outlined, 'Communication', profile.communicationStyle.join(', ')),
                      if (profile.datingStyle.isNotEmpty)
                        _MiniRow(Icons.psychology_outlined, 'Dating style', profile.datingStyle.join(', ')),
                    ],

                    // ── Lifestyle ──
                    if (profile.canViewField('lifestyle', isMatch: isMatch) && _hasLifestyleData(profile)) ...[
                      const SizedBox(height: 24),
                      _SectionLabel('Lifestyle'),
                      const SizedBox(height: 10),
                      if (profile.sleepStyle != null) _MiniRow(Icons.bedtime_outlined, 'Sleep', profile.sleepStyle!),
                      if (profile.dietStyle != null) _MiniRow(Icons.restaurant_outlined, 'Diet', profile.dietStyle!),
                      if (profile.fitnessRoutine != null) _MiniRow(Icons.fitness_center_outlined, 'Fitness', profile.fitnessRoutine!),
                    ],

                    // ── Career & Building ──
                    if (profile.canViewField('career', isMatch: isMatch) && _hasCareerData(profile)) ...[
                      const SizedBox(height: 24),
                      _SectionLabel('Career & Building'),
                      const SizedBox(height: 10),
                      if (profile.industry.isNotEmpty)
                        _MiniRow(Icons.business_outlined, 'Industry', profile.industry.join(', ')),
                      if (profile.workStyle != null)
                        _MiniRow(Icons.work_outline_rounded, 'Work style', profile.workStyle!),
                      if (profile.buildingNow.isNotEmpty)
                        _MiniRow(Icons.build_outlined, 'Building', profile.buildingNow.join(', ')),
                    ],

                    // ── Culture ──
                    if (profile.canViewField('culture', isMatch: isMatch) && _hasCultureData(profile)) ...[
                      const SizedBox(height: 24),
                      _SectionLabel('Culture & Taste'),
                      const SizedBox(height: 10),
                      if (profile.musicGenres.isNotEmpty)
                        Wrap(spacing: 6, runSpacing: 6,
                          children: profile.musicGenres.map((m) => _Chip(m)).toList()),
                      if (profile.weekendStyle.isNotEmpty)
                        Padding(padding: const EdgeInsets.only(top: 8),
                          child: _MiniRow(Icons.weekend_outlined, 'Weekends', profile.weekendStyle.join(', '))),
                    ],

                    // ── Travel ──
                    if (profile.canViewField('travel', isMatch: isMatch) && _hasTravelData(profile)) ...[
                      const SizedBox(height: 24),
                      _SectionLabel('Travel'),
                      const SizedBox(height: 10),
                      if (profile.countriesVisited.isNotEmpty)
                        _MiniRow(Icons.flight_outlined, 'Visited', profile.countriesVisited.take(5).join(', ')),
                      if (profile.travelStyle.isNotEmpty)
                        _MiniRow(Icons.luggage_outlined, 'Style', profile.travelStyle.join(', ')),
                    ],

                    // ── Digital Life ──
                    if (profile.canViewField('digital', isMatch: isMatch) && profile.aiTools.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _SectionLabel('Digital Life'),
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6,
                        children: profile.aiTools.map((t) => _Chip(t)).toList()),
                    ],

                    // ── Languages ──
                    if (profile.languages.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _SectionLabel('Languages'),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8,
                        children: profile.languages.map((l) => _Chip(l)).toList()),
                    ],

                    // ── Recent Nobs ──
                    const SizedBox(height: 24),
                    _SectionLabel('Recent Nobs'),
                    const SizedBox(height: 10),
                    nobsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 1, color: AppColors.emerald600))),
                      ),
                      error: (_, __) => Text('Could not load.',
                          style: TextStyle(color: context.textMuted, fontSize: 12)),
                      data: (nobs) {
                        if (nobs.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text('No public Nobs yet.',
                                style: TextStyle(color: context.textMuted, fontSize: 13)),
                          );
                        }
                        return Column(
                          children: nobs.map((n) => _NobPreview(nob: n)).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 40),
                  ]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero header — avatar, name, tier, modes
// ---------------------------------------------------------------------------

class _HeroHeader extends StatelessWidget {
  final String? name;
  final String? avatarUrl;
  final NobTier tier;
  final Profile? profile;

  const _HeroHeader({
    this.name,
    this.avatarUrl,
    this.tier = NobTier.observer,
    this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = profile?.displayName ?? name ?? 'Someone';
    final avatar = profile?.dateAvatarUrl ?? profile?.bffAvatarUrl ?? avatarUrl;
    final displayTier = profile?.nobTier ?? tier;
    final tierColor = switch (displayTier) {
      NobTier.noble => AppColors.nobNoble,
      NobTier.explorer => AppColors.nobExplorer,
      NobTier.observer => AppColors.nobObserver,
    };

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tierColor.withValues(alpha: 0.08),
            context.bgColor,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Avatar
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tierColor.withValues(alpha: 0.12),
                border: Border.all(color: tierColor.withValues(alpha: 0.35), width: 2),
              ),
              child: avatar != null
                  ? ClipOval(child: CachedNetworkImage(
                      imageUrl: avatar, fit: BoxFit.cover, width: 88, height: 88,
                      memCacheWidth: 264,
                    ))
                  : Center(child: Text(
                      displayName[0].toUpperCase(),
                      style: TextStyle(color: tierColor, fontWeight: FontWeight.w700, fontSize: 32),
                    )),
            ),
            const SizedBox(height: 14),
            // Name — editorial hero
            Text(displayName,
                style: TextStyle(color: context.textPrimary, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            // Tier + mode badges
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Badge(displayTier.label.toUpperCase(), tierColor),
                if (profile?.city != null) ...[
                  const SizedBox(width: 8),
                  _Badge(profile!.city!, context.textMuted),
                ],
                if (profile?.age != null) ...[
                  const SizedBox(width: 8),
                  _Badge('${profile!.age}', context.textMuted),
                ],
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data presence helpers
// ---------------------------------------------------------------------------

bool _hasRelationshipData(Profile p) =>
    p.loveLanguages.isNotEmpty || p.communicationStyle.isNotEmpty || p.datingStyle.isNotEmpty;

bool _hasLifestyleData(Profile p) =>
    p.sleepStyle != null || p.dietStyle != null || p.fitnessRoutine != null;

bool _hasCareerData(Profile p) =>
    p.industry.isNotEmpty || p.workStyle != null || p.buildingNow.isNotEmpty;

bool _hasCultureData(Profile p) =>
    p.musicGenres.isNotEmpty || p.weekendStyle.isNotEmpty;

bool _hasTravelData(Profile p) =>
    p.countriesVisited.isNotEmpty || p.travelStyle.isNotEmpty;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5));
  }
}

class _InfoSection extends StatelessWidget {
  final Profile profile;
  const _InfoSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String)>[
      if (profile.occupation != null) (Icons.work_outline_rounded, profile.occupation!),
      if (profile.fromCountry != null) (Icons.public_rounded, profile.fromCountry!),
      if (profile.height != null) (Icons.straighten_rounded, '${profile.height} cm'),
      if (profile.vibe != null) (Icons.mood_rounded, profile.vibe!),
      if (profile.lookingFor != null) (Icons.search_rounded, profile.lookingFor!),
      if (profile.philosophy != null) (Icons.auto_stories_rounded, profile.philosophy!),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(item.$1, color: context.textMuted, size: 16),
            const SizedBox(width: 10),
            Expanded(child: Text(item.$2,
                style: TextStyle(color: context.textSecondary, fontSize: 14, height: 1.4))),
          ],
        ),
      )).toList(),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: context.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w500)),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  final List<String> urls;
  const _PhotoGrid({required this.urls});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: urls.length,
      itemBuilder: (_, i) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: urls[i],
          fit: BoxFit.cover,
          memCacheWidth: 360,
          errorWidget: (_, __, ___) => Container(
            color: context.surfaceAltColor,
            child: Icon(Icons.image_not_supported_outlined, color: context.textMuted, size: 20),
          ),
        ),
      ),
    );
  }
}

class _NobPreview extends StatelessWidget {
  final Post nob;
  const _NobPreview({required this.nob});

  @override
  Widget build(BuildContext context) {
    final text = nob.isThought ? nob.content : (nob.caption ?? '');
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor.withValues(alpha: 0.4)),
        ),
        child: Text(text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.textPrimary, fontSize: 13.5, height: 1.4, fontStyle: FontStyle.italic)),
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  final String question;
  final String answer;
  const _PromptCard({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.emerald600.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question,
                style: TextStyle(color: AppColors.emerald600.withValues(alpha: 0.8), fontSize: 11,
                    fontWeight: FontWeight.w600, letterSpacing: 0.3)),
            const SizedBox(height: 8),
            Text(answer,
                style: TextStyle(color: context.textPrimary, fontSize: 14, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MiniRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.textMuted, size: 15),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(color: context.textMuted, fontSize: 12.5, fontWeight: FontWeight.w500)),
          Expanded(child: Text(value,
              style: TextStyle(color: context.textSecondary, fontSize: 12.5, height: 1.3))),
        ],
      ),
    );
  }
}
