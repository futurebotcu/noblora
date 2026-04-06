import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  /// Get current GPS position (requests permission if needed)
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

  /// Convert coordinates to city/country
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

  /// Get city automatically from GPS
  static Future<Map<String, dynamic>> getLocationFromGPS() async {
    final position = await getCurrentPosition();
    if (position == null) return {};
    final info = await getCityFromCoordinates(position.latitude, position.longitude);
    return {
      ...info,
      'lat': double.parse(position.latitude.toStringAsFixed(2)),
      'lng': double.parse(position.longitude.toStringAsFixed(2)),
    };
  }
}
