import 'package:flutter_test/flutter_test.dart';

import '../lib/models/photo_spot.dart';
import '../lib/services/compact_route_selection.dart';

PhotoSpot spot(
  String id,
  double lat,
  double lon, {
  String category = 'Tarihi yapı',
}) => PhotoSpot(
  id: id,
  name: id,
  city: 'İstanbul',
  latitude: lat,
  longitude: lon,
  rating: 4,
  bestTime: '',
  angle: '',
  imageUrl: '',
  category: category,
);
void main() {
  test(
    'short plan chooses nearby stops over distant high ranked ones and islands',
    () {
      final result = selectCompactRoute(
        [
          spot('start', 41.01, 28.97),
          spot('far', 41.2, 29.8),
          spot('island', 41.02, 28.98, category: 'Ada'),
          spot('near', 41.011, 28.971),
        ],
        hours: 3,
        transport: 'Yürüyüş',
        limit: 5,
      );
      expect(result.map((s) => s.id), ['start', 'near']);
    },
  );
  test('visit time limits number of stops and duplicates are ignored', () {
    final a = spot('a', 41.01, 28.97);
    final result = selectCompactRoute(
      [a, a, spot('b', 41.01, 28.97)],
      hours: 1,
      transport: 'Araç',
      limit: 5,
    );
    expect(result.map((s) => s.id), ['a']);
  });
  test('invalid coordinates and empty inputs produce no recommendation', () {
    expect(
      selectCompactRoute(
        [spot('bad', 0, 0)],
        hours: 3,
        transport: 'Araç',
        limit: 5,
      ),
      isEmpty,
    );
    expect(
      selectCompactRoute([], hours: 3, transport: 'Araç', limit: 5),
      isEmpty,
    );
  });
}
