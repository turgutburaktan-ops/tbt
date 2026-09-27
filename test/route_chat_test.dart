import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/widgets/route_chat_bubble.dart';

void main() {
  testWidgets('reply remains available with large text on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var replies = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.6),
          ),
          child: Scaffold(
            body: ListView(
              children: [
                RouteChatBubble(
                  mine: false,
                  name: 'Uzun katılımcı adı',
                  text: 'Buluşma yerini haritadan seçelim. Fotoğrafları gezi albümüne ekleyebiliriz.',
                  time: '12:30',
                  replyText: 'Ayşe\nNerede buluşuyoruz?',
                  onReply: () => replies++,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.longPress(find.textContaining('Buluşma yerini'));
    expect(replies, 1);
    await tester.drag(
      find.textContaining('Buluşma yerini'),
      const Offset(100, 0),
    );
    await tester.pumpAndSettle();
    expect(replies, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('pending is not presented as delivered', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RouteChatBubble(
            mine: true,
            name: 'Ben',
            text: 'Merhaba',
            time: '12:00',
            pending: true,
            onReply: () {},
          ),
        ),
      ),
    );
    expect(find.text('Gönderiliyor…'), findsOneWidget);
    expect(find.text('12:00'), findsNothing);
  });
}
