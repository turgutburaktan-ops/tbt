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
const key = 'city_venues_v10_province_cafe_80000_387_392_nearby';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      reportIncomplete: true,
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
      reportIncomplete: true,
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
        reportIncomplete: true,
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
        reportIncomplete: true,
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
    await expectLater(
      service.nearby(
        category: NearbyVenueCategory.cafe,
        reportIncomplete: true,
        latitude: 38.67,
        longitude: 39.22,
      ),
      throwsA(
        isA<VenueLoadException>().having(
          (e) => e.venues.single.id,
          'preserved place',
          venue.id,
        ),
      ),
    );
    expect(networkCalls, 2);
  });
  test(
    'partial business list is reported as incomplete when OSM fails',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = NearbyVenueService.forTesting(
        clientFactory: () =>
            MockClient((_) async => http.Response('busy', 429)),
        businessLoader: (_, __, ___, ____) async => [venue],
      );
      await expectLater(
        service.nearby(
          category: NearbyVenueCategory.cafe,
          reportIncomplete: true,
          latitude: 38.67,
          longitude: 39.22,
        ),
        throwsA(
          isA<VenueLoadException>().having(
            (e) => e.venues.single.id,
            'partial place',
            venue.id,
          ),
        ),
      );
    },
  );

  test('valid empty response is not a network error', () async {
    SharedPreferences.setMockInitialValues({});
    final service = NearbyVenueService.forTesting(
      clientFactory: () =>
          MockClient((_) async => http.Response('{"elements":[]}', 200)),
      businessLoader: (_, __, ___, ____) async => [],
    );
    expect(
      await service.nearby(
        category: NearbyVenueCategory.cafe,
        reportIncomplete: true,
        latitude: 38.67,
        longitude: 39.22,
      ),
      isEmpty,
    );
  });
  test('category source requests are serialized', () async {
    SharedPreferences.setMockInitialValues({});
    final firstResponse = Completer<http.Response>();
    final started = Completer<void>();
    var calls = 0;
    final service = NearbyVenueService.forTesting(
      clientFactory: () => MockClient((_) async {
        calls++;
        if (calls == 1) {
          started.complete();
          return firstResponse.future;
        }
        return http.Response('{"elements":[]}', 200);
      }),
      businessLoader: (_, __, ___, ____) async => [],
    );
    final first = service.nearby(
      category: NearbyVenueCategory.cafe,
      latitude: 38.67,
      longitude: 39.22,
    );
    await started.future;
    final second = service.nearby(
      category: NearbyVenueCategory.dining,
      latitude: 38.67,
      longitude: 39.22,
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    firstResponse.complete(http.Response('{"elements":[]}', 200));
    await Future.wait([first, second]);
    expect(calls, 2);
  });
  test('province query keeps distant districts and street names, without a result cap', () async {
    SharedPreferences.setMockInitialValues({});
    String query = '';
    final service = NearbyVenueService.forTesting(
      clientFactory: () => MockClient((request) async {
        query = request.bodyFields['data']!;
        return http.Response(
          jsonEncode({
            'elements': [
              {'type': 'area', 'id': 3600000023},
              for (var i = 0; i < 650; i++)
                {
                  'type': 'node',
                  'id': i,
                  'lat': 38.9,
                  'lon': 40.0,
                  'tags': {
                    'name': 'Kafe $i',
                    'amenity': 'cafe',
                    'addr:city': 'Karakoçan',
                    'addr:street': 'Malatya Caddesi',
                  },
                },
            ],
          }),
          200,
        );
      }),
      businessLoader: (_, __, ___, ____) async => [],
    );
    service.selectCity(
      name: 'Elazığ',
      latitude: 38.6748,
      longitude: 39.2225,
      south: 38.1248,
      west: 38.5725,
      north: 39.2248,
      east: 39.8725,
    );
    final items = await service.nearby(
      category: NearbyVenueCategory.cafe,
      latitude: 38.6748,
      longitude: 39.2225,
    );
    expect(query, contains('"ISO3166-2"="TR-23"'));
    expect(query, contains('nwr(area.province)'));
    expect(query, isNot(contains('around:')));
    expect(items.length, 650);
  });

  test('forced refresh bypasses a fresh ten-place cache', () async {
    SharedPreferences.setMockInitialValues({
      key: jsonEncode({
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'venues': [
          for (var i = 0; i < 10; i++)
            {...venue.toJson(), 'id': 'old-$i', 'name': 'Old $i'},
        ],
      }),
    });
    var calls = 0;
    final service = NearbyVenueService.forTesting(
      clientFactory: () => MockClient((_) async {
        calls++;
        return http.Response('{"elements":[]}', 200);
      }),
      businessLoader: (_, __, ___, ____) async => [],
    );
    expect(
      (await service.nearby(
        category: NearbyVenueCategory.cafe,
        latitude: 38.67,
        longitude: 39.22,
      )).length,
      10,
    );
    expect(calls, 0);
    expect(
      await service.nearby(
        category: NearbyVenueCategory.cafe,
        latitude: 38.67,
        longitude: 39.22,
        forceRefresh: true,
      ),
      isEmpty,
    );
    expect(calls, 1);
  });

  test('missing province boundary is an error, not an empty cache', () async {
    SharedPreferences.setMockInitialValues({});
    final service = NearbyVenueService.forTesting(
      clientFactory: () =>
          MockClient((_) async => http.Response('{"elements":[]}', 200)),
      businessLoader: (_, __, ___, ____) async => [],
    );
    service.selectCity(name: 'Elazığ', latitude: 38.6748, longitude: 39.2225);
    await expectLater(
      service.nearby(
        category: NearbyVenueCategory.cafe,
        latitude: 38.6748,
        longitude: 39.2225,
      ),
      throwsA(isA<VenueLoadException>()),
    );
  });
}
