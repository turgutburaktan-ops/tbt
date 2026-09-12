import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/widgets/profile_name_link.dart';
import '../lib/widgets/story_navigation_surface.dart';

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform: name opens exact profile without selecting its row', (tester) async {
      final routes = _Routes();
      var rowTaps = 0;
      var paused = 0;
      var resumed = 0;
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: navigator,
        theme: ThemeData(platform: platform), navigatorObservers: [routes],
        home: Scaffold(body: ListTile(
          title: ProfileNameLink(userId: ' actual-user-id ',
            onOpening: () => paused++, onReturned: () => resumed++,
            child: const Text('Aynı görünen isim')),
          trailing: const Icon(Icons.check_box_outline_blank),
          onTap: () => rowTaps++,
        )),
      ));
      await tester.tap(find.text('Aynı görünen isim'));
      expect(routes.pushed.last.settings.name, '/profile/actual-user-id');
      expect(rowTaps, 0);
      expect(paused, 1);
      // Remove before building the Firebase-backed destination.
      navigator.currentState!.removeRoute(routes.pushed.last);
      await tester.pumpAndSettle();
      expect(resumed, 1);
      await tester.tap(find.byIcon(Icons.check_box_outline_blank));
      expect(rowTaps, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('missing identity never opens an unrelated profile', (tester) async {
    final routes = _Routes();
    await tester.pumpWidget(MaterialApp(navigatorObservers: [routes],
      home: const Scaffold(body: ProfileNameLink(userId: ' ', child: Text('Silinmiş kullanıcı')))));
    await tester.tap(find.text('Silinmiş kullanıcı'));
    expect(routes.pushed.length, 1);
  });

  testWidgets('story name wins taps; background navigation and hold still work', (tester) async {
    final events = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StoryNavigationSurface(
      onPrevious: () => events.add('previous'), onNext: () => events.add('next'),
      onOpenShared: () => events.add('post'), onPause: () => events.add('pause'),
      onResume: () => events.add('resume'),
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: Colors.black),
        Positioned(top: 110, left: 16, child: TextButton(
          onPressed: () => events.add('profile'), child: const Text('Video sahibi'))),
      ]),
    ))));
    await tester.tap(find.text('Video sahibi'));
    expect(events, ['profile']);
    await tester.tapAt(const Offset(20, 300));
    await tester.tapAt(const Offset(400, 300));
    await tester.tapAt(const Offset(780, 300));
    expect(events, ['profile', 'previous', 'post', 'next']);
    await tester.longPressAt(const Offset(400, 300));
    expect(events.sublist(4), ['pause', 'resume']);
  });
}
