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
  static final RegExp _safeId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  Uri communityUri(String communityId) =>
      Uri.https(webHost, '/community/${_safeOutgoingId(communityId)}');

  Uri eventUri(String eventId) =>
      Uri.https(webHost, '/event/${_safeOutgoingId(eventId)}');

  Uri communityAppUri(String communityId) => Uri(
    scheme: scheme,
    host: 'community',
    pathSegments: [_safeOutgoingId(communityId)],
  );

  Uri eventAppUri(String eventId) => Uri(
    scheme: scheme,
    host: 'event',
    pathSegments: [_safeOutgoingId(eventId)],
  );

  String _safeOutgoingId(String value) {
    final id = value.trim();
    if (!_safeId.hasMatch(id)) {
      throw ArgumentError.value(value, 'id', 'Geçersiz paylaşım kimliği');
    }
    return id;
  }

  InviteLinkTarget? parse(Uri uri) {
    final incomingScheme = uri.scheme.toLowerCase();
    final incomingHost = uri.host.toLowerCase();

    if (incomingScheme == scheme) {
      if (uri.pathSegments.length != 1) return null;
      final id = uri.pathSegments.first.trim();
      final type = incomingHost.trim();
      if (!_validTarget(type, id)) return null;
      return InviteLinkTarget(type: type, id: id);
    }

    final isWebInvite =
        incomingScheme == 'https' &&
        (incomingHost == webHost || incomingHost == firebaseHost);
    if (!isWebInvite || uri.pathSegments.length != 2) return null;

    final type = uri.pathSegments[0].trim().toLowerCase();
    final id = uri.pathSegments[1].trim();
    if (!_validTarget(type, id)) return null;
    return InviteLinkTarget(type: type, id: id);
  }

  bool _validTarget(String type, String id) {
    if (type != 'event' && type != 'community') return false;
    return _safeId.hasMatch(id);
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
    final meta = [
      hostName.trim(),
      city.trim(),
    ].where((item) => item.isNotEmpty).join(' • ');
    await Share.share(
      '$eventTitle etkinliğine göz at.${meta.isEmpty ? '' : '\n$meta'}\n${eventUri(eventId)}',
      subject: eventTitle,
    );
  }
}
