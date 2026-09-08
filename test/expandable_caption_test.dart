import 'package:best_photo_spot/widgets/expandable_caption.dart';
import 'package:best_photo_spot/widgets/mention_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  Widget screen(String text, {bool sheet = false}) => MaterialApp(home: Scaffold(body: SizedBox(width: 260, child: ExpandableCaption(text: text, detailsInSheet: sheet))));
  final long = List.generate(12, (i) => 'Açıklama satırı $i').join('\n');
  testWidgets('Long descriptions expand and collapse without losing text', (tester) async {
    await tester.pumpWidget(screen(long));
    expect(tester.widget<MentionText>(find.byType(MentionText)).maxLines, 3);
    await tester.tap(find.text('Devamını gör')); await tester.pump();
    expect(tester.widget<MentionText>(find.byType(MentionText)).maxLines, isNull);
    expect(tester.widget<MentionText>(find.byType(MentionText)).text, long);
    await tester.tap(find.text('Daha az göster')); await tester.pump();
    expect(tester.widget<MentionText>(find.byType(MentionText)).maxLines, 3);
    await tester.pumpWidget(screen('Kısa açıklama'));
    expect(find.text('Devamını gör'), findsNothing);
  });
  testWidgets('Video detail sheet exposes the entire caption', (tester) async {
    await tester.pumpWidget(screen(long, sheet: true));
    await tester.tap(find.text('Devamını gör')); await tester.pumpAndSettle();
    expect(tester.widgetList<MentionText>(find.byType(MentionText)).any((w) => w.maxLines == null && w.text == long), isTrue);
    expect(tester.takeException(), isNull);
  });
}
