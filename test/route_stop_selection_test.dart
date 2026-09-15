import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/models/photo_spot.dart';
import '../lib/services/route_stop_order.dart';
import '../lib/widgets/route_stop_picker.dart';
import '../lib/theme/app_theme.dart';

PhotoSpot spot(String id, double longitude) => PhotoSpot(
  id: id,
  name: id,
  city: 'Elazığ',
  latitude: 38.6,
  longitude: longitude,
  rating: 0,
  bestTime: '',
  angle: '',
  imageUrl: '',
  category: 'Yer',
);
void main() {
  test('smart order preserves start and all stops without mutating input', () {
    final original = [
      spot('Başlangıç', 39),
      spot('Uzak', 39.4),
      spot('Yakın', 39.1),
      spot('Orta', 39.2),
    ];
    final result = smartOrderStops(original);
    expect(result.map((s) => s.id), ['Başlangıç', 'Yakın', 'Orta', 'Uzak']);
    expect(original.map((s) => s.id), ['Başlangıç', 'Uzak', 'Yakın', 'Orta']);
    expect(result.first, same(original.first));
  });
  test('short and coincident routes keep a stable order', () {
    expect(smartOrderStops([]), isEmpty);
    final same = [spot('a', 39), spot('b', 39), spot('c', 39)];
    expect(smartOrderStops(same).map((s) => s.id), ['a', 'b', 'c']);
    expect(smartOrderStops(same.take(2).toList()).map((s) => s.id), ['a', 'b']);
  });
  testWidgets(
    'multiple selection survives search and category change, then returns once',
    (tester) async {
      List<PhotoSpot>? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showModalBottomSheet<List<PhotoSpot>>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => RouteStopPicker(
                      city: 'Elazığ',
                      stops: const [],
                      multiple: true,
                      loadItems: (category) async => category == 0
                          ? [spot('Harput', 39), spot('Kale', 39.1)]
                          : [spot('Kahve', 39.2)],
                    ),
                  );
                },
                child: const Text('Aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Harput'));
      await tester.pump();
      expect(find.text('Seçilenleri ekle (1)'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Kale');
      await tester.pump();
      await tester.tap(
        find.descendant(of: find.byType(ListTile), matching: find.text('Kale')),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Kafeler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kahve'));
      await tester.pump();
      expect(selected, isNull);
      await tester.tap(find.text('Seçilenleri ekle (3)'));
      await tester.pumpAndSettle();
      expect(selected!.map((s) => s.id), ['Harput', 'Kale', 'Kahve']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('existing stops cannot be duplicated and capacity is enforced', (
    tester,
  ) async {
    final existing = List.generate(11, (i) => spot('Eski $i', 39));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: RouteStopPicker(
            city: 'Elazığ',
            stops: existing,
            multiple: true,
            loadItems: (_) async => [
              existing.first,
              spot('Yeni A', 39.1),
              spot('Yeni B', 39.2),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eski 0'));
    await tester.pump();
    expect(find.text('Eklemek istediğin yerleri seç'), findsOneWidget);
    await tester.tap(find.text('Yeni A'));
    await tester.pump();
    await tester.tap(find.text('Yeni B'));
    await tester.pump();
    expect(find.text('Seçilenleri ekle (1)'), findsOneWidget);
    expect(
      find.text('Rotaya en fazla 12 durak ekleyebilirsin.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Yeni A'));
    await tester.pump();
    expect(find.text('Eklemek istediğin yerleri seç'), findsOneWidget);
  });
  testWidgets('meeting-point picker still returns one place immediately', (
    tester,
  ) async {
    PhotoSpot? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showModalBottomSheet<PhotoSpot>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => RouteStopPicker(
                    city: 'Elazığ',
                    stops: const [],
                    loadItems: (_) async => [spot('Buluşma', 39)],
                  ),
                );
              },
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buluşma'));
    await tester.pumpAndSettle();
    expect(selected?.id, 'Buluşma');
  });
}
