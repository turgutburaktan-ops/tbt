import 'dart:math' as math;

import '../models/photo_spot.dart';

String foldPlaceText(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c');

List<PhotoSpot> browseCitySpots(
  List<PhotoSpot> spots, {
  required String? city,
  String query = '',
  bool nearest = true,
  double? latitude,
  double? longitude,
}) {
  if (city == null || city.trim().isEmpty) return [];
  final key = foldPlaceText(query);
  final result = spots
      .where(
        (spot) =>
            foldPlaceText(spot.city) == foldPlaceText(city) &&
            (key.isEmpty ||
                foldPlaceText(
                  '${spot.name} ${spot.category} ${spot.description} ${spot.tags.join(' ')}',
                ).contains(key)),
      )
      .toList();
  double distance(PhotoSpot spot) {
    const rad = math.pi / 180;
    final dlat = (spot.latitude - latitude!) * rad;
    final dlon = (spot.longitude - longitude!) * rad;
    return math.pow(math.sin(dlat / 2), 2).toDouble() +
        math.cos(latitude * rad) *
            math.cos(spot.latitude * rad) *
            math.pow(math.sin(dlon / 2), 2);
  }

  result.sort((a, b) {
    if (nearest && latitude != null && longitude != null) {
      final order = distance(a).compareTo(distance(b));
      if (order != 0) return order;
    }
    final rating = b.rating.compareTo(a.rating);
    return rating != 0 ? rating : a.name.compareTo(b.name);
  });
  return result;
}
