import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../lib/models/photo_spot.dart';
import '../lib/models/travel_plan.dart';
import '../lib/services/route_geometry.dart';
import '../lib/screens/route_create_screen.dart';
import '../lib/widgets/route_editor_map.dart';
import '../lib/theme/app_theme.dart';

void main() {
  final rows = jsonDecode(File('functions/scripts/elazig_expansion_routes.json').readAsStringSync()) as List;
  final source = Map<String, dynamic>.from(rows.firstWhere((r) => r['id'].toString().contains('hazarbaba')) as Map);
  final day = Map<String, dynamic>.from(source['dayPlan'] as Map);
  final stops = (source['stopSnapshots'] as List).map((s) => PhotoSpot(
    id: s['id'], name: s['name'], city: s['city'],
    latitude: (s['latitude'] as num).toDouble(), longitude: (s['longitude'] as num).toDouble(),
    rating: 0, bestTime: '', angle: '', imageUrl: '', category: 'Gezi',
  )).toList();

  test('Hazarbaba closed trail restores its full geometry and nonzero distance', () {
    expect(stops.first.latitude, stops.last.latitude);
    expect(stops.first.longitude, stops.last.longitude);
    final restored = RouteGeometry.restoreForEdit(day, stops, 'Yürüyüş')!;
    expect(restored.points.length, (day['geometry'] as List).length);
    expect(restored.meters / 1000, closeTo(source['distanceKm'], .000001));
    expect(restored.seconds / 60, closeTo(source['travelMinutes'], .000001));
    expect(restored.points.toSet().length, greaterThan(100));
    expect(restored.points.any((p) => p != LatLng(stops.first.latitude, stops.first.longitude)), isTrue);
  });
  test('changed inputs never restore stale geometry; undo can restore the source', () {
    expect(RouteGeometry.restoreForEdit(day, stops, 'Bisiklet'), isNull);
    expect(RouteGeometry.restoreForEdit(day, stops.reversed.toList(), 'Yürüyüş'), isNotNull); // Same coordinates, same full loop.
    expect(RouteGeometry.restoreForEdit(day, [stops.first], 'Yürüyüş'), isNull);
    expect(RouteGeometry.restoreForEdit(day, stops, 'Yürüyüş', origin: const LatLng(38, 39)), isNull);
    expect(RouteGeometry.restoreForEdit(day, stops, 'Yürüyüş', roundTrip: true), isNull);
    expect(RouteGeometry.restoreForEdit(day, stops, 'Yürüyüş', manual: true), isNull);
    expect(RouteGeometry.restoreForEdit({...day, 'geometry': []}, stops, 'Yürüyüş'), isNull);
    expect(RouteGeometry.restoreForEdit(day, stops, 'Yürüyüş'), isNotNull);
  });
  testWidgets('opening edit preserves the trail and labels the final stop as finish', (tester) async {
    final now = DateTime.now();
    final plan = TravelPlan(id: 'personal_hazarbaba', ownerId: 'owner', title: source['title'], city: 'Elazığ',
      durationHours: 5, budget: 'Orta', transport: 'Yürüyüş', interests: const [],
      spotIds: stops.map((s) => s.id).toList(), spotNames: stops.map((s) => s.name).toList(), memberIds: const ['owner'],
      startAt: now, createdAt: now, updatedAt: now, dayPlan: day,
      distanceKm: (source['distanceKm'] as num).toDouble(), travelMinutes: source['travelMinutes']);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: RouteCreateScreen(
      existingPlan: plan, initialStops: stops, loadCatalog: (_) async => [])));
    await tester.pump();
    final map = tester.widget<RouteEditorMap>(find.byType(RouteEditorMap).first);
    expect(map.itinerary!.points.length, (day['geometry'] as List).length);
    expect(map.itinerary!.meters, greaterThan(10000));
    expect(find.text('0.0 km · 0 dk yol'), findsNothing);
    expect(find.text('Bitiş'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
