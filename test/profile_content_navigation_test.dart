import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/widgets/profile_content_navigation.dart';
import '../lib/theme/app_theme.dart';

void main() {
  testWidgets(
    'profile content tabs remain reachable on a narrow phone and journey opens once',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = 'all';
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => Column(
                children: [
                  ProfileJourneyRow(points: 12, onTap: () => opened++),
                  ProfileContentNavigation(
                    selected: selected,
                    onChanged: (value) => update(() => selected = value),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('TBT Yolculuğu'), findsOneWidget);
      expect(find.text('Yolculuğum'), findsNothing);
      await tester.tap(find.text('TBT Yolculuğu'));
      expect(opened, 1);
      await tester.ensureVisible(find.text('Favoriler'));
      await tester.tap(find.text('Favoriler'));
      await tester.pumpAndSettle();
      expect(selected, 'favorites');
      expect(tester.takeException(), isNull);
    },
  );
}
