import 'package:share_plus/share_plus.dart';

class InviteLinkTarget {
  final String type;
  final String id;

  const InviteLinkTarget({required this.type, required this.id});
}

class InviteLinkService {
  InviteLinkService._();
  static final InviteLinkService instance = InviteLinkService._();

  static const String scheme = 'tbt';
  static const String webHost = 'en-iyi-cekim-noktasi.web.app';
  static const String firebaseHost = 'en-iyi-cekim-noktasi.firebaseapp.com';

  Uri communityUri(String communityId) =>
      Uri.https(webHost, '/community/$communityId');

  Uri eventUri(String eventId) => Uri.https(webHost, '/event/$eventId');

  Uri communityAppUri(String communityId) =>
      Uri(scheme: scheme, host: 'community', pathSegments: [communityId]);

  Uri eventAppUri(String eventId) =>
      Uri(scheme: scheme, host: 'event', pathSegments: [eventId]);

  InviteLinkTarget? parse(Uri uri) {
    if (uri.scheme == scheme) {
      final id = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first.trim();
      final type = uri.host.trim();
      if (id.isEmpty || (type != 'event' && type != 'community')) return null;
      return InviteLinkTarget(type: type, id: id);
    }

    final isWebInvite = uri.scheme == 'https' &&
        (uri.host == webHost || uri.host == firebaseHost);
    if (!isWebInvite || uri.pathSegments.length < 2) return null;

    final type = uri.pathSegments[0].trim();
    final id = uri.pathSegments[1].trim();
    if (id.isEmpty || (type != 'event' && type != 'community')) return null;
    return InviteLinkTarget(type: type, id: id);
  }

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
