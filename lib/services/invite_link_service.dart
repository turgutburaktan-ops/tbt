import 'package:share_plus/share_plus.dart';

class InviteLinkService {
  InviteLinkService._();
  static final InviteLinkService instance = InviteLinkService._();

  static const String scheme = 'tbt';

  Uri communityUri(String communityId) =>
      Uri(scheme: scheme, host: 'community', pathSegments: [communityId]);

  Uri eventUri(String eventId) =>
      Uri(scheme: scheme, host: 'event', pathSegments: [eventId]);

  Future<void> shareCommunity({
    required String communityId,
    required String communityName,
    String university = '',
  }) async {
    final details = university.trim().isEmpty ? '' : '\n$university';
    await Share.share(
      '$communityName topluluğuna göz at.$details\n${communityUri(communityId)}',
      subject: communityName,
    );
  }

  Future<void> shareEvent({
    required String eventId,
    required String eventTitle,
    String hostName = '',
    String city = '',
  }) async {
    final meta = [hostName.trim(), city.trim()]
        .where((item) => item.isNotEmpty)
        .join(' • ');
    await Share.share(
      '$eventTitle etkinliğine göz at.${meta.isEmpty ? '' : '\n$meta'}\n${eventUri(eventId)}',
      subject: eventTitle,
    );
  }
}
