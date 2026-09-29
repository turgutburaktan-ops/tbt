import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:best_photo_spot/security/signal_engine.dart';

Future<Map<String, dynamic>> bundle(SignalState state) async {
  final b = await state.publicBundle();
  return {...b, 'preKey': (b['preKeys'] as List).first};
}

void main() {
  test('Signal text, reply and media key survive secure persistence; no plaintext in envelopes', () async {
    final alice = await SignalState.create(), bob = await SignalState.create();
    final a = SignalEngine('alice', alice), b = SignalEngine('bob', bob);
    final content = {
      'text': 'Sadece iki cihaz bilir',
      'replyText': 'Gizli alıntı',
      'mediaUrl': 'tbt-e2ee:secret',
    };
    final packet = await a.encrypt(
      thread: 'dm',
      message: 'one',
      members: ['alice', 'bob'],
      content: content,
      claimBundle: (_, consume) => bundle(bob),
    );
    expect(jsonEncode(packet), isNot(contains(content['text'])));
    expect(
      await b.decrypt(
        thread: 'dm',
        message: 'one',
        sender: 'alice',
        packet: packet,
      ),
      content,
    );
    final restored = SignalEngine(
      'bob',
      SignalState.restore(
        jsonDecode(jsonEncode(bob.serialize())) as Map<String, dynamic>,
      ),
    );
    expect(
      await restored.decrypt(
        thread: 'dm',
        message: 'one',
        sender: 'alice',
        packet: packet,
      ),
      content,
    );
    expect(
      await a.decrypt(
        thread: 'dm',
        message: 'one',
        sender: 'alice',
        packet: packet,
      ),
      content,
    );
    final response = await b.encrypt(
      thread: 'dm',
      message: 'two',
      members: ['alice', 'bob'],
      content: {'text': 'Yanıt'},
      claimBundle: (_, consume) => bundle(alice),
    );
    expect(
      (await a.decrypt(
        thread: 'dm',
        message: 'two',
        sender: 'bob',
        packet: response,
      ))['text'],
      'Yanıt',
    );
  });
  test(
    'tampering, cross-thread replay and wrong recipient cannot decrypt',
    () async {
      final alice = await SignalState.create(),
          bob = await SignalState.create();
      final packet = await SignalEngine('alice', alice).encrypt(
        thread: 'dm',
        message: 'one',
        members: ['alice', 'bob'],
        content: {'text': 'secret'},
        claimBundle: (_, consume) => bundle(bob),
      );
      final original = jsonEncode(bob.serialize());
      await expectLater(
        () => SignalEngine('bob', SignalState.restore(jsonDecode(original)))
            .decrypt(
              thread: 'other',
              message: 'one',
              sender: 'alice',
              packet: packet,
            ),
        throwsA(anything),
      );
      await expectLater(
        () => SignalEngine('mallory', SignalState.restore(jsonDecode(original)))
            .decrypt(
              thread: 'dm',
              message: 'one',
              sender: 'alice',
              packet: packet,
            ),
        throwsA(anything),
      );
      final tampered = jsonDecode(jsonEncode(packet)) as Map<String, dynamic>;
      final raw = base64Decode(tampered['envelopes']['bob']['body'] as String);
      raw[raw.length - 1] ^= 1;
      tampered['envelopes']['bob']['body'] = base64Encode(raw);
      await expectLater(
        () => SignalEngine('bob', SignalState.restore(jsonDecode(original)))
            .decrypt(
              thread: 'dm',
              message: 'one',
              sender: 'alice',
              packet: tampered,
            ),
        throwsA(anything),
      );
    },
  );
  test(
    'outbox retries are identical and pinned identity replacement is rejected',
    () async {
      final alice = await SignalState.create(),
          bob = await SignalState.create();
      final a = SignalEngine('alice', alice);
      Future<Map<String, dynamic>> send(String id, SignalState target) =>
          a.encrypt(
            thread: 'dm',
            message: id,
            members: ['alice', 'bob'],
            content: {'text': 'test'},
            claimBundle: (_, consume) => bundle(target),
          );
      final first = await send('one', bob);
      expect(await send('one', bob), first);
      final impostor = await SignalState.create();
      await expectLater(() => send('two', impostor), throwsA(anything));
    },
  );
  test('group envelopes exclude removed members; canonical cache handles Firestore map order', () async {
    final alice = await SignalState.create(),
        bob = await SignalState.create(),
        carol = await SignalState.create();
    final a = SignalEngine('alice', alice);
    final packet = await a.encrypt(
      thread: 'group',
      message: 'one',
      members: ['carol', 'alice', 'bob'],
      content: {'text': 'group'},
      claimBundle: (p, consume) => bundle(p == 'bob' ? bob : carol),
    );
    for (final entry in {'bob': bob, 'carol': carol}.entries)
      expect(
        (await SignalEngine(entry.key, entry.value).decrypt(
          thread: 'group',
          message: 'one',
          sender: 'alice',
          packet: packet,
        ))['text'],
        'group',
      );
    final reordered = {
      'envelopes': packet['envelopes'],
      'senderId': 'alice',
      'version': 1,
    };
    expect(
      (await SignalEngine('bob', bob).decrypt(
        thread: 'group',
        message: 'one',
        sender: 'alice',
        packet: reordered,
      ))['text'],
      'group',
    );
    final next = await a.encrypt(
      thread: 'group',
      message: 'two',
      members: ['alice', 'bob'],
      content: {'text': 'private'},
      claimBundle: (_, consume) => bundle(bob),
    );
    expect((next['envelopes'] as Map).containsKey('carol'), false);
    await expectLater(
      () => SignalEngine(
        'carol',
        carol,
      ).decrypt(thread: 'group', message: 'two', sender: 'alice', packet: next),
      throwsA(anything),
    );
  });
}
