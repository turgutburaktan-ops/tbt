import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:best_photo_spot/screens/app_onboarding_screen.dart';
import 'package:best_photo_spot/widgets/searchable_selection_field.dart';

void main() {
  testWidgets('onboarding city field suggests and selects Turkish provinces', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppOnboardingScreen()),
    );

    final picker = find.byType(SearchableSelectionField);
    final field = find.descendant(
      of: picker,
      matching: find.byType(TextField),
    );
    expect(picker, findsOneWidget);

    await tester.tap(field);
    await tester.enterText(field, 'ela');
    await tester.pumpAndSettle();

    expect(find.text('Elazığ'), findsOneWidget);
    await tester.tap(find.text('Elazığ'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(field).controller?.text, 'Elazığ');
  });
}
