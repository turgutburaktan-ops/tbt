import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/widgets/swipe_to_reply.dart';

void main() {
  Future<void> mount(WidgetTester tester, VoidCallback onReply, {bool enabled = true}) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: SwipeToReply(enabled: enabled, onReply: onReply,
        child: const SizedBox(width: 300, height: 100, child: Text('Mesaj'))),
    ))));
  }
  testWidgets('right swipe replies once and keeps the message', (tester) async {
    var replies = 0;
    await mount(tester, () => replies++);
    await tester.drag(find.text('Mesaj'), const Offset(110, 0));
    await tester.pumpAndSettle();
    expect(replies, 1);
    expect(find.text('Mesaj'), findsOneWidget);
    await tester.drag(find.text('Mesaj'), const Offset(110, 0));
    await tester.pumpAndSettle();
    expect(replies, 2);
  });
  testWidgets('left, short and vertical gestures do not reply', (tester) async {
    var replies = 0;
    await mount(tester, () => replies++);
    for (final offset in [const Offset(-110, 0), const Offset(30, 0), const Offset(0, -120)]) {
      await tester.drag(find.text('Mesaj'), offset);
      await tester.pumpAndSettle();
    }
    expect(replies, 0);
  });
  testWidgets('cancelled swipe and disabled reply never send an action', (tester) async {
    var replies = 0;
    await mount(tester, () => replies++);
    final gesture = await tester.startGesture(tester.getCenter(find.text('Mesaj')));
    await gesture.moveBy(const Offset(100, 0));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(replies, 0);
    await mount(tester, () => replies++, enabled: false);
    await tester.drag(find.text('Mesaj'), const Offset(110, 0));
    await tester.pumpAndSettle();
    expect(replies, 0);
  });
}
