import 'dart:math' as math;

import '../models/photo_spot.dart';

/// Keep the chosen start fixed; arrange the remaining stops by proximity.
/// This is a proximity suggestion, not a claim of the fastest road route.
List<PhotoSpot> smartOrderStops(List<PhotoSpot> stops) {
  if (stops.length < 3) return List.of(stops);
  double distance(PhotoSpot a, PhotoSpot b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dlat = lat2 - lat1;
    final dlon = (b.longitude - a.longitude) * math.pi / 180;
    final h =
        math.pow(math.sin(dlat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dlon / 2), 2);
    return 2 * math.asin(math.sqrt(h.clamp(0, 1)));
  }

  double length(List<PhotoSpot> route) {
    var total = 0.0;
    for (var i = 1; i < route.length; i++) {
      total += distance(route[i - 1], route[i]);
    }
    return total;
  }

  final remaining = stops.skip(1).toList();
  var ordered = <PhotoSpot>[stops.first];
  while (remaining.isNotEmpty) {
    var nearest = 0;
    for (var i = 1; i < remaining.length; i++) {
      if (distance(ordered.last, remaining[i]) <
          distance(ordered.last, remaining[nearest]))
        nearest = i;
    }
    ordered.add(remaining.removeAt(nearest));
  }
  // Never make the proximity estimate worse than the user's order.
  if (length(stops) < length(ordered)) ordered = List.of(stops);
  for (var pass = 0; pass < 12; pass++) {
    var improved = false;
    for (var a = 1; a < ordered.length - 1; a++) {
      for (var b = a + 1; b < ordered.length; b++) {
        final candidate = [
          ...ordered.take(a),
          ...ordered.sublist(a, b + 1).reversed,
          ...ordered.skip(b + 1),
        ];
        if (length(candidate) + 1e-12 < length(ordered)) {
          ordered = candidate;
          improved = true;
        }
      }
    }
    if (!improved) break;
  }
  return ordered;
}
