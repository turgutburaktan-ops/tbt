import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:best_photo_spot/widgets/description_field.dart';
import 'package:best_photo_spot/widgets/profile_photo_card.dart';
import 'package:best_photo_spot/widgets/profile_name_link.dart';

class _Routes extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) { pushes++; }
}

void main() {
  testWidgets('iOS description can dismiss via button, outside touch and Done without losing text', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(theme: ThemeData(platform: TargetPlatform.iOS),
      home: Scaffold(body: Column(children: [
        DescriptionField(controller: controller),
        const SizedBox(height: 150, width: double.infinity, child: Text('Dış alan')),
      ]))));
    final field = find.byType(TextField);
    await tester.enterText(field, 'Harput\nAkşam yürüyüşü');
    await tester.tap(find.text('Bitti'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(controller.text, 'Harput\nAkşam yürüyüşü');
    await tester.tap(field);
    await tester.pump();
    await tester.tap(find.text('Dış alan'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(field);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(controller.text, 'Harput\nAkşam yürüyüşü');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('photo card closes and preserves access to stories', (tester) async {
    var storyOpened = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) =>
      TextButton(onPressed: () => showProfilePhotoCard(context,
        userId: '', photoUrl: '', name: 'Burak', username: 'burak',
        onViewStory: () => storyOpened = true), child: const Text('Fotoğraf'))))));
    await tester.tap(find.text('Fotoğraf'));
    await tester.pumpAndSettle();
    expect(find.text('Burak'), findsOneWidget);
    expect(find.text('@burak'), findsOneWidget);
    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    await tester.tap(find.text('Fotoğraf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hikâyeyi görüntüle'));
    await tester.pumpAndSettle();
    expect(storyOpened, isTrue);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('name touch opens a profile route, including inside a comment sheet', (tester) async {
    final routes = _Routes();
    await tester.pumpWidget(MaterialApp(navigatorObservers: [routes],
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () => showModalBottomSheet<void>(context: context,
          builder: (_) => const Material(child: ProfileNameLink(userId: 'user-123', child: Text('Burak')))),
        child: const Text('Yorumlar'))))));
    await tester.tap(find.text('Yorumlar'));
    await tester.pumpAndSettle();
    final before = routes.pushes;
    expect(tester.getSize(find.byType(ProfileNameLink)).height, greaterThanOrEqualTo(44));
    await tester.tap(find.text('Burak'));
    expect(routes.pushes, before + 1);
    // Route creation is the interaction under test; profile data needs Firebase.
    await tester.pumpWidget(const SizedBox());
  });
}
