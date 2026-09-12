import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/screens/route_create_screen.dart';

void main() {
  testWidgets(
    'route starts with destination duration and company; advanced fields are collapsed',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RouteCreateScreen()));
      expect(find.text('Nereye?'), findsOneWidget);
      expect(find.text('Ne kadar süre?'), findsOneWidget);
      expect(find.text('Kimlerle?'), findsOneWidget);
      expect(find.text('Bütçe'), findsNothing);
      await tester.tap(find.text('Diğer tercihler'));
      await tester.pumpAndSettle();
      expect(find.text('Bütçe'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
