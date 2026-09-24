import '../models/models.dart';

class GeofenceService {
  /// Boundary counts as inside. Local polygons must not cross the antimeridian.
  static bool contains(double lat, double lng, List<Coordinate> polygon) {
    if (polygon.length < 3) {
      return false;
    }
    var inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[j], b = polygon[i];
      final cross =
          (lng - a.lng) * (b.lat - a.lat) - (lat - a.lat) * (b.lng - a.lng);
      bool between(double n, double x, double y) =>
          n >= (x < y ? x : y) - 1e-10 && n <= (x > y ? x : y) + 1e-10;
      if (cross.abs() <= 1e-10 &&
          between(lng, a.lng, b.lng) &&
          between(lat, a.lat, b.lat)) {
        return true;
      }
      if ((a.lat > lat) != (b.lat > lat) &&
          lng < (b.lng - a.lng) * (lat - a.lat) / (b.lat - a.lat) + a.lng) {
        inside = !inside;
      }
    }
    return inside;
  }
}
