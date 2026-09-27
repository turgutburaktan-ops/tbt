import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:best_photo_spot/services/chat_notification_identity.dart';
import 'package:best_photo_spot/widgets/discover_post_feed.dart';
import 'package:best_photo_spot/widgets/profile_photo_viewer.dart';

void main() {
  test('messages from a conversation replace the same account-scoped card', () {
    final first = {'recipientId': 'me', 'sourceId': 'group', 'notificationId': '1', 'actorId': 'alice'};
    expect(chatNotificationIdentity(first), chatNotificationIdentity({...first, 'notificationId': '2', 'actorId': 'bob'}));
    expect(chatNotificationIdentity(first), isNot(chatNotificationIdentity({...first, 'sourceId': 'other'})));
    expect(chatNotificationIdentity(first), isNot(chatNotificationIdentity({...first, 'recipientId': 'other'})));
  });
  test('missing conversation identifiers do not collapse unrelated messages', () {
    expect(chatNotificationIdentity({'notificationId': '1'}), isNot(chatNotificationIdentity({'notificationId': '2'})));
  });
  testWidgets('profile feed starts at selected post and scrolls to another', (tester) async {
    await tester.pumpWidget(MaterialApp(home: DiscoverPostFeed(
      title: 'Gönderiler', itemCount: 3, initialIndex: 1,
      itemBuilder: (_, index) => SizedBox(height: 700, child: Text('post-$index')),
    )));
    expect(find.text('Gönderiler'), findsOneWidget);
    expect(find.text('post-1'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.text('post-2'), findsOneWidget);
  });
  testWidgets('profile photo double tap zooms and resets', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfilePhotoViewer(name: 'TBT', child: ColoredBox(color: Colors.blue))));
    final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final point = tester.getCenter(find.byType(InteractiveViewer));
    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(point);
    await tester.pumpAndSettle();
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 3);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(point);
    await tester.pumpAndSettle();
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
  });
}
