import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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
        appBar: AppBar(backgroundColor: context.bgColor, surfaceTintColor: Colors.transparent,
          title: Text('Edit Profile', style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w600))),
        body: const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

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
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.xxxxl),
        children: [
          // Completion header
          _CompletionHeader(score: d.completionScore),
          const SizedBox(height: AppSpacing.xxl),

          // Section cards
          ProfileSectionCard(
            icon: Icons.photo_camera_outlined,
            title: 'Photos & Media',
            subtitle: d.photosStatus(),
            progress: d.photoUrls.length / 6,
            onTap: () => _push(context, const PhotosMediaSection()),
          ),
          ProfileSectionCard(
            icon: Icons.person_outline_rounded,
            title: 'Basic Info',
            subtitle: d.basicInfoStatus(),
            progress: d.sectionProgress(d.basicInfoCount(), 9),
            onTap: () => _push(context, const BasicInfoSection()),
          ),
          ProfileSectionCard(
            icon: Icons.edit_note_rounded,
            title: 'About Me',
            subtitle: d.aboutStatus(),
            progress: d.sectionProgress(d.aboutCount(), 4),
            onTap: () => _push(context, const AboutMeSection()),
          ),
          ProfileSectionCard(
            icon: Icons.fingerprint_rounded,
            title: 'Identity & Life',
            subtitle: d.identityStatus(),
            progress: d.sectionProgress(d.identityCount(), 8),
            onTap: () => _push(context, const IdentityLifeSection()),
          ),
          ProfileSectionCard(
            icon: Icons.favorite_outline_rounded,
            title: 'Relationship & Intent',
            subtitle: d.relationshipStatus(),
            progress: d.sectionProgress(d.relationshipCount(), 6),
            onTap: () => _push(context, const RelationshipSection()),
          ),
          ProfileSectionCard(
            icon: Icons.interests_outlined,
            title: 'Interests',
            subtitle: d.interestsStatus(),
            progress: d.interests.isEmpty ? 0 : (d.interests.length / 20).clamp(0.0, 1.0),
            onTap: () => _push(context, const InterestsSection()),
          ),
          ProfileSectionCard(
            icon: Icons.music_note_outlined,
            title: 'Culture & Social',
            subtitle: d.cultureStatus(),
            progress: (d.musicGenres.length + d.movieGenres.length) == 0 ? 0 : 0.5,
            onTap: () => _push(context, const CultureSocialSection()),
          ),
          ProfileSectionCard(
            icon: Icons.flight_outlined,
            title: 'Travel & World',
            subtitle: d.travelStatus(),
            progress: d.visitedCountries.isEmpty ? 0 : 0.5,
            onTap: () => _push(context, const TravelSection()),
          ),
          ProfileSectionCard(
            icon: Icons.work_outline_rounded,
            title: 'Career & Building',
            subtitle: d.careerStatus(),
            progress: d.sectionProgress(d.careerCount(), 4),
            onTap: () => _push(context, const CareerSection()),
          ),
          ProfileSectionCard(
            icon: Icons.smart_toy_outlined,
            title: 'Digital Life',
            subtitle: d.digitalStatus(),
            progress: d.aiTools.isEmpty ? 0 : 0.5,
            onTap: () => _push(context, const DigitalLifeSection()),
          ),
          ProfileSectionCard(
            icon: Icons.self_improvement_outlined,
            title: 'Lifestyle',
            subtitle: d.lifestyleStatus(),
            progress: d.sectionProgress(d.lifestyleCount, 5),
            onTap: () => _push(context, const LifestyleSection()),
          ),
          ProfileSectionCard(
            icon: Icons.format_quote_outlined,
            title: 'Prompts & Highlights',
            subtitle: d.promptsStatus(),
            progress: d.prompts.where((p) => p.answer.isNotEmpty).length / 3,
            onTap: () => _push(context, const PromptsSection()),
          ),
          ProfileSectionCard(
            icon: Icons.visibility_outlined,
            title: 'Privacy & Visibility',
            subtitle: '${d.visibility.length} custom',
            progress: d.visibility.isEmpty ? 0 : 0.5,
            onTap: () => _push(context, const VisibilitySection()),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _CompletionHeader extends StatelessWidget {
  final int score;
  const _CompletionHeader({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 4,
                  backgroundColor: context.borderColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
                Text('$score', style: const TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile Strength', style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  score >= 80 ? 'Your profile is looking great!'
                  : score >= 50 ? 'Add more details to stand out.'
                  : 'Complete your profile to get more matches.',
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
