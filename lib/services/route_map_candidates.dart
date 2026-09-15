import '../models/photo_spot.dart';

/// Bounds limit only rendered cards. The full city list remains selectable.
List<PhotoSpot> routeMapCandidates(
  List<PhotoSpot> places, {
  required double latitude,
  required double longitude,
  double? south,
  double? north,
  double? west,
  double? east,
  int limit = 80,
}) {
  final visible = places
      .where(
        (p) =>
            (south == null || p.latitude >= south) &&
            (north == null || p.latitude <= north) &&
            (west == null || p.longitude >= west) &&
            (east == null || p.longitude <= east),
      )
      .toList();
  double distance(PhotoSpot p) =>
      (p.latitude - latitude) * (p.latitude - latitude) +
      (p.longitude - longitude) * (p.longitude - longitude);
  visible.sort((a, b) {
    final order = distance(a).compareTo(distance(b));
    return order == 0 ? a.id.compareTo(b.id) : order;
  });
  return visible.take(limit).toList();
}
