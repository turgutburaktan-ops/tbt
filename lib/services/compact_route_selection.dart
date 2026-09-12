import '../models/photo_spot.dart';
import 'day_plan_engine.dart';

/// Conservative suggestions until ferry schedules and transfers are supported.
bool needsWaterTransfer(PhotoSpot spot) {
  final category = foldDayCity(spot.category);
  return category == 'ada' ||
      category.contains('adalar') ||
      spot.tags.any(
        (tag) => ['ada', 'feribot', 'vapur'].contains(foldDayCity(tag)),
      );
}

List<PhotoSpot> selectCompactRoute(
  List<PhotoSpot> ranked, {
  required int hours,
  required String transport,
  required int limit,
}) {
  if (hours < 1 || limit < 1) return [];
  final remaining = ranked
      .where(
        (spot) =>
            !needsWaterTransfer(spot) &&
            DayPlanEngine.coordinates(spot.latitude, spot.longitude),
      )
      .toList();
  if (remaining.isEmpty) return [];
  final origin = remaining.first;
  final selected = <PhotoSpot>[];
  final seen = <String>{};
  var previous = origin, spent = 0.0;
  final speed = transport == 'Yürüyüş'
      ? 4.0
      : transport == 'Bisiklet'
      ? 12.0
      : 25.0;
  double km(PhotoSpot a, PhotoSpot b) =>
      DayPlanEngine.distance(a.latitude, a.longitude, b.latitude, b.longitude);
  while (remaining.isNotEmpty && selected.length < limit) {
    remaining.sort((a, b) => km(previous, a).compareTo(km(previous, b)));
    final stop = remaining.removeAt(0);
    if (!seen.add(stop.id)) continue;
    final leg = km(previous, stop);
    if (leg >
        (hours <= 3
            ? 8
            : hours <= 5
            ? 15
            : 25))
      continue;
    final travel = leg * 1.4 / speed * 60;
    final back = km(stop, origin) * 1.4 / speed * 60;
    if (spent + travel + 45 + back > hours * 60) continue;
    spent += travel + 45;
    selected.add(stop);
    previous = stop;
  }
  return selected;
}
