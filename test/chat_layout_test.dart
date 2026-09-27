import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/widgets/chat_backdrop.dart';
import '../lib/widgets/chat_request_banner.dart';

void main() {
  for (final bottomInset in [24.0, 48.0]) {
    testWidgets('request actions stay tappable above navigation $bottomInset', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final tapped = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: EdgeInsets.only(bottom: bottomInset),
              viewPadding: EdgeInsets.only(bottom: bottomInset),
              textScaler: TextScaler.linear(1.6),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: ChatBackdrop(
              child: Column(
                children: [
                  const Expanded(child: SizedBox.expand()),
                  ChatRequestBanner(
                    incoming: true,
                    onAccept: () => tapped.add('accept'),
                    onReject: () => tapped.add('reject'),
                    onBlock: () => tapped.add('block'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      for (final label in ['Kabul et', 'Reddet', 'Engelle']) {
        final button = find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );
        expect(
          tester.getRect(button).bottom,
          lessThanOrEqualTo(640 - bottomInset),
        );
        await tester.tap(button);
      }
      expect(tapped, ['accept', 'reject', 'block']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('outgoing banner leaves bottom inset to its composer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: 48)),
          child: ChatRequestBanner(
            incoming: false,
            onAccept: () {},
            onReject: () {},
            onBlock: () {},
          ),
        ),
      ),
    );
    expect(find.text('Kabul et'), findsNothing);
    expect(tester.widget<SafeArea>(find.byType(SafeArea)).bottom, isFalse);
  });

  testWidgets('travel pattern paints behind content without blocking taps', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBackdrop(
            color: const Color(0xFF191D24),
            child: Center(
              child: TextButton(
                onPressed: () => tapped = true,
                child: const Text('Mesaj'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ChatTravelPatternPainter,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Mesaj'));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });
}
