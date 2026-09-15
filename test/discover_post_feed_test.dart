import 'package:best_photo_spot/widgets/discover_post_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget feed(int selected, {int count = 5}) => MaterialApp(
    home: DiscoverPostFeed(
      itemCount: count,
      initialIndex: selected,
      itemBuilder: (_, index) => SizedBox(
        height: 500,
        child: Text('Post $index'),
      ),
    ),
  );

  testWidgets('Tapped tile leads; scrolling reaches later and earlier posts', (tester) async {
    await tester.pumpWidget(feed(3));
    expect(tester.getTopLeft(find.text('Post 3')).dy,
        lessThan(tester.getTopLeft(find.text('Post 4')).dy));
    for (final index in [4, 0, 1, 2]) {
      await tester.scrollUntilVisible(find.text('Post $index'), 250);
      expect(find.text('Post $index'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Single and empty feeds are safe', (tester) async {
    await tester.pumpWidget(feed(0, count: 1));
    expect(find.text('Post 0'), findsOneWidget);
    await tester.pumpWidget(feed(0, count: 0));
    expect(find.text('Gösterilecek paylaşım yok.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
