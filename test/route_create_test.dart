import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/models/photo_spot.dart';
import '../lib/screens/route_create_screen.dart';
import '../lib/services/route_draft_store.dart';
import '../lib/theme/app_theme.dart';
import '../lib/widgets/route_design/route_design.dart';

const stop = PhotoSpot(
  id: 'map:harput',
  name: 'Harput',
  city: 'Elazığ',
  latitude: 38.7,
  longitude: 39.25,
  rating: 0,
  bestTime: '',
  angle: '',
  imageUrl: '',
  category: 'Konum',
);
Future<List<PhotoSpot>> catalog(int category) async => const [];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> open(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark,
      home: RouteCreateScreen(initialStops: const [stop], loadCatalog: catalog)));
    await tester.pumpAndSettle();
  }
  testWidgets('four stages preserve transport and selected stops', (tester) async {
    await open(tester);
    expect(find.text('Yeni rota'), findsOneWidget);
    await tester.tap(find.text('Bisiklet'));
    await tester.tap(find.text('Rotanı oluşturmaya başla'));
    await tester.pumpAndSettle();
    expect(find.text('Rotam'), findsOneWidget);
    expect(find.text('1 durak'), findsOneWidget);
    await tester.tap(find.text('Rotayı incele'));
    await tester.pumpAndSettle();
    expect(find.text('Rotayı düzenle'), findsOneWidget);
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(find.text('Elazığ gezisi'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Elazığ gezisi'), 'Sabah bisikleti');
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rotayı düzenle'));
    await tester.pumpAndSettle();
    expect(find.text('1 durak'), findsOneWidget);
    expect(tester.widget<RouteModePicker>(find.byType(RouteModePicker)).value, 'Bisiklet');
    expect(tester.takeException(), isNull);
  });
  testWidgets('removal disables review and undo restores the stop once', (tester) async {
    await open(tester);
    await tester.tap(find.text('Rotanı oluşturmaya başla'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Durağı kaldır'));
    await tester.tap(find.byTooltip('Durağı kaldır'));
    await tester.pumpAndSettle();
    expect(find.text('0 durak'), findsOneWidget);
    expect(tester.widget<RouteAction>(find.widgetWithText(RouteAction, 'Rotayı incele')).onPressed, isNull);
    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();
    expect(find.text('1 durak'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('320px screen keeps the start action visible without overflow', (tester) async {
    await open(tester, width: 320);
    expect(find.text('Rotanı oluşturmaya başla').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
    'draft storage isolates accounts and preserves mixed stop metadata',
    () async {
      SharedPreferences.setMockInitialValues({});
      await RouteDraftStore.write('a', {
        'step': 2,
        'stops': [RouteDraftStore.encodeSpot(stop)],
        'visibility': 'followers',
      });
      expect(await RouteDraftStore.read('b'), isNull);
      final draft = (await RouteDraftStore.read('a'))!;
      expect(draft['visibility'], 'followers');
      final restored = RouteDraftStore.decodeSpot(
        Map<String, dynamic>.from(draft['stops'][0]),
      );
      expect(restored.id, stop.id);
      expect(restored.latitude, stop.latitude);
      expect(restored.city, stop.city);
      await RouteDraftStore.clear('a');
      expect(await RouteDraftStore.read('a'), isNull);
    },
  );
}
