import 'package:flutter_test/flutter_test.dart';
import '../lib/services/invite_link_service.dart';
void main() {
  final links=InviteLinkService.instance;
  test('route sharing round trips through verified web and app links', () {
    expect(links.parse(links.routeUri('route_123'))!.id,'route_123');
    expect(links.parse(Uri.parse('tbt://route/route_123'))!.type,'route');
    expect(links.parse(Uri.parse('https://evil.example/route/route_123')),isNull);
    expect(links.parse(Uri.parse('https://www.trtbt.com/route/a/b')),isNull);
  });
}
