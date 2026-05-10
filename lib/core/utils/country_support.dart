/// R13 — Country gate utility for the geo-awareness layer.
///
/// V1 Noblara only matches users whose **home country** is one of the
/// supported regions (TH/VN/PH) **or** who have **Travel Mode active** with
/// a `travelCountry` in those regions. This is the single source of truth
/// for that decision; both the Discover swipe gate (`feed_screen.dart`)
/// and the swipe repository wrapper (`swipe_repository.dart`) call into
/// this utility so the UI banner and the backend RPC stay in lock-step.
///
/// Pure-parametric on purpose: takes primitives (not `Profile`) so it
/// can be unit-tested without pulling the Profile model into the test
/// graph, and so the gate logic is reusable from any caller (settings
/// dialog, banner, RPC error handler, future analytics) without an
/// import diamond.
class CountrySupport {
  /// Set of supported ISO 2-letter country codes for V1 launch.
  /// Keep in sync with `create_swipe_with_gate` SQL function in migration
  /// `20260510000004_geo_awareness_locked_swipe.sql`.
  static const Set<String> supportedCountries = {'TH', 'VN', 'PH'};

  /// True when [country] is one of the supported V1 regions. `null` returns
  /// false (unknown is not supported — the user must pick a city or activate
  /// Travel Mode before they can match).
  static bool isSupported(String? country) =>
      country != null && supportedCountries.contains(country);

  /// Mirrors the country-gate logic in
  /// `public.create_swipe_with_gate(...)`. The user can interact when
  /// either:
  ///   • their home `country` is in TH/VN/PH, OR
  ///   • they have `travelMode == true` AND their `travelCountry` is in
  ///     TH/VN/PH.
  ///
  /// Anything else — null country, travel mode off, travel country outside
  /// the region — returns false. Callers should surface the locked-swipe
  /// banner / Travel-Mode prompt rather than silently dropping the gesture.
  static bool isUserActiveInRegion({
    required String? country,
    required bool travelMode,
    required String? travelCountry,
  }) {
    if (isSupported(country)) return true;
    if (travelMode && isSupported(travelCountry)) return true;
    return false;
  }
}
