import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';

/// RPC fan-out for the global mood-map screen: country list, country-level
/// insight aggregation, and per-country detail. Each method returns the raw
/// shape the underlying RPC produces so the screen can keep using its own
/// `fromJson` constructors (`CountryInsightData`, `CountryMood`,
/// `CountryMoodDetail`) without coupling those DTOs to the repository.
class MoodMapRepository {
  final SupabaseClient? _supabase;

  MoodMapRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Aggregated insight payload for [countryCode] — used by the country
  /// drilldown header.
  Future<Map<String, dynamic>> fetchCountryInsightData(
      String countryCode) async {
    if (isMockMode) return const {};
    final res = await _supabase!.rpc(
      'fetch_country_insight_data',
      params: {'p_country': countryCode},
    );
    return Map<String, dynamic>.from(res as Map);
  }

  /// List of countries with current mood snapshots — used by the map
  /// overview cards.
  Future<List<Map<String, dynamic>>> fetchCountryMoods() async {
    if (isMockMode) return const [];
    final res = await _supabase!.rpc('fetch_country_moods');
    if (res is! List) return const [];
    return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Detailed breakdown for [countryCode] — drilldown body (mood breakdown,
  /// top topics, sample posts).
  Future<Map<String, dynamic>> fetchCountryMoodDetail(
      String countryCode) async {
    if (isMockMode) return const {};
    final res = await _supabase!.rpc(
      'fetch_country_mood_detail',
      params: {'p_country': countryCode},
    );
    return Map<String, dynamic>.from(res as Map);
  }

  /// AI summary for the country drilldown header. Wraps the
  /// `nob-country-insight` Edge Function. Returns the raw response map
  /// (typically `{summary_title, summary_body, ...}`) or `null` if the
  /// shape is unexpected / mock mode. Caller does the `AISummary.fromJson`
  /// mapping.
  Future<Map<String, dynamic>?> fetchCountryAISummary({
    required String countryCode,
    required String countryName,
    required String timeWindow,
    required int totalPosts,
    required int uniqueAuthors,
    required double avgQuality,
    String? dominantMood,
    required List<Map<String, dynamic>> moodBreakdown,
    required List<Map<String, dynamic>> topTopics,
    required Map<String, dynamic> engagement,
    required String dataQuality,
  }) async {
    if (isMockMode) return null;
    final res = await _supabase!.functions.invoke(
      'nob-country-insight',
      body: {
        'country_code': countryCode,
        'country_name': countryName,
        'time_window': timeWindow,
        'total_posts': totalPosts,
        'unique_authors': uniqueAuthors,
        'avg_quality': avgQuality,
        'dominant_mood': dominantMood,
        'mood_breakdown': moodBreakdown,
        'top_topics': topTopics,
        'engagement': engagement,
        'data_quality': dataQuality,
      },
    );
    if (res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    return null;
  }
}
