import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/screens/business_campaigns_screen.dart';
import '../lib/theme/app_theme.dart';

void main() {
  testWidgets('campaign cannot publish without title and description', (tester) async {
    tester.view.physicalSize = const Size(430, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const BusinessCampaignEditor(venueKey: 'cafe:example', venueName: 'Örnek')));
    await tester.tap(find.text('Ücretsiz yayınla'));
    await tester.pumpAndSettle();
    expect(find.text('En az 3 karakter yaz.'), findsOneWidget);
    expect(find.text('Teklifini açıkla.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('coupon editor keeps site capacity and expiry fields without campaign targeting', (tester) async {
    tester.view.physicalSize = const Size(430, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const BusinessCampaignEditor(venueKey: 'cafe:example', venueName: 'Örnek', coupon: true)));
    expect(find.text('Toplam kupon kontenjanı'), findsOneWidget);
    expect(find.text('Son kullanım tarihi ve saati'), findsOneWidget);
    expect(find.text('Kampanya hedefi'), findsNothing);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'İkinci kahve');
    await tester.enterText(fields.last, '0');
    await tester.tap(find.text('Kuponu yayınla'));
    await tester.pumpAndSettle();
    expect(find.text('1–100000 arasında tam sayı gir.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
