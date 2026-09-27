import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/widgets/camera_share_controls.dart';

void main() {
  testWidgets('tap and swipe switch modes; recording locks the selector', (
    tester,
  ) async {
    var selected = 1;
    var enabled = true;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Center(
                child: SizedBox(
                  width: 360,
                  child: CameraShareModeSelector(
                    selectedIndex: selected,
                    enabled: enabled,
                    onChanged: (value) => setState(() => selected = value),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    expect(find.text('Story'), findsOneWidget);
    expect(find.text('Gönderi'), findsOneWidget);
    expect(find.text('Reels'), findsOneWidget);
    await tester.tap(find.text('Reels'));
    await tester.pumpAndSettle();
    expect(selected, 2);
    await tester.drag(find.byType(PageView), const Offset(160, 0));
    await tester.pumpAndSettle();
    expect(selected, 1);
    update(() => enabled = false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Story'));
    await tester.drag(find.byType(PageView), const Offset(160, 0));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'gallery has a visible label, survives narrow layout, and locks while busy',
    (tester) async {
      var opened = 0;
      Future<void> render(bool enabled) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 292,
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: CameraGalleryButton(
                          onPressed: enabled ? () => opened++ : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 82, height: 82),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await render(true);
      await tester.tap(find.text('Galeriden seç'));
      expect(opened, 1);
      await render(false);
      await tester.tap(find.text('Galeriden seç'));
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
