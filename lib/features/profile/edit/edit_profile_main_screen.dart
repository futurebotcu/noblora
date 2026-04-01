import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import 'edit_profile_provider.dart';
import 'widgets/profile_section_card.dart';
import 'sections/photos_media_section.dart';
import 'sections/basic_info_section.dart';
import 'sections/about_me_section.dart';
import 'sections/identity_life_section.dart';
import 'sections/relationship_section.dart';
import 'sections/interests_section.dart';
import 'sections/culture_social_section.dart';
import 'sections/travel_section.dart';
import 'sections/career_section.dart';
import 'sections/digital_life_section.dart';
import 'sections/lifestyle_section.dart';
import 'sections/prompts_section.dart';
import 'sections/visibility_section.dart';

class EditProfileMainScreen extends ConsumerWidget {
  const EditProfileMainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editProfileProvider);
    final d = state.draft;

    if (state.isLoading) {
      return Scaffold(
        backgroundColor: context.bgColor,
        body: const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    return Scaffold(
      backgroundColor: context.bgColor,
      body: CustomScrollView(
        slivers: [
          // ── Collapsing app bar ──
          SliverAppBar(
            expandedHeight: 0,
            pinned: true,
            backgroundColor: context.bgColor,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Edit Profile',
              style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ════════════════════════════════════════════════════════
                  // PHOTO HERO SECTION
                  // ════════════════════════════════════════════════════════
                  _PhotoHero(
                    photoUrls: d.photoUrls,
                    onTap: () => _push(context, const PhotosMediaSection()),
                  ),

                  const SizedBox(height: 28),

                  // ════════════════════════════════════════════════════════
                  // COMPLETION
                  // ════════════════════════════════════════════════════════
                  _CompletionStrip(score: d.completionScore),

                  const SizedBox(height: 24),

                  // ════════════════════════════════════════════════════════
                  // SECTION CARDS
                  // ════════════════════════════════════════════════════════

                  ProfileSectionCard(
                    icon: Icons.person_outline_rounded,
                    title: 'The Basics',
                    subtitle: _humanSub(d.basicInfoCount(), 9, 'Tell us a bit about yourself'),
                    progress: d.sectionProgress(d.basicInfoCount(), 9),
                    isEmpty: d.basicInfoCount() == 0,
                    preview: d.basicInfoPreview(),
                    onTap: () => _push(context, const BasicInfoSection()),
                  ),
                  ProfileSectionCard(
                    icon: Icons.auto_awesome_outlined,
                    title: 'In Your Own Words',
                    subtitle: _humanSub(d.aboutCount(), 4, 'Let your personality shine'),
                    progress: d.sectionProgress(d.aboutCount(), 4),
                    isEmpty: d.aboutCount() == 0,
                    preview: d.aboutPreview(),
                    onTap: () => _push(context, const AboutMeSection()),
                  ),
                  ProfileSectionCard(
                    icon: Icons.favorite_outline_rounded,
                    title: 'What You\'re Looking For',
                    subtitle: _humanSub(d.relationshipCount(), 6, 'Share your intentions honestly'),
                    progress: d.sectionProgress(d.relationshipCount(), 6),
                    isEmpty: d.relationshipCount() == 0,
                    preview: d.relationshipPreview(),
                    onTap: () => _push(context, const RelationshipSection()),
                  ),
                  ProfileSectionCard(
                    icon: Icons.local_fire_department_outlined,
                    title: 'Things You Love',
                    subtitle: d.interests.isEmpty
                        ? 'What makes you, you?'
                        : '${d.interests.length} interests',
                    progress: d.interests.isEmpty ? 0 : (d.interests.length / 20).clamp(0.0, 1.0),
                    isEmpty: d.interests.isEmpty,
                    preview: d.interestsPreview(),
                    onTap: () => _push(context, const InterestsSection()),
                  ),
                  ProfileSectionCard(
                    icon: Icons.fingerprint_rounded,
                    title: 'Who You Are',
                    subtitle: _humanSub(d.identityCount(), 8, 'Values, beliefs, and personality'),
                    progress: d.sectionProgress(d.identityCount(), 8),
                    isEmpty: d.identityCount() == 0,
                    preview: d.identityPreview(),
                    onTap: () => _push(context, const IdentityLifeSection()),
                  ),
                  ProfileSectionCard(
                    icon: Icons.music_note_outlined,
                    title: 'Culture & Taste',
                    subtitle: (d.musicGenres.length + d.movieGenres.length) == 0
                        ? 'Music, movies, and weekend vibes'
                        : '${d.musicGenres.length + d.movieGenres.length} tastes',
                    progress: (d.musicGenres.length + d.movieGenres.length) == 0 ? 0 : 0.5,
                    isEmpty: d.musicGenres.isEmpty && d.movieGenres.isEmpty,
                    preview: d.culturePreview(),
                    onTap: () => _push(context, const CultureSocialSection()),
                  ),
                  ProfileSectionCard(
                    icon: Icons.coffee_outlined,
                    title: 'Daily Rhythm',
                    subtitle: _humanSub(d.lifestyleCount, 5, 'How you move through life'),
                    progress: d.sectionProgress(d.lifestyleCount, 5),
                    isEmpty: d.lifestyleCount == 0,
                    preview: d.lifestylePreview(),
                    onTap: () => _push(context, const LifestyleSection()),
                  ),
                  ProfileSectionCard(
                    icon: Icons.flight_outlined,
                    title: 'Your World',
                    subtitle: d.visitedCountries.isEmpty
                        ? 'Where you\'ve been and where you dream of'
                        : '${d.visitedCountries.length} countries explored',
                    progress: d.visitedCountries.isEmpty ? 0 : 0.5,
                    isEmpty: d.visitedCountries.isEmpty,
                    preview: d.travelPreview(),
                    onTap: () => _push(context, const TravelSection()),
                  ),
                  ProfileSectionCard(
                    icon: Icons.rocket_launch_outlined,
                    title: 'What You\'re Building',
                    subtitle: _humanSub(d.careerCount(), 4, 'Your work and ambitions'),
                    progress: d.sectionProgress(d.careerCount(), 4),
                    isEmpty: d.careerCount() == 0,
                    preview: d.careerPreview(),
                    onTap: () => _push(context, const CareerSection()),
                  ),
                  ProfileSectionCard(
                    icon: Icons.smart_toy_outlined,
                    title: 'Digital World',
                    subtitle: d.aiTools.isEmpty
                        ? 'Your tech and digital life'
                        : '${d.aiTools.length} tools',
                    progress: d.aiTools.isEmpty ? 0 : 0.5,
                    isEmpty: d.aiTools.isEmpty,
                    preview: d.digitalPreview(),
                    onTap: () => _push(context, const DigitalLifeSection()),
                  ),
                  ProfileSectionCard(
                    icon: Icons.format_quote_rounded,
                    title: 'Conversation Starters',
                    subtitle: d.prompts.where((p) => p.answer.isNotEmpty).isEmpty
                        ? 'Answer prompts to spark connections'
                        : '${d.prompts.where((p) => p.answer.isNotEmpty).length}/3 answered',
                    progress: d.prompts.where((p) => p.answer.isNotEmpty).length / 3,
                    isEmpty: d.prompts.where((p) => p.answer.isNotEmpty).isEmpty,
                    preview: d.promptsPreview(),
                    onTap: () => _push(context, const PromptsSection()),
                  ),
                  ProfileSectionCard(
                    icon: Icons.shield_outlined,
                    title: 'Privacy',
                    subtitle: 'Control who sees what',
                    progress: d.visibility.isEmpty ? 0 : 0.5,
                    isEmpty: d.visibility.isEmpty,
                    onTap: () => _push(context, const VisibilitySection()),
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _humanSub(int filled, int total, String emptyMsg) {
    if (filled == 0) return emptyMsg;
    if (filled >= total) return 'Complete';
    return '$filled of $total filled';
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Photo Hero Section
// ═══════════════════════════════════════════════════════════════════════════════

class _PhotoHero extends StatelessWidget {
  final List<String> photoUrls;
  final VoidCallback onTap;

  const _PhotoHero({required this.photoUrls, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasPhotos = photoUrls.isNotEmpty;
    final mainUrl = hasPhotos ? photoUrls.first : null;
    final extras = hasPhotos ? photoUrls.skip(1).take(3).toList() : <String>[];

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          // Main photo — large hero
          Container(
            width: double.infinity,
            height: 280,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: context.surfaceColor,
              border: Border.all(
                color: hasPhotos
                    ? AppColors.gold.withValues(alpha: 0.15)
                    : context.borderColor.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: mainUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(mainUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _emptyPhoto(context)),
                        // Subtle gradient at bottom
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.6, 1.0],
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 14, right: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.edit_rounded, color: Colors.white, size: 13),
                              const SizedBox(width: 4),
                              Text('${photoUrls.length}/6', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ],
                    )
                  : _emptyPhoto(context),
            ),
          ),
          // Extra photo previews
          if (extras.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: Row(
                children: [
                  ...extras.map((url) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(url, fit: BoxFit.cover, height: 72,
                          errorBuilder: (_, __, ___) => Container(color: context.surfaceColor)),
                      ),
                    ),
                  )),
                  // Fill remaining slots
                  for (int i = extras.length; i < 3; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Container(
                          height: 72,
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.borderColor.withValues(alpha: 0.4)),
                          ),
                          child: Icon(Icons.add_rounded, color: context.textDisabled, size: 20),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: Row(
                children: List.generate(3, (i) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Container(
                      height: 72,
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.borderColor.withValues(alpha: 0.4)),
                      ),
                      child: Icon(Icons.add_photo_alternate_outlined, color: context.textDisabled, size: 20),
                    ),
                  ),
                )),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyPhoto(BuildContext context) {
    return Container(
      color: context.surfaceColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.08),
            ),
            child: Icon(Icons.camera_alt_outlined, color: AppColors.gold.withValues(alpha: 0.5), size: 28),
          ),
          const SizedBox(height: 12),
          const Text('Add your first photo',
            style: TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('People with photos get 10x more matches',
            style: TextStyle(color: context.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Completion Strip — compact, warm
// ═══════════════════════════════════════════════════════════════════════════════

class _CompletionStrip extends StatelessWidget {
  final int score;
  const _CompletionStrip({required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Circular progress
        SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 3,
                backgroundColor: context.borderColor.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
              ),
              Text('$score', style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                score >= 80 ? 'Looking great!'
                : score >= 50 ? 'Getting there'
                : 'Just getting started',
                style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                score >= 80 ? 'Your profile stands out.'
                : 'Add more to make your profile shine.',
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
