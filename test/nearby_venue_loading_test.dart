import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:best_photo_spot/models/nearby_venue.dart';
import 'package:best_photo_spot/services/nearby_venue_service.dart';

const venue = NearbyVenue(id: 'node-1', category: NearbyVenueCategory.cafe,
    name: 'Test Kafe', latitude: 38.67, longitude: 39.22);
const key = 'city_venues_v9_cafe_80000_387_392_nearby';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('disk cache is published while business refresh is pending', () async {
    SharedPreferences.setMockInitialValues({key: jsonEncode({
      'savedAt': DateTime.now().millisecondsSinceEpoch, 'venues': [venue.toJson()],
    })});
    final business = Completer<List<NearbyVenue>>();
    final displayed = Completer<List<NearbyVenue>>();
    var networkCalls = 0;
    final service = NearbyVenueService.forTesting(
      clientFactory: () => MockClient((_) async { networkCalls++; return http.Response('{"elements":[]}', 200); }),
      businessLoader: (_, __, ___, ____) => business.future,
    );
    final pending = service.nearby(category: NearbyVenueCategory.cafe,
      latitude: 38.67, longitude: 39.22,
      onUpdate: (items) { if (!displayed.isCompleted) displayed.complete(items); });
    expect((await displayed.future).single.name, 'Test Kafe');
    expect(business.isCompleted, isFalse);
    business.complete([]);
    expect((await pending).single.id, venue.id);
    expect(networkCalls, 0);
  });

  test('business results appear before OSM and concurrent loads share one request', () async {
    SharedPreferences.setMockInitialValues({});
    final osm = Completer<http.Response>();
    final displayed = Completer<void>();
    var networkCalls = 0;
    final service = NearbyVenueService.forTesting(
      clientFactory: () => MockClient((_) { networkCalls++; return osm.future; }),
      businessLoader: (_, __, ___, ____) async => [venue],
    );
    final first = service.nearby(category: NearbyVenueCategory.cafe,
      latitude: 38.67, longitude: 39.22,
      onUpdate: (items) { if (!displayed.isCompleted) displayed.complete(); });
    final second = service.nearby(category: NearbyVenueCategory.cafe,
      latitude: 38.67, longitude: 39.22);
    await displayed.future;
    expect(osm.isCompleted, isFalse);
    osm.complete(http.Response('{"elements":[]}', 200));
    final results = await Future.wait([first, second]);
    expect(results.every((items) => items.single.id == venue.id), isTrue);
    expect(networkCalls, 1);
  });

  test('failed background refresh retains stale disk results', () async {
    SharedPreferences.setMockInitialValues({key: jsonEncode({
      'savedAt': 0, 'venues': [venue.toJson()],
    })});
    var networkCalls = 0;
    final service = NearbyVenueService.forTesting(
      clientFactory: () => MockClient((_) async { networkCalls++; throw Exception('offline'); }),
      businessLoader: (_, __, ___, ____) async => [],
    );
    final items = await service.nearby(category: NearbyVenueCategory.cafe,
      latitude: 38.67, longitude: 39.22);
    expect(items.single.id, venue.id);
    expect(networkCalls, 2);
  });
}
