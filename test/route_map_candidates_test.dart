import 'package:flutter_test/flutter_test.dart';

import '../lib/models/photo_spot.dart';
import '../lib/services/route_map_candidates.dart';

void main() {
  test(
    'large catalog renders bounded cards and panning reveals other places',
    () {
      final places = List.generate(
        1000,
        (i) => PhotoSpot(
          id: 'p$i',
          name: 'Yer $i',
          city: 'İstanbul',
          latitude: 40 + i / 1000,
          longitude: 29,
          rating: 0,
          bestTime: '',
          angle: '',
          imageUrl: '',
        ),
      );
      final first = routeMapCandidates(
        places,
        latitude: 40,
        longitude: 29,
        south: 40,
        north: 40.2,
      );
      final second = routeMapCandidates(
        places,
        latitude: 40.9,
        longitude: 29,
        south: 40.8,
        north: 41,
      );
      expect(first.length, 80);
      expect(second.length, 80);
      expect(first.every((p) => p.latitude <= 40.2), isTrue);
      expect(second.every((p) => p.latitude >= 40.8), isTrue);
      expect(
        first
            .map((p) => p.id)
            .toSet()
            .intersection(second.map((p) => p.id).toSet()),
        isEmpty,
      );
      expect(places.length, 1000);
    },
  );
}
