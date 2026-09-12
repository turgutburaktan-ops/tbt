import 'dart:math' as math;

import '../models/photo_spot.dart';
import '../models/nearby_venue.dart';

String foldDayCity(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('i̇', 'i')
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c');

class DayPlanRequest {
  final String city, transport, company, mood;
  final int minutes, people, budgetPerPerson;
  final double latitude, longitude;
  final DateTime startAt;
  const DayPlanRequest({
    required this.city,
    required this.transport,
    required this.company,
    required this.mood,
    required this.minutes,
    required this.people,
    required this.budgetPerPerson,
    required this.latitude,
    required this.longitude,
    required this.startAt,
  });
}

class DayPlanStop {
  final PhotoSpot spot;
  final NearbyVenue? venue;
  // A published menu floor is a lower bound, never a complete meal quote.
  final int? minimumPriceMinor;
  final String priceNote;
  final int stayMinutes;
  const DayPlanStop({
    required this.spot,
    this.venue,
    this.minimumPriceMinor,
    this.priceNote = 'Giriş / harcama bilgisi teyit edilmeli.',
    this.stayMinutes = 45,
  });
  String get id => venue == null
      ? 'spot:${spot.id}'
      : '${venue!.category.name}:${venue!.id}';
}

class DayPlanAlternative {
  final String title;
  final List<DayPlanStop> stops;
  final List<int> arrivalMinutes;
  final int totalMinutes, travelMinutes, minimumPriceMinor;
  final double distanceKm;
  const DayPlanAlternative({
    required this.title,
    required this.stops,
    required this.arrivalMinutes,
    required this.totalMinutes,
    required this.travelMinutes,
    required this.distanceKm,
    required this.minimumPriceMinor,
  });
}

class DayPlanEngine {
  static double distance(double a, double b, double c, double d) {
    double rad(double n) => n * math.pi / 180;
    final x =
        math.pow(math.sin(rad(c - a) / 2), 2) +
        math.cos(rad(a)) *
            math.cos(rad(c)) *
            math.pow(math.sin(rad(d - b) / 2), 2);
    return 6371 * 2 * math.asin(math.sqrt(x.clamp(0, 1)));
  }

  static bool coordinates(double lat, double lon) =>
      lat.isFinite &&
      lon.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lon >= -180 &&
      lon <= 180 &&
      !(lat == 0 && lon == 0);
  static int _travel(double km, DayPlanRequest r) {
    final speed = r.transport == 'Yürüyüş'
        ? (r.company == 'Aile' ? 3.5 : 4.5)
        : r.transport == 'Bisiklet'
        ? 13.0
        : 30.0;
    return (km * 1.35 / speed * 60).ceil();
  }

  static List<DayPlanAlternative> build(
    DayPlanRequest r,
    List<DayPlanStop> source,
  ) {
    if (!coordinates(r.latitude, r.longitude) ||
        r.minutes < 30 ||
        r.people < 1 ||
        r.budgetPerPerson < 0)
      return [];
    final unique = <String, DayPlanStop>{};
    for (final s in source) {
      if (foldDayCity(s.spot.city) != foldDayCity(r.city) ||
          !coordinates(s.spot.latitude, s.spot.longitude) ||
          s.stayMinutes <= 0)
        continue;
      if (foldDayCity(s.spot.category) == 'ada' ||
          s.spot.tags.any(
            (t) => ['ada', 'feribot', 'vapur'].contains(foldDayCity(t)),
          ))
        continue;
      if (s.minimumPriceMinor != null &&
          (s.minimumPriceMinor! < 0 ||
              s.minimumPriceMinor! > r.budgetPerPerson * 100))
        continue;
      unique.putIfAbsent(s.id, () => s);
    }
    double preference(DayPlanStop s) {
      final venue = s.venue;
      final match = r.mood == 'Yemek ve kahve'
          ? venue != null
          : r.mood == 'Gezinti'
          ? venue == null
          : true;
      return (match ? 20 : 0) -
          distance(r.latitude, r.longitude, s.spot.latitude, s.spot.longitude);
    }

    final pool = unique.values.toList()
      ..sort((a, b) {
        final order = preference(b).compareTo(preference(a));
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    final results = <DayPlanAlternative>[];
    final signatures = <String>{};
    for (final seed in pool.take(12)) {
      if (results.length == 2) break;
      final chosen = <DayPlanStop>[], arrivals = <int>[];
      var elapsed = 0, travel = 0, cost = 0;
      var lat = r.latitude, lon = r.longitude, km = 0.0;
      final remaining = [seed, ...pool.where((s) => s.id != seed.id)];
      while (remaining.isNotEmpty && chosen.length < 6) {
        final stop = remaining.removeAt(0), p = stop.spot;
        final legKm = distance(lat, lon, p.latitude, p.longitude);
        final leg = _travel(legKm, r);
        final back = _travel(
          distance(p.latitude, p.longitude, r.latitude, r.longitude),
          r,
        );
        final stay =
            (stop.stayMinutes * (r.company == 'Aile' ? 1.2 : 1)).ceil() +
            (r.people > 4 ? 10 : 0);
        if (elapsed + leg + stay + back > r.minutes ||
            cost + (stop.minimumPriceMinor ?? 0) > r.budgetPerPerson * 100)
          continue;
        // Do not build a short plan composed entirely of repeated coffee/meal stops.
        if (stop.venue != null &&
            chosen.any((s) => s.venue?.category == stop.venue!.category))
          continue;
        arrivals.add(elapsed + leg);
        chosen.add(stop);
        elapsed += leg + stay;
        travel += leg;
        km += legKm * 1.35;
        cost += stop.minimumPriceMinor ?? 0;
        lat = p.latitude;
        lon = p.longitude;
        remaining.sort(
          (a, b) =>
              (distance(lat, lon, a.spot.latitude, a.spot.longitude) -
                      preference(a) * .05)
                  .compareTo(
                    distance(lat, lon, b.spot.latitude, b.spot.longitude) -
                        preference(b) * .05,
                  ),
        );
      }
      if (chosen.isEmpty) continue;
      // A reversed route alone is not a second option.
      final signature = (chosen.map((s) => s.id).toList()..sort()).join('|');
      if (!signatures.add(signature)) continue;
      final backKm = distance(lat, lon, r.latitude, r.longitude),
          back = _travel(backKm, r);
      results.add(
        DayPlanAlternative(
          title: results.isEmpty ? 'Yakından başla' : 'Başka bir seçenek',
          stops: chosen,
          arrivalMinutes: arrivals,
          totalMinutes: elapsed + back,
          travelMinutes: travel + back,
          distanceKm: km + backKm * 1.35,
          minimumPriceMinor: cost,
        ),
      );
    }
    return results;
  }
}

List<PhotoSpot> dayPlanRouteStops(
  List<PhotoSpot> stops,
  double lat,
  double lon,
  String city,
) {
  if (!DayPlanEngine.coordinates(lat, lon)) return stops;
  PhotoSpot origin(String id, String name) => PhotoSpot(
    id: id,
    name: name,
    city: city,
    latitude: lat,
    longitude: lon,
    rating: 0,
    bestTime: '',
    angle: '',
    imageUrl: '',
    category: 'Başlangıç / dönüş',
  );
  return [
    origin('today_origin', 'Başlangıç noktası'),
    ...stops,
    origin('today_return', 'Başlangıç noktasına dönüş'),
  ];
}
