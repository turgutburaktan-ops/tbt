import 'package:best_photo_spot/widgets/discover_content_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget screen(int count) => MaterialApp(
    home: Scaffold(
      body: DiscoverContentGrid(
        itemCount: count,
        itemBuilder: (_, index) => Text('Post $index'),
        sponsoredCard: const SizedBox(
          height: 150,
          child: Text('Sponsorlu test kartı'),
        ),
      ),
    ),
  );

  testWidgets('Fewer than twelve posts never show an ad', (tester) async {
    for (final count in [0, 1, 11]) {
      await tester.pumpWidget(screen(count));
      expect(find.text('Sponsorlu test kartı'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Ad follows twelve posts and scrolls with the grid', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(screen(25));
    final ad = find.text('Sponsorlu test kartı');
    final initialY = tester.getTopLeft(ad).dy;
    expect(initialY, greaterThanOrEqualTo(tester.getBottomLeft(find.text('Post 11')).dy));
    expect(tester.getTopLeft(find.text('Post 12')).dy, greaterThan(initialY));
    expect(ad, findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(ad).dy, lessThan(initialY));
    await tester.scrollUntilVisible(find.text('Post 24'), 250);
    expect(find.text('Post 24'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
