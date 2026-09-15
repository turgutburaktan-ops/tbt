import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/models/nearby_venue.dart';
import '../lib/models/photo_spot.dart';
import '../lib/screens/places_hub_screen.dart';
import '../lib/services/route_selection_service.dart';
import '../lib/theme/app_theme.dart';

class Catalog extends PlacesDataSource {
  const Catalog();
  @override
  String get selectedCity => 'Elazığ';
  @override
  Future<List<PhotoSpot>> spots() async => const [
    PhotoSpot(
      id: 'test-harput',
      name: 'Harput Kalesi',
      city: 'Elazığ',
      latitude: 38.7,
      longitude: 39.25,
      rating: 4.8,
      bestTime: '',
      angle: '',
      imageUrl: '',
      category: 'Tarihi yer',
      tags: ['FirestoreDoğrulanmış'],
    ),
    PhotoSpot(
      id: 'test-cami',
      name: 'İzzet Paşa Camii',
      city: 'Elazığ',
      latitude: 38.67,
      longitude: 39.22,
      rating: 0,
      bestTime: '',
      angle: '',
      imageUrl: '',
      category: 'Cami',
      tags: ['FirestoreDoğrulanmış'],
    ),
  ];
  @override
  Future<List<NearbyVenue>> venues({
    required NearbyVenueCategory category,
    required double latitude,
    required double longitude,
    void Function(List<NearbyVenue>)? onUpdate,
  }) async => [];
}

class FailingCatalog extends Catalog {
  const FailingCatalog();
  @override
  Future<List<NearbyVenue>> venues({
    required NearbyVenueCategory category,
    required double latitude,
    required double longitude,
    void Function(List<NearbyVenue>)? onUpdate,
  }) async => throw Exception('unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      for (final family in ['Ahem', 'Roboto']) {
        final font = FontLoader(family)
          ..addFont(
            File('$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf')
                .readAsBytes()
                .then(ByteData.sublistView),
          );
        await font.load();
      }
      final icons = File(
        '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (await icons.exists())
        await (FontLoader(
          'MaterialIcons',
        )..addFont(icons.readAsBytes().then(ByteData.sublistView))).load();
    }
  });
  setUp(() => RouteSelectionService.instance.clear());
  tearDown(() => RouteSelectionService.instance.clear());

  testWidgets(
    'four categories fit one row; category changes keep search and route basket',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark.copyWith(
            textTheme: AppTheme.dark.textTheme.apply(fontFamily: 'Roboto'),
          ),
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: const PlacesHubScreen(source: Catalog()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final y = tester.getCenter(find.text('Gezi')).dy;
      for (final label in ['Lezzet', 'Kafeler', 'Oteller']) {
        expect(tester.getCenter(find.text(label)).dy, y);
      }
      expect(find.text('★ 0.0'), findsNothing);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/places-review').create(recursive: true);
        await File('build/places-review/places.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(find.text('Rotaya ekle').first);
      await tester.pumpAndSettle();
      expect(
        RouteSelectionService.instance.selected.value.values.single.name,
        'Harput Kalesi',
      );
      await tester.enterText(find.byType(TextField), 'Harput');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oteller'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gezi'));
      await tester.pumpAndSettle();
      expect(find.text('Harput Kalesi'), findsOneWidget);
      expect(find.text('İzzet Paşa Camii'), findsNothing);
      expect(find.text('Rotaya eklendi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'city search accepts Turkish city names; keyboard does not overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark.copyWith(
            textTheme: AppTheme.dark.textTheme.apply(fontFamily: 'Roboto'),
          ),
          home: const Scaffold(body: PlacesHubScreen(source: Catalog())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elazığ'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'istanbul');
      await tester.pumpAndSettle();
      expect(find.text('İstanbul'), findsOneWidget);
      await tester.tap(find.text('İstanbul'));
      await tester.pumpAndSettle();
      expect(find.text('İstanbul'), findsOneWidget);
      expect(find.text('Harput Kalesi'), findsNothing);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed category never claims there are no matching places', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: PlacesHubScreen(source: FailingCatalog())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kafeler'));
    await tester.pumpAndSettle();
    expect(find.text('Yerler yüklenemedi.'), findsOneWidget);
    expect(find.text('0 yer'), findsNothing);
    expect(find.textContaining('Bu filtrelerde yer bulunamadı'), findsNothing);
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
