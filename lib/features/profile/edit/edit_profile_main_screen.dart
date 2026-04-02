import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class EditProfileMainScreen extends ConsumerStatefulWidget {
  const EditProfileMainScreen({super.key});

  @override
  ConsumerState<EditProfileMainScreen> createState() => _EditProfileMainScreenState();
}

class _EditProfileMainScreenState extends ConsumerState<EditProfileMainScreen> {
  int? _prevScore;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editProfileProvider);
    final d = state.draft;

    if (state.isLoading) {
      return Scaffold(
        backgroundColor: context.bgColor,
        body: const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    // Dopamine: detect score increase
    final score = d.completionScore;
    if (_prevScore != null && score > _prevScore!) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        _showScorePop(context, score - _prevScore!);
      });
    }
    _prevScore = score;

    int idx = 0;

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

                  const SizedBox(height: 16),

                  // ═══ IDENTITY MIRROR ═══
                  _IdentityMirror(
                    photoUrl: d.photoUrls.isNotEmpty ? d.photoUrls.first : null,
                    name: d.displayName,
                    interests: d.interests.take(2).toList(),
                    prompt: d.prompts.where((p) => p.answer.isNotEmpty).firstOrNull?.answer,
                  ),

                  const SizedBox(height: 16),

                  // ═══ HOOK BANNER ═══
                  if (score < 80) ...[
                    _HookBanner(score: score),
                    const SizedBox(height: 16),
                  ],

                  // ═══ COMPLETION ═══
                  _CompletionStrip(score: score),

                  const SizedBox(height: 20),

                  // ═══ SECTION CARDS ═══
                  ProfileSectionCard(
                    staggerIndex: idx++,
                    icon: Icons.person_outline_rounded,
                    title: 'The Basics',
                    subtitle: _sub(d.basicInfoCount(), 9, 'People want to know the real you'),
                    progress: d.sectionProgress(d.basicInfoCount(), 9),
                    isEmpty: d.basicInfoCount() == 0,
                    previewChips: _chips(d.basicInfoPreview()),
                    boostHint: '+8 → appear in more searches',
                    onTap: () => _push(context, const BasicInfoSection()),
                  ),
                  ProfileSectionCard(
                    staggerIndex: idx++,
                    icon: Icons.auto_awesome_outlined,
                    title: 'In Your Own Words',
                    subtitle: _sub(d.aboutCount(), 4, 'This is where connections begin'),
                    progress: d.sectionProgress(d.aboutCount(), 4),
                    isEmpty: d.aboutCount() == 0,
                    previewChips: d.aboutPreview() != null ? [d.aboutPreview()!] : [],
                    boostHint: '+10 → first thing people read',
                    onTap: () => _push(context, const AboutMeSection()),
                  ),
                  ProfileSectionCard(
                    staggerIndex: idx++,
                    icon: Icons.favorite_outline_rounded,
                    title: 'What You\'re Looking For',
                    subtitle: _sub(d.relationshipCount(), 6, 'Honesty attracts the right people'),
                    progress: d.sectionProgress(d.relationshipCount(), 6),
                    isEmpty: d.relationshipCount() == 0,
                    previewChips: _chips(d.relationshipPreview()),
                    boostHint: '+12 → better matches',
                    onTap: () => _push(context, const RelationshipSection()),
                  ),
                  ProfileSectionCard(
                    staggerIndex: idx++,
                    icon: Icons.local_fire_department_outlined,
                    title: 'Things You Love',
                    subtitle: d.interests.isEmpty ? 'The spark that makes you interesting' : '${d.interests.length} interests',
                    progress: d.interests.isEmpty ? 0 : (d.interests.length / 20).clamp(0.0, 1.0),
                    isEmpty: d.interests.isEmpty,
                    previewChips: d.interests.take(5).toList(),
                    boostHint: '+12 → shared interests drive matches',
                    onTap: () => _push(context, const InterestsSection()),
                  ),
                  ProfileSectionCard(
                    staggerIndex: idx++,
                    icon: Icons.fingerprint_rounded,
                    title: 'Who You Are',
                    subtitle: _sub(d.identityCount(), 8, 'Your values shape your connections'),
                    progress: d.sectionProgress(d.identityCount(), 8),
                    isEmpty: d.identityCount() == 0,
                    previewChips: _chips(d.identityPreview()),
                    boostHint: '+8 → compatibility boost',
                    onTap: () => _push(context, const IdentityLifeSection()),
                  ),
                  ProfileSectionCard(
                    staggerIndex: idx++,
                    icon: Icons.music_note_outlined,
                    title: 'Culture & Taste',
                    subtitle: (d.musicGenres.length + d.movieGenres.length) == 0
                        ? 'Shared taste creates instant chemistry'
                        : '${d.musicGenres.length + d.movieGenres.length} tastes',
                    progress: (d.musicGenres.length + d.movieGenres.length) == 0 ? 0 : 0.5,
                    isEmpty: d.musicGenres.isEmpty && d.movieGenres.isEmpty,
                    previewChips: [...d.musicGenres.take(3), ...d.movieGenres.take(2)],
                    boostHint: '+6 → vibe matching',
                    onTap: () => _push(context, const CultureSocialSection()),
                  ),
                  ProfileSectionCard(
                    staggerIndex: idx++,
                    icon: Icons.coffee_outlined,
                    title: 'Daily Rhythm',
                    subtitle: _sub(d.lifestyleCount, 5, 'Are you a sunrise or midnight soul?'),
                    progress: d.sectionProgress(d.lifestyleCount, 5),
                    isEmpty: d.lifestyleCount == 0,
                    previewChips: _chips(d.lifestylePreview()),
                    boostHint: '+6 → lifestyle compatibility',
                    onTap: () => _push(context, const LifestyleSection()),
                  ),
                  ProfileSectionCard(
                    staggerIndex: idx++,
                    icon: Icons.flight_outlined,
                    title: 'Your World',
                    subtitle: d.visitedCountries.isEmpty
                        ? 'Every place you\'ve been tells a story'
                        : '${d.visitedCountries.length} countries explored',
                    progress: d.visitedCountries.isEmpty ? 0 : 0.5,
                    isEmpty: d.visitedCountries.isEmpty,
                    previewChips: d.visitedCountries.take(4).toList(),
                    boostHint: '+6 → travel compatibility',
                    onTap: () => _push(context, const TravelSection()),
                  ),
                  ProfileSectionCard(
                    staggerIndex: idx++,
                    icon: Icons.rocket_launch_outlined,
                    title: 'What You\'re Building',
                    subtitle: _sub(d.careerCount(), 4, 'Ambition is attractive'),
                    progress: d.sectionProgress(d.careerCount(), 4),
                    isEmpty: d.careerCount() == 0,
                    previewChips: _chips(d.careerPreview()),
                    boostHint: '+8 → stand out from the crowd',
                    onTap: () => _push(context, const CareerSection()),
                  ),
                  ProfileSectionCard(
                    staggerIndex: idx++,
                    icon: Icons.smart_toy_outlined,
                    title: 'Digital World',
                    subtitle: d.aiTools.isEmpty ? 'Show your modern side' : '${d.aiTools.length} tools',
                    progress: d.aiTools.isEmpty ? 0 : 0.5,
                    isEmpty: d.aiTools.isEmpty,
                    previewChips: d.aiTools.take(4).toList(),
                    boostHint: '+6 → attract tech-savvy people',
                    onTap: () => _push(context, const DigitalLifeSection()),
                  ),
                  ProfileSectionCard(
                    staggerIndex: idx++,
                    icon: Icons.format_quote_rounded,
                    title: 'Conversation Starters',
                    subtitle: d.prompts.where((p) => p.answer.isNotEmpty).isEmpty
                        ? 'The best icebreaker is your story'
                        : '${d.prompts.where((p) => p.answer.isNotEmpty).length}/3 answered',
                    progress: d.prompts.where((p) => p.answer.isNotEmpty).length / 3,
                    isEmpty: d.prompts.where((p) => p.answer.isNotEmpty).isEmpty,
                    previewChips: d.promptsPreview() != null ? [d.promptsPreview()!] : [],
                    boostHint: '+10 → spark real conversations',
                    onTap: () => _push(context, const PromptsSection()),
                  ),
                  ProfileSectionCard(
                    staggerIndex: idx++,
                    icon: Icons.shield_outlined,
                    title: 'Privacy',
                    subtitle: 'You decide who sees what',
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

  void _showScorePop(BuildContext context, int gained) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (ctx) => _ScorePopOverlay(
      points: gained,
      onDone: () => entry.remove(),
    ));
    overlay.insert(entry);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Score Pop — dopamine feedback overlay
// ═══════════════════════════════════════════════════════════════════════════════

class _ScorePopOverlay extends StatefulWidget {
  final int points;
  final VoidCallback onDone;
  const _ScorePopOverlay({required this.points, required this.onDone});

  @override
  State<_ScorePopOverlay> createState() => _ScorePopOverlayState();
}

class _ScorePopOverlayState extends State<_ScorePopOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.2), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_ctrl);
    _slide = Tween(begin: const Offset(0, 0), end: const Offset(0, -0.3))
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.35,
      left: 0, right: 0,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_upward_rounded, color: Colors.black, size: 18),
                    const SizedBox(width: 6),
                    Text('+${widget.points}', style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Identity Mirror — "This is how others see you"
// ═══════════════════════════════════════════════════════════════════════════════

class _IdentityMirror extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final List<String> interests;
  final String? prompt;

  const _IdentityMirror({this.photoUrl, required this.name, this.interests = const [], this.prompt});

  @override
  Widget build(BuildContext context) {
    final hasContent = name.isNotEmpty || interests.isNotEmpty || prompt != null;
    if (!hasContent && photoUrl == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, size: 13, color: context.textDisabled),
              const SizedBox(width: 6),
              Text('How others see you', style: TextStyle(color: context.textDisabled, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Mini avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.3), width: 1.5),
                ),
                child: ClipOval(
                  child: photoUrl != null
                      ? Image.network(photoUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(context))
                      : _placeholder(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Your name' : name,
                      style: TextStyle(
                        color: name.isEmpty ? context.textDisabled : context.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (interests.isNotEmpty)
                      Text(
                        interests.join(' · '),
                        style: TextStyle(color: AppColors.gold.withValues(alpha: 0.7), fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (prompt != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border(left: BorderSide(color: AppColors.gold.withValues(alpha: 0.4), width: 2)),
              ),
              child: Text(
                '"${prompt!.length > 70 ? '${prompt!.substring(0, 70)}...' : prompt!}"',
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: AppColors.gold.withValues(alpha: 0.08),
      child: Icon(Icons.person_rounded, color: AppColors.gold.withValues(alpha: 0.3), size: 24),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Photo Hero
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
    _breathe = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);
    _breatheScale = Tween<double>(begin: 1.0, end: 1.015).animate(
      CurvedAnimation(parent: _breathe, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _breathe.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final hasPhotos = widget.photoUrls.isNotEmpty;
    final mainUrl = hasPhotos ? widget.photoUrls.first : null;
    final extras = hasPhotos ? widget.photoUrls.skip(1).take(3).toList() : <String>[];

    return Column(
      children: [
        GestureDetector(
          onTap: mainUrl != null ? () => _showFull(context, mainUrl) : widget.onEdit,
          child: Container(
            width: double.infinity, height: 300,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: context.surfaceColor),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: mainUrl != null
                  ? Stack(fit: StackFit.expand, children: [
                      AnimatedBuilder(
                        animation: _breatheScale,
                        builder: (_, child) => Transform.scale(scale: _breatheScale.value, child: child),
                        child: Image.network(mainUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _empty(context)),
                      ),
                      Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          stops: const [0.0, 0.4, 0.85, 1.0],
                          colors: [Colors.black.withValues(alpha: 0.08), Colors.transparent, Colors.black.withValues(alpha: 0.2), Colors.black.withValues(alpha: 0.5)],
                        ),
                      ))),
                      Positioned(bottom: 14, right: 14, child: GestureDetector(
                        onTap: widget.onEdit,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 14),
                            const SizedBox(width: 5),
                            Text('${widget.photoUrls.length}/6', style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      )),
                    ])
                  : _empty(context),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(height: 72, child: Row(children: [
          for (int i = 0; i < 3; i++)
            Expanded(child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 3, right: i == 2 ? 0 : 3),
              child: GestureDetector(
                onTap: i < extras.length ? () => _showFull(context, extras[i]) : widget.onEdit,
                child: i < extras.length
                    ? ClipRRect(borderRadius: BorderRadius.circular(12),
                        child: Image.network(extras[i], fit: BoxFit.cover, height: 72,
                          errorBuilder: (_, __, ___) => _slot(context)))
                    : _slot(context),
              ),
            )),
        ])),
      ],
    );
  }

  Widget _empty(BuildContext context) => Container(
    color: context.surfaceColor,
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 72, height: 72, decoration: BoxDecoration(shape: BoxShape.circle,
        gradient: LinearGradient(colors: [AppColors.gold.withValues(alpha: 0.15), AppColors.gold.withValues(alpha: 0.05)])),
        child: Icon(Icons.camera_alt_outlined, color: AppColors.gold.withValues(alpha: 0.6), size: 30)),
      const SizedBox(height: 14),
      const Text('Add your first photo', style: TextStyle(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('Profiles with photos get 10x more attention', style: TextStyle(color: context.textMuted, fontSize: 12)),
    ]),
  );

  Widget _slot(BuildContext context) => Container(height: 72,
    decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.borderColor.withValues(alpha: 0.3))),
    child: Center(child: Icon(Icons.add_rounded, color: AppColors.gold.withValues(alpha: 0.35), size: 22)),
  );

  void _showFull(BuildContext context, String url) {
    Navigator.push(context, PageRouteBuilder(
      opaque: false, barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Scaffold(backgroundColor: Colors.black87,
          body: Center(child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)))),
      ),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Hook Banner
// ═══════════════════════════════════════════════════════════════════════════════

class _HookBanner extends StatelessWidget {
  final int score;
  const _HookBanner({required this.score});

  @override
  Widget build(BuildContext context) {
    final left = 80 - score;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.gold.withValues(alpha: 0.10), AppColors.gold.withValues(alpha: 0.04)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Icon(Icons.auto_awesome_rounded, color: AppColors.gold.withValues(alpha: 0.7), size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text.rich(TextSpan(children: [
          TextSpan(text: '+$left points ', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13)),
          TextSpan(text: 'to unlock your full potential', style: TextStyle(color: context.textMuted, fontSize: 13)),
        ]))),
      ]),
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
    return Row(children: [
      SizedBox(width: 42, height: 42, child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(value: score / 100, strokeWidth: 3,
          backgroundColor: context.borderColor.withValues(alpha: 0.2),
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold)),
        Text('$score', style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w800)),
      ])),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          score >= 80 ? 'You stand out'
          : score >= 50 ? 'Almost there — make it shine'
          : 'Let\'s make your profile irresistible',
          style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 1),
        Text(
          score >= 80 ? 'People notice profiles like yours.'
          : score >= 50 ? 'A few more details and you\'ll glow.'
          : 'Great connections start with a great profile.',
          style: TextStyle(color: context.textMuted, fontSize: 12)),
      ])),
    ]);
  }
}
