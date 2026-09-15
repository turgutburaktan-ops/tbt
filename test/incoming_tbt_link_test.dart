import 'package:flutter_test/flutter_test.dart';
import 'package:best_photo_spot/services/incoming_tbt_link.dart';

void main() {
  test('WhatsApp event URL and caption open the event', () {
    const url = 'https://www.trtbt.com/event/n0PxET2SeFc1NP9cJkeD';
    expect(incomingTbtLink(url)?.path, '/event/n0PxET2SeFc1NP9cJkeD');
    expect(incomingTbtLink('Yürüyüş etkinliğine göz at.\n$url')?.toString(), url);
  });
  test('posts, places, invitations and old supported links are retained', () {
    for (final url in [
      'https://trtbt.com/post/photo123',
      'https://www.trtbt.com/spot/place123',
      'tbt://event/event123',
      'https://en-iyi-cekim-noktasi.web.app/event/old123',
      'https://www.trtbt.com/#/event/event123',
      'https://www.trtbt.com/davet/explorer/TBT-123',
    ]) {
      expect(incomingTbtLink(url), isNotNull, reason: url);
    }
  });
  test('attached media and external content stay in the import editor', () {
    expect(incomingTbtLink('https://trtbt.com/post/a', hasMedia: true), isNull);
    expect(incomingTbtLink('https://instagram.com/p/a'), isNull);
    expect(incomingTbtLink('Merhaba'), isNull);
  });
  test('spoofed hosts and malformed IDs are not routed', () {
    for (final url in [
      'https://trtbt.com.evil.example/event/a',
      'https://trtbt.com@evil.example/event/a',
      'https://evil.example/?url=https%3A%2F%2Ftrtbt.com%2Fevent%2Fa',
      'https://trtbt.com/event/a%2Fb',
      'https://trtbt.com/event/',
    ]) {
      expect(incomingTbtLink(url), isNull, reason: url);
    }
  });
  test('ambiguous targets stay editable; duplicate target is accepted', () {
    expect(incomingTbtLink('https://trtbt.com/event/a https://trtbt.com/event/b'), isNull);
    expect(incomingTbtLink('https://trtbt.com/event/a tbt://event/a'), isNotNull);
    expect(incomingTbtLink('(https://trtbt.com/event/a).')?.path, '/event/a');
  });
}
