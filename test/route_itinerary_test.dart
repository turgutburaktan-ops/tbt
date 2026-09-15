import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../lib/services/route_itinerary_service.dart';

Map<String, dynamic> fixture() => {
  'code': 'Ok',
  'routes': [
    {
      'geometry': {
        'coordinates': [
          [29, 41],
          [29.01, 41.01],
          [29.02, 41.02],
        ],
      },
      'legs': [
        {'distance': 1800, 'duration': 300},
        {'distance': 2300, 'duration': 420},
      ],
    },
  ],
};
void main() {
  test('distance and duration are sums of actual routed legs', () {
    final r = RouteItineraryService.decode(fixture(), 3)!;
    expect(r.meters, 4100);
    expect(r.seconds, 720);
    expect(r.legs.length, 2);
    expect(r.points.last.latitude, 41.02);
  });
  test(
    'no route and incomplete routes never become straight line distances',
    () {
      expect(RouteItineraryService.decode({'code': 'NoRoute'}, 3), isNull);
      expect(RouteItineraryService.decode(fixture(), 4), isNull);
      final d = fixture();
      d['routes'][0]['legs'][0].remove('distance');
      expect(RouteItineraryService.decode(d, 3), isNull);
    },
  );
  test('walking uses a separate graph and sends all ordered stops', () async {
    late Uri url;
    final service = RouteItineraryService(
      client: MockClient((r) async {
        url = r.url;
        return http.Response(jsonEncode(fixture()), 200);
      }),
    );
    const points = [LatLng(41, 29), LatLng(41.01, 29.01), LatLng(41.02, 29.02)];
    expect(await service.calculate(points, 'Yürüyüş'), isNotNull);
    expect(url.path, contains('routed-foot'));
    expect(url.path, contains('29.0,41.0;29.01,41.01;29.02,41.02'));
    expect(url.queryParameters['radiuses'], '100;100;100');
  });
  test(
    'unsupported transport and network failures do not use driving estimates',
    () async {
      final service = RouteItineraryService(
        client: MockClient((_) async => http.Response('unavailable', 503)),
      );
      expect(
        await service.calculate([
          const LatLng(41, 29),
          const LatLng(42, 30),
        ], 'Araç'),
        isNull,
      );
      expect(
        await service.calculate([
          const LatLng(41, 29),
          const LatLng(42, 30),
        ], 'Otobüs'),
        isNull,
      );
    },
  );
}
