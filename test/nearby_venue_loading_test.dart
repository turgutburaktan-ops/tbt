import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:best_photo_spot/models/nearby_venue.dart';
import 'package:best_photo_spot/services/nearby_venue_service.dart';

const venue = NearbyVenue(
  id: 'node-1',
  category: NearbyVenueCategory.cafe,
  name: 'Test Kafe',
  latitude: 38.67,
  longitude: 39.22,
);
const key = 'city_venues_v9_cafe_80000_387_392_nearby';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('temporary shelters do not appear as hotels, real hotels remain', () {
    NearbyVenue hotel(String name) => NearbyVenue(
      id: name,
      category: NearbyVenueCategory.hotel,
      name: name,
      latitude: 38.67,
      longitude: 39.22,
    );
    expect(
      NearbyVenueService.suitableForCategory(
        hotel('Sivrice Geçici Barınma Alanı'),
      ),
      isFalse,
    );
    expect(
      NearbyVenueService.suitableForCategory(hotel('Konteyner Kent')),
      isFalse,
    );
    expect(
      NearbyVenueService.suitableForCategory(hotel('Harput Otel')),
      isTrue,
    );
    expect(NearbyVenueService.suitableForCategory(venue), isTrue);
  });

  test('explicit planning coordinates ignore the selected city without changing it', () async {
    SharedPreferences.setMockInitialValues({});
    double? queriedLat, queriedLon;
    final service = NearbyVenueService.forTesting(
      clientFactory: () =>
          MockClient((_) async => http.Response('{"elements":[]}', 200)),
      businessLoader: (_, lat, lon, __) async {
        queriedLat = lat;
        queriedLon = lon;
        return [];
      },
    );
    service.selectCity(name: 'İstanbul', latitude: 41.0082, longitude: 28.9784);
    await service.nearby(
      category: NearbyVenueCategory.cafe,
      latitude: 38.6748,
      longitude: 39.2225,
      useSelectedCity: false,
    );
    expect(queriedLat, 38.6748);
    expect(queriedLon, 39.2225);
    expect(service.selectedCityName, 'İstanbul');
  });

  test('disk cache is published while business refresh is pending', () async {
    SharedPreferences.setMockInitialValues({
      key: jsonEncode({
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'venues': [venue.toJson()],
      }),
    });
    final business = Completer<List<NearbyVenue>>();
    final displayed = Completer<List<NearbyVenue>>();
    var networkCalls = 0;
    final service = NearbyVenueService.forTesting(
      clientFactory: () => MockClient((_) async {
        networkCalls++;
        return http.Response('{"elements":[]}', 200);
      }),
      businessLoader: (_, __, ___, ____) => business.future,
    );
    final pending = service.nearby(
      category: NearbyVenueCategory.cafe,
      latitude: 38.67,
      longitude: 39.22,
      onUpdate: (items) {
        if (!displayed.isCompleted) displayed.complete(items);
      },
    );
    expect((await displayed.future).single.name, 'Test Kafe');
    expect(business.isCompleted, isFalse);
    business.complete([]);
    expect((await pending).single.id, venue.id);
    expect(networkCalls, 0);
  });

  test(
    'business results appear before OSM and concurrent loads share one request',
    () async {
      SharedPreferences.setMockInitialValues({});
      final osm = Completer<http.Response>();
      final displayed = Completer<void>();
      var networkCalls = 0;
      final service = NearbyVenueService.forTesting(
        clientFactory: () => MockClient((_) {
          networkCalls++;
          return osm.future;
        }),
        businessLoader: (_, __, ___, ____) async => [venue],
      );
      final first = service.nearby(
        category: NearbyVenueCategory.cafe,
        latitude: 38.67,
        longitude: 39.22,
        onUpdate: (items) {
          if (!displayed.isCompleted) displayed.complete();
        },
      );
      await displayed.future;
      final lateDisplay = Completer<void>();
      final second = service.nearby(
        category: NearbyVenueCategory.cafe,
        latitude: 38.67,
        longitude: 39.22,
        onUpdate: (_) {
          if (!lateDisplay.isCompleted) lateDisplay.complete();
        },
      );
      await lateDisplay.future;
      expect(osm.isCompleted, isFalse);
      osm.complete(http.Response('{"elements":[]}', 200));
      final results = await Future.wait([first, second]);
      expect(results.every((items) => items.single.id == venue.id), isTrue);
      expect(networkCalls, 1);
    },
  );

  test('failed background refresh retains stale disk results', () async {
    SharedPreferences.setMockInitialValues({
      key: jsonEncode({
        'savedAt': 0,
        'venues': [venue.toJson()],
      }),
    });
    var networkCalls = 0;
    final service = NearbyVenueService.forTesting(
      clientFactory: () => MockClient((_) async {
        networkCalls++;
        throw Exception('offline');
      }),
      businessLoader: (_, __, ___, ____) async => [],
    );
    final items = await service.nearby(
      category: NearbyVenueCategory.cafe,
      latitude: 38.67,
      longitude: 39.22,
    );
    expect(items.single.id, venue.id);
    expect(networkCalls, 2);
  });
}
