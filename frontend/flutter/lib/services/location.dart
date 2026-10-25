import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Returns the current position, or null when location is disabled or the
  /// rider declines permission. Never throws.
  static Future<Position?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Great-circle distance in kilometres.
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const earth = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double degrees) => degrees * math.pi / 180.0;
