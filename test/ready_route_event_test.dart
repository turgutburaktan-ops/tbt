import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/travel_plan.dart';
import '../lib/screens/routes_hub_screen.dart';
import '../lib/screens/ready_route_event_screen.dart';
import '../lib/services/route_community.dart';
import '../lib/theme/app_theme.dart';

TravelPlan template() => TravelPlan(
  id: 'tbt_ready_test', ownerId: 'editor', title: 'Alacakaya – IV. Murat Hanı yürüyüşü',
  city: 'Elazığ', durationHours: 5, budget: 'Orta', transport: 'Yürüyüş',
  interests: const [], spotIds: const ['a', 'b'], spotNames: const ['A', 'B'], memberIds: const [],
  startAt: DateTime(2026), createdAt: DateTime(2026), updatedAt: DateTime(2026),
  distanceKm: 14.5, travelMinutes: 300,
  dayPlan: const {'difficulty': 'Orta', 'geometry': [{'lat': 38.7, 'lng': 39.2}, {'lat': 38.8, 'lng': 39.3}],
    'signature': 'saved-signature', 'description': 'Kaynak açıklaması', 'privateChat': 'never copy'},
);

void main() {
  testWidgets('compact card has one primary action and no duplicated metadata', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark,
      home: Scaffold(body: SingleChildScrollView(child: RoutePreviewCard(plan: template(), featured: true)))));
    expect(find.text('Etkinlik oluştur'), findsOneWidget);
    expect(find.byTooltip('Planlarıma kaydet'), findsOneWidget);
    expect(find.text('Rotayı aç'), findsNothing);
    expect(find.text('Rotayı kullan'), findsNothing);
    expect(find.text('0 kişi'), findsNothing);
    expect(find.text('14,5 km · 5 saat · 2 durak'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Etkinlik oluştur'));
    await tester.pumpAndSettle();
    expect(find.byType(ReadyRouteEventScreen), findsOneWidget);
    expect(find.text('Etkinlik adı'), findsOneWidget);
    expect(find.text('Katılım için onayım gereksin'), findsNothing); // Private invitations need no extra approval.
    await tester.tap(find.text('Etkinliği oluştur'));
    await tester.pumpAndSettle();
    expect(find.text('İleri bir tarih ve saat seç.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ReadyRouteEventScreen), findsNothing);
    expect(find.text('Etkinlik oluştur'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text remains scrollable on a narrow card', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: Scaffold(body:
      MediaQuery(data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: SingleChildScrollView(child: SizedBox(width: 320,
          child: RoutePreviewCard(plan: template(), featured: true)))))));
    expect(tester.takeException(), isNull);
  });

  test('template copy retains exact track and attribution without private event data', () {
    final source = template();
    final copied = copyRouteDayPlan(source.dayPlan);
    expect(copied['geometry'], source.dayPlan['geometry']);
    expect(copied['signature'], 'saved-signature');
    expect(copied['description'], 'Kaynak açıklaması');
    expect(copied['difficulty'], 'Orta');
    expect(copied.containsKey('privateChat'), isFalse);
  });
}
