import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/services/profile_record_status.dart';
import '../lib/services/video_audio_session.dart';
import '../lib/widgets/tbt_dialog.dart';

void main() {
  test(
    'expired, used and cancelled coupons leave the active list at the boundary',
    () {
      final now = DateTime(2026, 9, 9);
      final coupon = {
        'status': 'ready',
        'token': 'qr',
        'validUntil': now.add(const Duration(minutes: 1)),
      };
      expect(isActiveCoupon(coupon, now), true);
      for (final status in ['used', 'cancelled', 'expired'])
        expect(isActiveCoupon({...coupon, 'status': status}, now), false);
      expect(isActiveCoupon({...coupon, 'validUntil': now}, now), false);
      expect(isActiveCoupon({...coupon, 'token': ''}, now), false);
    },
  );
  test('past bookings move to history while preparation stays active', () {
    final now = DateTime(2026, 9, 9), past = DateTime(2026, 9, 8);
    expect(isActiveReservation({'status': 'accepted', 'at': past}, now), false);
    expect(
      isActiveReservation({
        'status': 'accepted',
        'at': past,
        'preparationStatus': 'preparing',
      }, now),
      true,
    );
    expect(isActiveReservation({'status': 'cancelled', 'at': now}, now), false);
    expect(
      isActiveReservation({
        'status': 'accepted',
        'at': now,
        'preparationStatus': 'completed',
      }, now),
      false,
    );
    expect(isActiveReservation({'status': 'pending', 'at': now}, now), true);
  });
  test('feed mute notifies all subscribers and stays independent of Reels', () {
    VideoAudioSession.feed.reset();
    VideoAudioSession.reels.reset();
    final observed = <bool>[];
    void first() => observed.add(VideoAudioSession.feed.muted);
    void second() => observed.add(VideoAudioSession.feed.muted);
    VideoAudioSession.feed.addListener(first);
    VideoAudioSession.feed.addListener(second);
    VideoAudioSession.feed.toggle();
    expect(observed, [true, true]);
    expect(VideoAudioSession.reels.muted, false);
    VideoAudioSession.reels.toggle();
    VideoAudioSession.feed.reset();
    expect(observed, [true, true, false, false]);
    expect(VideoAudioSession.reels.muted, true);
    VideoAudioSession.feed.removeListener(first);
    VideoAudioSession.feed.removeListener(second);
    VideoAudioSession.reels.reset();
  });
  testWidgets(
    'long form remains scrollable with keyboard on a narrow display',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTbtDialog<void>(
                  context: context,
                  builder: (sheet) => TbtDialog(
                    title: const Text('Düzenle'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        12,
                        (i) => TextField(
                          decoration: InputDecoration(labelText: 'Alan $i'),
                        ),
                      ),
                    ),
                    actions: [
                      FilledButton(
                        onPressed: () => Navigator.pop(sheet),
                        child: const Text('Kaydet'),
                      ),
                    ],
                  ),
                ),
                child: const Text('Aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Kaydet'), findsOneWidget);
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(find.text('Düzenle'), findsNothing);
    },
  );
}
