import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Outcome of a GPS location attempt — surfaces the specific failure
/// mode so the UI can offer the right next action (request again, send
/// the user to Settings, ask them to turn on services, or fall back to
/// the manual city picker). The previous implementation collapsed all
/// failures to `null` and the UI could only say "Could not detect
/// location" — the user reported (R15 smoke) that no permission popup
/// ever appeared, with no clue why.
enum LocationStatus {
  /// GPS coordinates resolved successfully.
  success,

  /// Permission was just denied during the runtime prompt — the user
  /// can retry the GPS button to see the prompt again.
  denied,

  /// Permission is denied "Don't ask again" — the OS will not show the
  /// runtime prompt anymore. Direct the user to App Settings.
  deniedForever,

  /// The device's location services (GPS/Wi-Fi positioning) are off at
  /// the OS level. Direct the user to OS Location Settings.
  serviceDisabled,

  /// Permission was granted but the position read or geocoding lookup
  /// failed (timeout, no fix, network for reverse geocode, etc.).
  positionUnavailable,
}

class LocationResult {
  final LocationStatus status;
  final String? city;
  final String? country;
  final String? countryCode;
  final double? lat;
  final double? lng;

  const LocationResult({
    required this.status,
    this.city,
    this.country,
    this.countryCode,
    this.lat,
    this.lng,
  });

  bool get isSuccess => status == LocationStatus.success;
}

class LocationService {
  /// Get current GPS position (requests runtime permission if needed).
  /// Returns the raw [Position] on success, null on any failure — use
  /// [getLocationFromGPS] for the structured-status flow.
  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    );
  }

  /// Convert coordinates to city/country via reverse geocoding.
  static Future<Map<String, String?>> getCityFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        double.parse(lat.toStringAsFixed(2)),
        double.parse(lng.toStringAsFixed(2)),
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return {
          'city': place.locality ?? place.administrativeArea,
          'country': place.country,
          'countryCode': place.isoCountryCode,
        };
      }
    } catch (e) { debugPrint('[location] Geocoding failed: $e'); }
    return {'city': null, 'country': null, 'countryCode': null};
  }

  /// Get city automatically from GPS, with explicit failure-mode reporting.
  /// Walks the same permission ladder as [getCurrentPosition] but tells the
  /// caller which step failed so the UI can offer the appropriate recovery
  /// (retry, Open Settings, turn on location services, manual fallback).
  static Future<LocationResult> getLocationFromGPS() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult(status: LocationStatus.serviceDisabled);
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // First-time prompt OR previous "Deny" (not "Don't ask again").
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return const LocationResult(status: LocationStatus.denied);
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult(status: LocationStatus.deniedForever);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 12));
      final info = await getCityFromCoordinates(position.latitude, position.longitude);
      return LocationResult(
        status: LocationStatus.success,
        city: info['city'],
        country: info['country'],
        countryCode: info['countryCode'],
        lat: double.parse(position.latitude.toStringAsFixed(2)),
        lng: double.parse(position.longitude.toStringAsFixed(2)),
      );
    } catch (e) {
      debugPrint('[location] Position read failed: $e');
      return const LocationResult(status: LocationStatus.positionUnavailable);
    }
  }

  /// Open the OS App Settings page so the user can grant permission that
  /// was previously denied with "Don't ask again".
  static Future<bool> openAppSettingsPage() => Geolocator.openAppSettings();

  /// Open the OS Location Services settings (master toggle).
  static Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
