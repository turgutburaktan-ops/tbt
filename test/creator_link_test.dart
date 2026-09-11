import 'package:flutter_test/flutter_test.dart';
import 'package:best_photo_spot/services/invite_link_service.dart';

void main() {
  test(
    'Creator welcome links round trip without becoming enrollment links',
    () {
      final links = InviteLinkService.instance;
      final uri = links.creatorProfileUri('creator_123');
      expect(links.parse(uri)?.type, 'creator-profile');
      expect(links.parse(uri)?.id, 'creator_123');
      expect(
        links.parse(Uri.parse('tbt://creator/TBT-AABB1122'))?.type,
        'creator',
      );
      expect(
        links.parse(Uri.parse('https://tbttr.com/creator/TBT-AABB1122'))?.id,
        'TBT-AABB1122',
      );
      expect(
        links.parse(Uri.parse('https://unrelated.example/creator-profile/id')),
        isNull,
      );
      expect(links.parse(Uri.parse('tbt://creator-profile/a/b')), isNull);
      expect(links.parse(Uri.parse('tbt://creator-profile/%2F')), isNull);
      expect(
        links.parse(Uri.parse('https://www.trtbt.com/post/existing'))?.type,
        'post',
      );
      final roleInvite = links.parse(
        Uri.parse(
          'https://www.trtbt.com/davet/gourmet/TBT-GRM-AABB1122',
        ),
      );
      expect(roleInvite?.type, 'role-invite');
      expect(roleInvite?.role, 'gourmet');
      expect(roleInvite?.id, 'TBT-GRM-AABB1122');
      expect(
        links.parse(Uri.parse('tbt://davet/social/TBT-SOS-AABB1122'))?.role,
        'social',
      );
    },
  );
}
