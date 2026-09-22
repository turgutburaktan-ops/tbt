import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../lib/services/route_terrain_service.dart';
import '../lib/services/route_itinerary_service.dart';
import '../lib/widgets/route_terrain_summary.dart';

void main() {
  const path = [LatLng(38, 39), LatLng(38.01, 39), LatLng(38.01, 39.02)];
  test(
    'samples follow a bent road, preserve endpoints and bound the request',
    () {
      final samples = RouteTerrainService.samplePath(path);
      expect(samples.first.$1, path.first);
      expect(samples.last.$1, path.last);
      expect(samples.length, lessThanOrEqualTo(100));
      expect(samples.length, greaterThan(3));
      for (final s in samples) {
        expect(
          (s.$1.longitude - 39).abs() < .000001 ||
              (s.$1.latitude - 38.01).abs() < .000001,
          isTrue,
        );
      }
      final long = RouteTerrainService.samplePath([
        const LatLng(38, 39),
        const LatLng(40, 40),
      ]);
      expect(long.length, 100);
      expect(RouteTerrainService.samplePath([path.first, path.first]), isEmpty);
    },
  );
  test('ascent/descent and mode-specific estimated difficulty', () {
    final terrain = RouteTerrain([
      TerrainSample(path.first, 0, 100),
      TerrainSample(path[1], 6000, 400),
      TerrainSample(path.last, 12000, 200),
    ]);
    expect(terrain.gainLoss, (300.0, 200.0));
    expect(terrain.difficulty('Yürüyüş'), 'Orta');
    expect(terrain.difficulty('Bisiklet'), 'Kolay');
    expect(terrain.reason('Yürüyüş'), contains('Zemin'));
    final steep = RouteTerrain([
      TerrainSample(path.first, 0, 0),
      TerrainSample(path.last, 1000, 150),
    ]);
    expect(steep.difficulty('Bisiklet'), 'Zor');
  });
  test(
    'missing, partial, or mismatched elevations never yield a difficulty',
    () {
      final samples = RouteTerrainService.samplePath(path);
      Map<String, dynamic> fixture() => {
        'status': 'OK',
        'results': [
          for (final s in samples)
            {
              'elevation': 100,
              'location': {'lat': s.$1.latitude, 'lng': s.$1.longitude},
            },
        ],
      };
      expect(RouteTerrainService.decode(fixture(), samples), isNotNull);
      final missing = fixture();
      missing['results'][1]['elevation'] = null;
      expect(RouteTerrainService.decode(missing, samples), isNull);
      final wrong = fixture();
      wrong['results'][0]['location']['lat'] = 12;
      expect(RouteTerrainService.decode(wrong, samples), isNull);
      final partial = fixture();
      partial['results'].removeLast();
      expect(RouteTerrainService.decode(partial, samples), isNull);
    },
  );
  test(
    'driving makes no request; walking and cycling share cached geometry',
    () async {
      var calls = 0;
      final service = RouteTerrainService(
        requestInterval: Duration.zero,
        client: MockClient((r) async {
          calls++;
          final locations = r.url.queryParameters['locations']!.split('|');
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'results': [
                for (final l in locations)
                  {
                    'elevation': 100,
                    'location': {
                      'lat': double.parse(l.split(',')[0]),
                      'lng': double.parse(l.split(',')[1]),
                    },
                  },
              ],
            }),
            200,
          );
        }),
      );
      expect(await service.load(path, 'Araç'), isNull);
      expect(calls, 0);
      expect(await service.load(path, 'Yürüyüş'), isNotNull);
      expect(await service.load(path, 'Bisiklet'), isNotNull);
      expect(calls, 1);
    },
  );
  testWidgets('terrain is hidden in driving and renders at narrow width', (
    tester,
  ) async {
    final service = RouteTerrainService(
      requestInterval: Duration.zero,
      client: MockClient((r) async {
        final samples = RouteTerrainService.samplePath(path);
        return http.Response(
          jsonEncode({
            'status': 'OK',
            'results': [
              for (final s in samples)
                {
                  'elevation': 100 + s.$2 / 100,
                  'location': {'lat': s.$1.latitude, 'lng': s.$1.longitude},
                },
            ],
          }),
          200,
        );
      }),
    );
    final route = RouteItinerary(path, [const RouteLeg(3000, 1000)]);
    await service.load(path, 'Yürüyüş');
    Widget view(String mode) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: RouteTerrainSummary(
              route: route,
              mode: mode,
              service: service,
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(view('Yürüyüş'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tahmini zorluk:'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    expect(find.textContaining('Zemin ve teknik'), findsOneWidget);
    Navigator.of(tester.element(find.byType(ActionChip))).pop();
    await tester.pumpAndSettle();
    await tester.pumpWidget(view('Araç'));
    await tester.pumpAndSettle();
    expect(find.text('Yükselti'), findsNothing);
  });
}
