import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/photo_spot.dart';
import 'route_itinerary_service.dart';

/// Persist geometry with a signature so editing stops never displays an old line.
class RouteGeometry {
  static String signature(
    List<PhotoSpot> stops,
    String mode, {
    LatLng? origin,
    bool roundTrip = false,
  }) =>
      '$mode|${origin?.latitude},${origin?.longitude}|$roundTrip|${stops.map((s) => '${s.latitude},${s.longitude}').join(';')}';
  /// Reuse a recorded trail only while the route inputs still match it.
  static RouteItinerary? restoreForEdit(
    Map<String, dynamic> data, List<PhotoSpot> stops, String mode, {
    LatLng? origin, bool roundTrip = false, bool manual = false,
  }) {
    if ((data['manual'] == true) != manual ||
        data['signature'] != signature(stops, mode, origin: origin, roundTrip: roundTrip)) return null;
    final route = decode(data);
    if (route == null || route.meters <= 0) return null;
    return route;
  }

  static List<LatLng> waypoints(
    List<PhotoSpot> stops, {
    LatLng? origin,
    bool roundTrip = false,
  }) {
    final points = [
      if (origin != null) origin,
      ...stops.map((s) => LatLng(s.latitude, s.longitude)),
    ];
    if (roundTrip && points.length > 1 && points.first != points.last)
      points.add(points.first);
    return points;
  }

  static double distance(LatLng a, LatLng b) {
    const r = math.pi / 180;
    final x =
        math.pow(math.sin((b.latitude - a.latitude) * r / 2), 2) +
        math.cos(a.latitude * r) *
            math.cos(b.latitude * r) *
            math.pow(math.sin((b.longitude - a.longitude) * r / 2), 2);
    return 6371000 * 2 * math.asin(math.sqrt(x.clamp(0, 1)));
  }

  static RouteItinerary manual(List<LatLng> points) => RouteItinerary(points, [
    for (var i = 1; i < points.length; i++)
      RouteLeg(distance(points[i - 1], points[i]), 0),
  ]);
  static Map<String, dynamic> encode(
    RouteItinerary? route,
    String signature, {
    required bool manual,
    required bool roundTrip,
  }) => {
    'routeVersion': 2,
    'signature': signature,
    'manual': manual,
    'roundTrip': roundTrip,
    if (route != null)
      'geometry': [
        for (var i = 0; i < route.points.length; i++)
          if (i == 0 ||
              i == route.points.length - 1 ||
              i % math.max(1, (route.points.length / 1800).ceil()) == 0)
            {'lat': route.points[i].latitude, 'lng': route.points[i].longitude},
      ],
    if (route != null)
      'legs':
          route.legs
              .map((l) => {'meters': l.meters, 'seconds': l.seconds})
              .toList(),
  };
  static RouteItinerary? decode(Map<String, dynamic> data) {
    try {
      final raw = data['geometry'] as List;
      if (raw.length < 2 || raw.length > 2000) return null;
      final points = <LatLng>[];
      for (final p in raw) {
        final lat = (p['lat'] as num).toDouble();
        final lng = (p['lng'] as num).toDouble();
        if (!lat.isFinite || !lng.isFinite || lat.abs() > 90 || lng.abs() > 180)
          return null;
        points.add(LatLng(lat, lng));
      }
      final legs =
          (data['legs'] as List)
              .map(
                (p) => RouteLeg(
                  (p['meters'] as num).toDouble(),
                  (p['seconds'] as num).toDouble(),
                ),
              )
              .toList();
      if (points.length < 2 ||
          points.length > 2000 ||
          points.any(
            (p) =>
                !p.latitude.isFinite ||
                !p.longitude.isFinite ||
                p.latitude.abs() > 90 ||
                p.longitude.abs() > 180,
          ) ||
          legs.any(
            (l) =>
                !l.meters.isFinite ||
                l.meters < 0 ||
                !l.seconds.isFinite ||
                l.seconds < 0,
          ))
        return null;
      return RouteItinerary(points, legs);
    } catch (_) {
      return null;
    }
  }
}
