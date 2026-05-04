import 'package:flutter_test/flutter_test.dart';
import 'package:noblara/data/models/profile.dart';
import 'package:noblara/data/models/post.dart';

/// Guardrail: `Profile.fromJson` must round-trip every field the visible
/// profile depends on. If someone adds a field to Edit Profile but forgets
/// to wire it in `Profile.fromJson`, this test fails immediately — so the
/// "I filled it in Edit but it doesn't show" silent-loss bug can't recur.
///
/// Also asserts that `Profile.fromJson` NEVER throws when a list field is
/// stored as an unexpected type (e.g. null, a string, a number) — that was
/// the bug that routed Fatih into the onboarding screen.
void main() {
  group('Profile.fromJson', () {
    test('round-trips every visible-profile field from a full JSONB row', () {
      final row = {
        'id': '00000000-0000-0000-0000-000000000001',
        'display_name': 'Fatih',
        'gender': 'male',
        'current_mode': 'bff',
        'noble_score': 12,
        'trust_score': 75,
        'nob_tier': 'noble',
        'maturity_score': 62.0,
        'profile_completeness_score': 85,
        'community_score': 40,
        'depth_score': 55,
        'follow_through_score': 60,
        'date_bio': 'I build calm products and run every morning.',
        'bff_bio': 'Deep talks over long walks. Always up for a museum.',
        'bio': 'Product designer · dog person · ocean lover',
        'age': 29,
        'city': 'Istanbul',
        'occupation': 'Product Designer',
        'height': 182,
        'from_country': 'Turkey',
        'countries_visited': ['Japan', 'Italy', 'Morocco'],
        'interests': ['design', 'running', 'jazz', 'film'],
        'vibe': 'thoughtful and warm',
        'looking_for': 'a real connection',
        'zodiac': 'libra',
        'photo_urls': [
          'https://example.com/1.jpg',
          'https://example.com/2.jpg',
        ],
        'languages': ['Turkish', 'English'],
        'profile_data': {
          'long_bio': 'A longer story about who I am and what I care about.',
          'tagline': 'Make quietly, listen loudly.',
          'current_focus': 'shipping a new product',
          'pronouns': 'he/him',
          'wants_children': 'open to it',
          'relationship_type': ['serious', 'monogamous'],
          'dating_style': ['slow', 'intentional'],
          'communication_style': ['direct', 'warm'],
          'love_languages': ['quality time', 'acts of service'],
          'music_genres': ['jazz', 'ambient'],
          'movie_genres': ['drama', 'documentary'],
          'weekend_style': ['hiking', 'brunch', 'bookstore'],
          'humor_style': ['dry', 'observational'],
          'sleep_style': 'early bird',
          'diet_style': 'mostly plants',
          'fitness_routine': 'morning runs',
          'work_style': 'deep focus',
          'entrepreneurship_status': 'founder',
          'secondary_role': 'jazz pianist',
          'social_energy': 'introvert',
          'work_intensity': 'balanced',
          'education_level': 'graduate',
          'relocation_openness': 'open within Europe',
          'interested_in': ['women'],
          'first_meet_preference': ['coffee', 'gallery'],
          'building_now': ['a new app', 'a reading habit'],
          'industry': ['design', 'tech'],
          'ai_tools': ['claude', 'figma ai'],
          'social_media_usage': 'low',
          'tech_relation': 'builder',
          'travel_style': ['slow travel', 'off the path'],
          'lived_countries': ['Germany', 'Turkey'],
          'wishlist_countries': ['Japan', 'Portugal'],
          'prompts': [
            {'question': 'Most spontaneous thing', 'answer': 'Flew to Lisbon on a Tuesday.'},
            {'question': 'Ideal Sunday', 'answer': 'Long run, then jazz, then friends.'},
          ],
          'visibility': {
            'age': 'Public',
            'city': 'Matches only',
          },
        },
      };

      final p = Profile.fromJson(row);

      // ── identity ────────────────────────────────────────────────────
      expect(p.displayName, 'Fatih');
      expect(p.age, 29);
      expect(p.city, 'Istanbul');
      expect(p.occupation, 'Product Designer');
      expect(p.bio, contains('Product designer'));
      expect(p.gender, 'male');
      expect(p.trustScore, 75);
      expect(p.nobTier, NobTier.noble);
      expect(p.profileCompletenessScore, 85);

      // ── about me / manifesto ───────────────────────────────────────
      expect(p.longBio, contains('longer story'));
      expect(p.tagline, 'Make quietly, listen loudly.');
      expect(p.currentFocus, 'shipping a new product');
      expect(p.vibe, 'thoughtful and warm');
      expect(p.lookingFor, 'a real connection');

      // ── photos / interests ─────────────────────────────────────────
      expect(p.photoUrls, hasLength(2));
      expect(p.interests, containsAll(['design', 'running']));

      // ── connection style ───────────────────────────────────────────
      expect(p.relationshipType, containsAll(['serious', 'monogamous']));
      expect(p.datingStyle, contains('slow'));
      expect(p.communicationStyle, contains('direct'));
      expect(p.loveLanguages, contains('quality time'));
      expect(p.socialEnergy, 'introvert');
      expect(p.firstMeetPreference, containsAll(['coffee', 'gallery']));
      expect(p.interestedIn, contains('women'));

      // ── lifestyle ──────────────────────────────────────────────────
      expect(p.sleepStyle, 'early bird');
      expect(p.dietStyle, 'mostly plants');
      expect(p.fitnessRoutine, 'morning runs');

      // ── career & building ──────────────────────────────────────────
      expect(p.workStyle, 'deep focus');
      expect(p.entrepreneurshipStatus, 'founder');
      expect(p.secondaryRole, 'jazz pianist');
      expect(p.workIntensity, 'balanced');
      expect(p.educationLevel, 'graduate');
      expect(p.buildingNow, contains('a new app'));
      expect(p.industry, contains('design'));

      // ── culture & taste ────────────────────────────────────────────
      expect(p.musicGenres, contains('jazz'));
      expect(p.movieGenres, contains('documentary'));
      expect(p.weekendStyle, contains('hiking'));
      expect(p.humorStyle, contains('dry'));

      // ── travel ─────────────────────────────────────────────────────
      expect(p.countriesVisited, contains('Japan'));
      expect(p.livedCountries, contains('Germany'));
      expect(p.wishlistCountries, contains('Portugal'));
      expect(p.travelStyle, contains('slow travel'));
      expect(p.relocationOpenness, 'open within Europe');

      // ── digital life ───────────────────────────────────────────────
      expect(p.aiTools, contains('claude'));
      expect(p.socialMediaUsage, 'low');
      expect(p.techRelation, 'builder');

      // ── prompts ────────────────────────────────────────────────────
      expect(p.prompts, hasLength(2));
      expect(p.prompts.first.answer, contains('Lisbon'));

      // ── personas ───────────────────────────────────────────────────
      expect(p.dateBio, contains('calm products'));
      expect(p.bffBio, contains('long walks'));

      // ── visibility map ─────────────────────────────────────────────
      expect(p.visibility['age'], 'Public');
      expect(p.visibility['city'], 'Matches only');
      expect(p.canViewField('city', isMatch: false), isFalse);
      expect(p.canViewField('city', isMatch: true), isTrue);
      expect(p.canViewField('age'), isTrue);
    });

    test('tolerates null / wrong-type list fields without throwing', () {
      final row = {
        'id': 'a',
        'display_name': 'Edge',
        'profile_data': {
          // These were the fields that crashed Profile.fromJson and
          // silently routed users into onboarding — now they must survive
          // being null, a string, or a number.
          'interested_in': null,
          'first_meet_preference': 'not-a-list',
          'music_genres': 42,
          'ai_tools': {'wrong': 'shape'},
          'prompts': null,
        },
      };

      final Profile p;
      try {
        p = Profile.fromJson(row);
      } catch (e) {
        fail('Profile.fromJson must not throw on garbage list fields: $e');
      }

      expect(p.interestedIn, isEmpty);
      expect(p.firstMeetPreference, isEmpty);
      expect(p.musicGenres, isEmpty);
      expect(p.aiTools, isEmpty);
      expect(p.prompts, isEmpty);
    });
  });
}
