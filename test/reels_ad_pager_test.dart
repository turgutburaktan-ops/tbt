import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:best_photo_spot/services/reels_ad_loader.dart';
import 'package:best_photo_spot/widgets/reels_ad_pager.dart';

class FakeAd implements ReelsAdHandle {
  int disposed = 0;
  @override
  Widget view() => const ColoredBox(color: Colors.teal, child: Center(child: Text('TEST AD')));
  @override
  void dispose() { disposed++; }
}

Future<void> showFeed(WidgetTester tester, ReelsAdLoader loader, {List<String>? ids}) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: ReelsAdPager(
    videoIds: ids ?? List.generate(25, (i) => 'v${i+1}'),
    adLoader: loader,
    videoBuilder: (_, index, active) => Center(child: Text('video ${index+1} ${active ? 'playing' : 'paused'}')),
  ))));
  await tester.pumpAndSettle();
}
Future<void> next(WidgetTester tester) async {
  await tester.drag(find.byType(PageView), const Offset(0, -450));
  await tester.pumpAndSettle();
}
Future<void> close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}
void main() {
  setUp(() => VisibilityDetectorController.instance.updateInterval = Duration.zero);
  testWidgets('no fill never allocates empty ad pages or retries every swipe', (tester) async {
    var requests = 0;
    await showFeed(tester, () async { requests++; return null; });
    for (var i = 2; i <= 16; i++) {
      await next(tester);
      expect(find.text('video $i playing'), findsOneWidget);
    }
    expect(requests, 2);
    await close(tester);
  });
  testWidgets('first ad after five videos, next after eight more; past ad is released', (tester) async {
    final ads = <FakeAd>[];
    await showFeed(tester, () async { final ad = FakeAd(); ads.add(ad); return ad; });
    for (var i = 2; i <= 5; i++) { await next(tester); }
    expect(find.text('video 5 playing'), findsOneWidget);
    expect(ads.length, 1);
    await next(tester);
    expect(find.text('TEST AD'), findsOneWidget);
    expect(find.textContaining('playing'), findsNothing);
    await next(tester);
    expect(find.text('video 6 playing'), findsOneWidget);
    expect(ads.first.disposed, 1);
    await tester.drag(find.byType(PageView), const Offset(0, 450));
    await tester.pumpAndSettle();
    expect(find.text('video 5 playing'), findsOneWidget);
    for (var i = 6; i <= 13; i++) { await next(tester); }
    expect(find.text('video 13 playing'), findsOneWidget);
    await next(tester);
    expect(find.text('TEST AD'), findsOneWidget);
    expect(ads.length, 2);
    await close(tester);
    expect(ads.last.disposed, 1);
  });
  testWidgets('late load never inserts behind the current video', (tester) async {
    final pending = Completer<ReelsAdHandle?>();
    final ad = FakeAd();
    await showFeed(tester, () => pending.future);
    for (var i = 2; i <= 7; i++) { await next(tester); }
    pending.complete(ad);
    await tester.pumpAndSettle();
    expect(find.text('video 7 playing'), findsOneWidget);
    for (var i = 8; i <= 13; i++) { await next(tester); }
    await next(tester);
    expect(find.text('TEST AD'), findsOneWidget);
    await close(tester);
    expect(ad.disposed, 1);
  });
  testWidgets('closing during load discards the late ad', (tester) async {
    final pending = Completer<ReelsAdHandle?>();
    final ad = FakeAd();
    await showFeed(tester, () => pending.future);
    await next(tester); await next(tester);
    await close(tester);
    pending.complete(ad);
    await tester.pump();
    expect(ad.disposed, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('feed updates retain the current video instead of shifting it', (tester) async {
    Future<ReelsAdHandle?> empty() async => null;
    await showFeed(tester, empty);
    await next(tester); await next(tester);
    await showFeed(tester, empty, ids: ['new', ...List.generate(25, (i) => 'v${i+1}')]);
    expect(find.text('video 4 playing'), findsOneWidget);
    await close(tester);
  });
  testWidgets('an unused prefetched ad expires without moving the video', (tester) async {
    final ad = FakeAd();
    await showFeed(tester, () async => ad);
    await next(tester); await next(tester);
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    expect(ad.disposed, 1);
    expect(find.text('video 3 playing'), findsOneWidget);
    await close(tester);
    expect(ad.disposed, 1);
  });
  testWidgets('removing all videos releases the pending ad safely', (tester) async {
    final ad = FakeAd();
    Future<ReelsAdHandle?> loader() async => ad;
    await showFeed(tester, loader);
    await next(tester); await next(tester);
    await showFeed(tester, loader, ids: []);
    expect(ad.disposed, 1);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
