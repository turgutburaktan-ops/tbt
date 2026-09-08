import 'package:flutter_test/flutter_test.dart';
import 'package:best_photo_spot/services/invite_link_service.dart';

void main() {
  test('Group invites resolve without accepting unrelated URLs', () {
    final links = InviteLinkService.instance;
    final target = links.parse(Uri.parse('tbt://group/abc123'));
    expect(target?.type, 'group');
    expect(target?.id, 'abc123');
    expect(links.parse(Uri.parse('https://unrelated.example/group/abc123')), isNull);
    expect(links.parse(Uri.parse('tbt://group/a/b')), isNull);
    expect(links.parse(Uri.parse('tbt://group/%2F')), isNull);
    expect(links.parse(Uri.parse('tbt://event/existing-event'))?.type, 'event');
  });
}
