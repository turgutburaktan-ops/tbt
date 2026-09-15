import 'package:flutter_test/flutter_test.dart';

import '../lib/services/invite_link_service.dart';

void main() {
  test('direct, fallback and old SPA links preserve role and code', () {
    final links = InviteLinkService.instance;
    for (final value in [
      'https://www.trtbt.com/davet/creator/TBT-CRT-ABCDEF12',
      'https://trtbt.com/invite.html#%2Fdavet%2Fcreator%2FTBT-CRT-ABCDEF12',
      'https://trtbt.com/#/davet/creator/TBT-CRT-ABCDEF12',
      'tbt://davet/creator/TBT-CRT-ABCDEF12',
    ]) {
      final target = links.parse(Uri.parse(value));
      expect(target?.type, 'role-invite');
      expect(target?.role, 'creator');
      expect(target?.id, 'TBT-CRT-ABCDEF12');
    }
    for (final value in [
      'https://evil.example/#/creator/TBT-ABCDEF12',
      'https://trtbt.com/invite.html#https://evil.example/creator/code',
      'https://trtbt.com/#//evil.example/creator/code',
      'https://trtbt.com/#%ZZ',
    ]) {
      expect(links.parse(Uri.parse(value)), isNull);
    }
  });
}
