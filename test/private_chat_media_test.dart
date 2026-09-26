import 'package:flutter_test/flutter_test.dart';
import '../lib/services/private_chat_media.dart';
void main() {
  test('only chat namespaces are accepted as private message identifiers', () {
    expect(isPrivateChatPath('users/alice/chat/thread/old.jpg'), isTrue);
    expect(isPrivateChatPath('private_chat/thread/alice/message/media.jpg'), isTrue);
    expect(isPrivateChatPath('private_chat/thread/alice/message/audio.m4a'), isTrue);
    for (final path in ['users/alice/profile/avatar.jpg', 'route_chat/plan/alice/msg/audio.m4a',
      'private_chat/thread/alice/message/extra/media.jpg', 'private_chat/thread/alice/message/script.js']) {
      expect(isPrivateChatPath(path), isFalse);
    }
  });
}
