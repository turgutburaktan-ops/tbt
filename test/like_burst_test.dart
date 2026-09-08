import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:best_photo_spot/widgets/like_burst.dart';

void main() {
  testWidgets('heart finishes while the like request is still pending', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: LikeBurst(
              onLike: () {
                calls++;
                return pending.future;
              },
              child: const ColoredBox(color: Colors.black),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(LikeBurst));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.byType(LikeBurst));
    await tester.pump(); // Establish the first animation frame.
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 1);
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: find.text('❤️'), matching: find.byType(Opacity)),
          )
          .opacity,
      greaterThan(0),
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: find.text('❤️'), matching: find.byType(Opacity)),
          )
          .opacity,
      0,
    );
    pending.complete();
    await tester.pumpWidget(const SizedBox());
  });
}
