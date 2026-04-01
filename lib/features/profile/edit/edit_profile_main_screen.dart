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
          SliverAppBar(
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
                  // ═══ PHOTO HERO ═══
                  _PhotoHero(
                    photoUrls: d.photoUrls,
                    onEdit: () => _push(context, const PhotosMediaSection()),
                  ),

                  const SizedBox(height: 20),

                  // ═══ HOOK BANNER ═══
                  if (d.completionScore < 80)
                    _HookBanner(score: d.completionScore),

                  if (d.completionScore < 80)
                    const SizedBox(height: 20),

                  // ═══ COMPLETION ═══
                  _CompletionStrip(score: d.completionScore),

                  const SizedBox(height: 22),

                  // ═══ SECTION CARDS ═══
                  ProfileSectionCard(
                    icon: Icons.person_outline_rounded,
                    title: 'The Basics',
                    subtitle: _sub(d.basicInfoCount(), 9, 'Tell us a bit about yourself'),
                    progress: d.sectionProgress(d.basicInfoCount(), 9),
                    isEmpty: d.basicInfoCount() == 0,
                    previewChips: _chips(d.basicInfoPreview()),
                    onTap: () => _push(context, const BasicInfoSection()),
                  ),
                  ProfileSectionCard(
                    icon: Icons.auto_awesome_outlined,
                    title: 'In Your Own Words',
                    subtitle: _sub(d.aboutCount(), 4, 'Let your personality shine'),
                    progress: d.sectionProgress(d.aboutCount(), 4),
                    isEmpty: d.aboutCount() == 0,
                    previewChips: d.aboutPreview() != null ? [d.aboutPreview()!] : [],
                    onTap: () => _push(context, const AboutMeSection()),
                  ),
                  ProfileSectionCard(
                    icon: Icons.favorite_outline_rounded,
                    title: 'What You\'re Looking For',
                    subtitle: _sub(d.relationshipCount(), 6, 'Share your intentions honestly'),
                    progress: d.sectionProgress(d.relationshipCount(), 6),
                    isEmpty: d.relationshipCount() == 0,
                    previewChips: _chips(d.relationshipPreview()),
                    onTap: () => _push(context, const RelationshipSection()),
                  ),
                  ProfileSectionCard(
                    icon: Icons.local_fire_department_outlined,
                    title: 'Things You Love',
                    subtitle: d.interests.isEmpty ? 'What makes you, you?' : '${d.interests.length} interests',
                    progress: d.interests.isEmpty ? 0 : (d.interests.length / 20).clamp(0.0, 1.0),
                    isEmpty: d.interests.isEmpty,
                    previewChips: d.interests.take(5).toList(),
                    onTap: () => _push(context, const InterestsSection()),
                  ),
                  ProfileSectionCard(
                    icon: Icons.fingerprint_rounded,
                    title: 'Who You Are',
                    subtitle: _sub(d.identityCount(), 8, 'Values, beliefs, and personality'),
                    progress: d.sectionProgress(d.identityCount(), 8),
                    isEmpty: d.identityCount() == 0,
                    previewChips: _chips(d.identityPreview()),
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
                    previewChips: [...d.musicGenres.take(3), ...d.movieGenres.take(2)],
                    onTap: () => _push(context, const CultureSocialSection()),
                  ),
                  ProfileSectionCard(
                    icon: Icons.coffee_outlined,
                    title: 'Daily Rhythm',
                    subtitle: _sub(d.lifestyleCount, 5, 'How you move through life'),
                    progress: d.sectionProgress(d.lifestyleCount, 5),
                    isEmpty: d.lifestyleCount == 0,
                    previewChips: _chips(d.lifestylePreview()),
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
                    previewChips: d.visitedCountries.take(4).toList(),
                    onTap: () => _push(context, const TravelSection()),
                  ),
                  ProfileSectionCard(
                    icon: Icons.rocket_launch_outlined,
                    title: 'What You\'re Building',
                    subtitle: _sub(d.careerCount(), 4, 'Your work and ambitions'),
                    progress: d.sectionProgress(d.careerCount(), 4),
                    isEmpty: d.careerCount() == 0,
                    previewChips: _chips(d.careerPreview()),
                    onTap: () => _push(context, const CareerSection()),
                  ),
                  ProfileSectionCard(
                    icon: Icons.smart_toy_outlined,
                    title: 'Digital World',
                    subtitle: d.aiTools.isEmpty ? 'Your tech and digital life' : '${d.aiTools.length} tools',
                    progress: d.aiTools.isEmpty ? 0 : 0.5,
                    isEmpty: d.aiTools.isEmpty,
                    previewChips: d.aiTools.take(4).toList(),
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
                    previewChips: d.promptsPreview() != null ? [d.promptsPreview()!] : [],
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

  String _sub(int filled, int total, String emptyMsg) {
    if (filled == 0) return emptyMsg;
    if (filled >= total) return 'All set';
    return '$filled of $total';
  }

  List<String> _chips(String? preview) {
    if (preview == null || preview.isEmpty) return [];
    return preview.split(' · ');
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Photo Hero — animated, tappable, alive
// ═══════════════════════════════════════════════════════════════════════════════

class _PhotoHero extends StatefulWidget {
  final List<String> photoUrls;
  final VoidCallback onEdit;

  const _PhotoHero({required this.photoUrls, required this.onEdit});

  @override
  State<_PhotoHero> createState() => _PhotoHeroState();
}

class _PhotoHeroState extends State<_PhotoHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathe;
  late Animation<double> _breatheScale;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _breatheScale = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _breathe, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhotos = widget.photoUrls.isNotEmpty;
    final mainUrl = hasPhotos ? widget.photoUrls.first : null;
    final extras = hasPhotos ? widget.photoUrls.skip(1).take(3).toList() : <String>[];

    return Column(
      children: [
        // Main photo — hero with breathing animation
        GestureDetector(
          onTap: mainUrl != null
              ? () => _showFullScreen(context, mainUrl)
              : widget.onEdit,
          child: Container(
            width: double.infinity,
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: context.surfaceColor,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: mainUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        // Photo with subtle breathing scale
                        AnimatedBuilder(
                          animation: _breatheScale,
                          builder: (_, child) => Transform.scale(
                            scale: _breatheScale.value,
                            child: child,
                          ),
                          child: Image.network(mainUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _emptyHero(context)),
                        ),
                        // Cinematic gradient
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.4, 0.85, 1.0],
                                colors: [
                                  Colors.black.withValues(alpha: 0.1),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.25),
                                  Colors.black.withValues(alpha: 0.55),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Edit badge
                        Positioned(
                          bottom: 14, right: 14,
                          child: GestureDetector(
                            onTap: widget.onEdit,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.gold.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 14),
                                const SizedBox(width: 5),
                                Text('${widget.photoUrls.length}/6',
                                  style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          ),
                        ),
                        // Tap to view hint
                        Positioned(
                          bottom: 16, left: 16,
                          child: Row(children: [
                            Icon(Icons.zoom_out_map_rounded, color: Colors.white.withValues(alpha: 0.6), size: 14),
                            const SizedBox(width: 4),
                            Text('Tap to view', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
                          ]),
                        ),
                      ],
                    )
                  : _emptyHero(context),
            ),
          ),
        ),
        // Extra photo row
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: Row(
            children: [
              for (int i = 0; i < 3; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 3,
                      right: i == 2 ? 0 : 3,
                    ),
                    child: GestureDetector(
                      onTap: i < extras.length
                          ? () => _showFullScreen(context, extras[i])
                          : widget.onEdit,
                      child: i < extras.length
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(extras[i], fit: BoxFit.cover, height: 72,
                                errorBuilder: (_, __, ___) => _emptySlot(context)),
                            )
                          : _emptySlot(context),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyHero(BuildContext context) {
    return GestureDetector(
      onTap: widget.onEdit,
      child: Container(
        color: context.surfaceColor,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.gold.withValues(alpha: 0.15),
                    AppColors.gold.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Icon(Icons.camera_alt_outlined, color: AppColors.gold.withValues(alpha: 0.6), size: 30),
            ),
            const SizedBox(height: 14),
            const Text('Add your first photo',
              style: TextStyle(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Profiles with photos get 10x more attention',
              style: TextStyle(color: context.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _emptySlot(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Icon(Icons.add_rounded, color: AppColors.gold.withValues(alpha: 0.35), size: 22),
      ),
    );
  }

  void _showFullScreen(BuildContext context, String url) {
    Navigator.push(context, PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => _FullScreenPhoto(url: url),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    ));
  }
}

class _FullScreenPhoto extends StatelessWidget {
  final String url;
  const _FullScreenPhoto({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Hero(
            tag: url,
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Hook Banner — motivational, warm
// ═══════════════════════════════════════════════════════════════════════════════

class _HookBanner extends StatelessWidget {
  final int score;
  const _HookBanner({required this.score});

  @override
  Widget build(BuildContext context) {
    final pointsLeft = 80 - score;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gold.withValues(alpha: 0.10),
            AppColors.gold.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.gold.withValues(alpha: 0.7), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '+$pointsLeft points ',
                  style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                TextSpan(
                  text: 'to make your profile stand out',
                  style: TextStyle(color: context.textMuted, fontSize: 13),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Completion Strip
// ═══════════════════════════════════════════════════════════════════════════════

class _CompletionStrip extends StatelessWidget {
  final int score;
  const _CompletionStrip({required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 3,
                backgroundColor: context.borderColor.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
              ),
              Text('$score', style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                score >= 80 ? 'You stand out'
                : score >= 50 ? 'Almost there — make it shine'
                : 'Let\'s make your profile irresistible',
                style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 1),
              Text(
                score >= 80 ? 'People notice profiles like yours.'
                : score >= 50 ? 'A few more details and you\'ll shine.'
                : 'The best connections start with a great profile.',
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
