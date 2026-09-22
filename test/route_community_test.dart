import 'package:flutter_test/flutter_test.dart';

import '../lib/services/route_community.dart';

void main() {
  test(
    'private copy preserves geometry and difficulty without old event data',
    () {
      final geometry = [
        {'lat': 38.6, 'lng': 39.2},
        {'lat': 38.7, 'lng': 39.3},
      ];
      final copy = copyRouteDayPlan({
        'geometry': geometry,
        'difficulty': 'Orta',
        'description': 'Parkur',
        'startAt': 'yesterday',
        'meetingPoint': {'label': 'private'},
        'memberIds': ['someone'],
        'album': ['photo'],
        'invitedIds': ['friend'],
      });
      expect(copy['geometry'], geometry);
      expect(copy['difficulty'], 'Orta');
      expect(
        copy.keys,
        unorderedEquals(['geometry', 'difficulty', 'description']),
      );
    },
  );
  test('only custom non-business stops can enter Gezi suggestion flow', () {
    expect(canSuggestRouteStop({'id': 'custom_1'}), isTrue);
    expect(canSuggestRouteStop({'id': 'map:38.600000,39.200000'}), isTrue);
    expect(canSuggestRouteStop({'id': 'catalog_1'}), isFalse);
    expect(canSuggestRouteStop({'id': 'custom_1', 'venue': {}}), isFalse);
  });
}
