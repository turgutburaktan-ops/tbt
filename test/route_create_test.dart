import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/models/photo_spot.dart';
import '../lib/screens/route_create_screen.dart';
import '../lib/services/route_draft_store.dart';
import '../lib/theme/app_theme.dart';
import '../lib/widgets/route_editor_map.dart';

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
  testWidgets('selected catalog place can be removed, re-added and kept across steps', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: RouteCreateScreen(
        initialStops: const [stop],
        loadCatalog: (_) async => const [stop],
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(find.text('Duraklarım (1)'), findsOneWidget);
    await tester.tap(find.text('Kaldır'));
    await tester.pumpAndSettle();
    expect(find.text('Duraklarım (0)'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Devam')).onPressed, isNull);
    await tester.tap(find.byTooltip('Rotaya ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Duraklarım (1)'), findsOneWidget);
    // Tapping the selected row must also undo selection.
    await tester.tap(find.text('Harput'));
    await tester.pumpAndSettle();
    expect(find.text('Duraklarım (0)'), findsOneWidget);
    await tester.tap(find.text('Harput'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duraklarım (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Harput'), findsOneWidget);
    await tester.tap(find.byTooltip('Durağı kaldır'));
    await tester.pumpAndSettle();
    expect(find.text('Duraklarım (0)'), findsOneWidget);
    await tester.tap(find.text('Yer ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rotaya ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Geri'));
    await tester.pumpAndSettle();
    expect(find.text('Duraklarım (1)'), findsOneWidget);
    expect(find.text('Kaldır'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'three steps retain title, transport and stops; map is available separately',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: RouteCreateScreen(
            initialStops: const [stop],
            loadCatalog: catalog,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rotanı başlat'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('Tarih ve saat'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'Hafta sonu');
      await tester.tap(find.text('Bisiklet'));
      await tester.tap(find.text('Devam'));
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);
      expect(find.byType(RouteEditorMap), findsNothing);
      await tester.tap(find.text('Harita'));
      await tester.pumpAndSettle();
      expect(find.byType(RouteEditorMap), findsOneWidget);
      await tester.tap(find.text('Liste'));
      await tester.pumpAndSettle();
      for (final category in ['Gezi', 'Lezzet', 'Kafeler', 'Oteller']) {
        expect(find.text(category), findsOneWidget);
      }
      await tester.tap(find.text('Devam'));
      await tester.pumpAndSettle();
      expect(find.text('3/3'), findsOneWidget);
      expect(find.text('Hafta sonu'), findsOneWidget);
      expect(find.textContaining('Bisiklet'), findsOneWidget);
      expect(find.text('Daha sonra belirle'), findsNWidgets(2));
      await tester.tap(find.text('Kimler katılabilir?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Herkes'));
      await tester.pumpAndSettle();
      expect(find.text('Herkes'), findsOneWidget);
      await tester.tap(find.text('Geri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Geri'));
      await tester.pumpAndSettle();
      expect(find.text('Hafta sonu'), findsOneWidget);
      expect(
        tester
            .widget<SegmentedButton<String>>(
              find.byType(SegmentedButton<String>),
            )
            .selected,
        {'Bisiklet'},
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'small screen has reachable controls and cannot advance without a city or stop',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: RouteCreateScreen(loadCatalog: catalog),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      await tester.tap(find.text('Devam'));
      await tester.pumpAndSettle();
      expect(find.text('1/3'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'ela');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elazığ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Devam'));
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Devam'))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
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
