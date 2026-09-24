import 'package:flutter_test/flutter_test.dart';
import '../lib/models/travel_plan.dart';
import '../lib/screens/route_filters_screen.dart';

TravelPlan route(String city) => TravelPlan(
  id: 'tbt_ready_$city', ownerId: 'editorial', title: city, city: city,
  durationHours: 2, budget: 'Orta', transport: 'Yürüyüş', interests: [],
  spotIds: ['a', 'b'], spotNames: ['A', 'B'], memberIds: [],
  startAt: DateTime(2026), createdAt: DateTime(2026), updatedAt: DateTime(2026),
);
void main() {
  test('selected province limits ready routes and changes with selection', () {
    final routes = [route('Elazığ'), route('Malatya')];
    var filters = const RouteFilters(mode: 'Yürüyüş').withCity('Elazığ');
    expect(routes.where((p) => filters.matches(p, {})).map((p) => p.city), ['Elazığ']);
    filters = filters.withCity('Malatya');
    expect(filters.mode, 'Yürüyüş');
    expect(routes.where((p) => filters.matches(p, {})).map((p) => p.city), ['Malatya']);
    filters = filters.withCity('Tunceli');
    expect(routes.where((p) => filters.matches(p, {})), isEmpty);
  });
}
