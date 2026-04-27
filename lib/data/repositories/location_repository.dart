import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';

/// City / place search via the `places-proxy` Edge Function (Google Places
/// behind a server-side key). Two actions: `autocomplete` returns a list of
/// prediction objects; `details` returns a single result object with
/// geometry and address components. Both methods return raw shapes so the
/// caller keeps its own DTO mapping (`_PlacePrediction`, lat/lng / country
/// extraction).
class LocationRepository {
  final SupabaseClient? _supabase;

  LocationRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Autocomplete predictions for [query]. Returns the `predictions` list
  /// (each an opaque map) or empty list on mock / unexpected shape.
  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    if (isMockMode) return const [];
    final res = await _supabase!.functions.invoke(
      'places-proxy',
      body: {'action': 'autocomplete', 'query': query},
    );
    final data = res.data;
    if (data is Map && data['predictions'] is List) {
      return (data['predictions'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return const [];
  }

  /// Place details for [placeId]. Returns the `result` object (geometry,
  /// address_components, ...) or `null` on mock / unexpected shape.
  Future<Map<String, dynamic>?> fetchPlaceDetails(String placeId) async {
    if (isMockMode) return null;
    final res = await _supabase!.functions.invoke(
      'places-proxy',
      body: {'action': 'details', 'placeId': placeId},
    );
    final data = res.data;
    if (data is Map && data['result'] is Map) {
      return Map<String, dynamic>.from(data['result'] as Map);
    }
    return null;
  }
}
