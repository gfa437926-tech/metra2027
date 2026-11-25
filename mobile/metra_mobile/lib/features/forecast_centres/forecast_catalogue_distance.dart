import 'dart:math' as math;

/// Great-circle distance in kilometres between two catalogue coordinates.
/// Returns null when either point is missing or outside WGS84 bounds.
/// This is geographic metadata only; it is not a weather observation.
double? forecastCatalogueDistanceKm({
  required double? latitudeA,
  required double? longitudeA,
  required double? latitudeB,
  required double? longitudeB,
}) {
  if (!_valid(latitudeA, longitudeA) || !_valid(latitudeB, longitudeB)) {
    return null;
  }
  const earthRadiusKm = 6371.0088;
  final lat1 = _radians(latitudeA!);
  final lat2 = _radians(latitudeB!);
  final deltaLat = _radians(latitudeB - latitudeA);
  final deltaLon = _radians(longitudeB! - longitudeA!);
  final haversine = math.pow(math.sin(deltaLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(deltaLon / 2), 2);
  final bounded = haversine.clamp(0.0, 1.0);
  return 2 * earthRadiusKm * math.asin(math.sqrt(bounded.toDouble()));
}

bool _valid(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180;

double _radians(double degrees) => degrees * math.pi / 180;
