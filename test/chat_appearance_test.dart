import 'dart:async';

import 'package:best_photo_spot/services/chat_appearance_service.dart';
import 'package:best_photo_spot/widgets/chat_background_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('New, unknown and malformed preferences use black', () async {
    SharedPreferences.setMockInitialValues({
      'chat_background_v1_unknown': 'removed-color',
      'chat_background_v1_malformed': 42,
    });
    final service = ChatAppearanceService();
    addTearDown(service.dispose);
    for (final id in ['new', 'unknown', 'malformed']) {
      await service.loadForUser(id);
      expect(service.background, ChatBackground.black);
    }
  });

  test('Selection survives recreation and remains isolated per account', () async {
    final first = ChatAppearanceService();
    final second = ChatAppearanceService();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await first.loadForUser('alice');
    await first.select(ChatBackground.forest);
    await second.loadForUser('alice');
    expect(second.background, ChatBackground.forest);
    await second.loadForUser('bob');
    expect(second.background, ChatBackground.black);
    await second.select(ChatBackground.purple);
    await second.loadForUser(null);
    expect(second.background, ChatBackground.black);
    await second.loadForUser('alice');
    expect(second.background, ChatBackground.forest);
  });

  test('An old account load cannot overwrite the active account', () async {
    SharedPreferences.setMockInitialValues({
      'chat_background_v1_alice': 'forest',
      'chat_background_v1_bob': 'purple',
    });
    final oldLoad = Completer<SharedPreferences>();
    final newLoad = Completer<SharedPreferences>();
    var calls = 0;
    final service = ChatAppearanceService(preferences: () => calls++ == 0 ? oldLoad.future : newLoad.future);
    addTearDown(service.dispose);
    final alice = service.loadForUser('alice');
    final bob = service.loadForUser('bob');
    final prefs = await SharedPreferences.getInstance();
    newLoad.complete(prefs);
    await bob;
    oldLoad.complete(prefs);
    await alice;
    expect(service.background, ChatBackground.purple);
  });

  test('Storage errors leave messaging available with the default', () async {
    final service = ChatAppearanceService(preferences: () async => throw StateError('Unavailable'));
    addTearDown(service.dispose);
    await service.loadForUser('alice');
    expect(service.background, ChatBackground.black);
    await expectLater(service.select(ChatBackground.forest), throwsStateError);
    expect(service.background, ChatBackground.black);
  });

  testWidgets('Preview can be cancelled and saved on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = ChatAppearanceService();
    addTearDown(service.dispose);
    await service.loadForUser('alice');
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Builder(builder: (context) => Scaffold(body: Center(child: TextButton(
        onPressed: () => showModalBottomSheet<ChatBackground>(
          context: context, isScrollControlled: true, useSafeArea: true,
          builder: (_) => ChatBackgroundPicker(service: service),
        ),
        child: const Text('Open'),
      )))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Koyu yeşil'));
    await tester.tap(find.text('Koyu yeşil'));
    await tester.pump();
    expect(service.background, ChatBackground.black);
    await tester.ensureVisible(find.text('Vazgeç'));
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(service.background, ChatBackground.black);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Koyu yeşil'));
    await tester.tap(find.text('Koyu yeşil'));
    await tester.pump();
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(service.background, ChatBackground.forest);
    expect(tester.takeException(), isNull);
  });
}
