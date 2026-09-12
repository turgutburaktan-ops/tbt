import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/widgets/categorized_search.dart';
import '../lib/screens/home_discover_screen.dart';

void main() {
  testWidgets('search opens on people with no posts or backend reads', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: HomeDiscoverScreen())));
    expect(find.text('Kişiler'), findsOneWidget);
    expect(find.text('Yerler'), findsOneWidget);
    expect(find.text('Mekânlar'), findsOneWidget);
    expect(find.text('Kişiler içinde aramak için en az 2 karakter yaz.'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only selected category loads and typing survives switches', (tester) async {
    final calls = <(SearchCategory, String)>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CategorizedSearch(
      resultsBuilder: (_, category, query) {
        calls.add((category, query));
        return Text('Sonuç: ${category.label} / $query');
      },
    ))));
    expect(calls, isEmpty);
    await tester.enterText(find.byType(TextField), '  İstanbul  ');
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, isEmpty);
    await tester.pump(const Duration(milliseconds: 200));
    expect(calls.last, (SearchCategory.people, 'İstanbul'));
    for (final category in [SearchCategory.places, SearchCategory.venues, SearchCategory.people]) {
      await tester.tap(find.text(category.label));
      await tester.pump();
      expect(calls.last, (category, 'İstanbul'));
      expect(find.text('Sonuç: ${category.label} / İstanbul'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '  İstanbul  ');
    }
    await tester.tap(find.byTooltip('Temizle'));
    await tester.pump();
    expect(find.textContaining('Sonuç:'), findsNothing);
    expect(find.text('Kişiler içinde aramak için en az 2 karakter yaz.'), findsOneWidget);
  });

  testWidgets('rapid input and tab switch discard pending category search', (tester) async {
    final calls = <(SearchCategory, String)>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CategorizedSearch(
      resultsBuilder: (_, category, query) {
        calls.add((category, query));
        return const SizedBox();
      },
    ))));
    await tester.enterText(find.byType(TextField), 'an');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'ankara');
    await tester.tap(find.text('Yerler'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, isNotEmpty);
    expect(calls.every((call) => call == (SearchCategory.places, 'ankara')), isTrue);
    await tester.enterText(find.byType(TextField), 'yeni');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('three tabs fit side by side on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.4)), child: child!),
      home: Scaffold(body: CategorizedSearch(resultsBuilder: (_, __, ___) => const SizedBox()))));
    final people = tester.getRect(find.text('Kişiler'));
    final places = tester.getRect(find.text('Yerler'));
    final venues = tester.getRect(find.text('Mekânlar'));
    expect(people.top, places.top);
    expect(places.top, venues.top);
    expect(people.right, lessThan(places.left));
    expect(places.right, lessThan(venues.left));
    expect(tester.takeException(), isNull);
  });
}
