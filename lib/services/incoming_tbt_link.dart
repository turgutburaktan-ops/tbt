import 'invite_link_service.dart';

/// Only text-only shares with one unambiguous TBT destination are navigation.
/// Real attachments always remain editable drafts.
Uri? incomingTbtLink(String text, {bool hasMedia = false}) {
  if (hasMedia) return null;
  Uri? result;
  String? destination;
  for (final match in RegExp(r"""(?:https://|tbt://)[^\s<>"']+""", caseSensitive: false).allMatches(text)) {
    final raw = match.group(0)!.replaceFirst(RegExp(r'[.,;!?)\]]+$'), '');
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.userInfo.isNotEmpty) continue;
    final target = InviteLinkService.instance.parse(uri);
    if (target == null) continue;
    final key = '${target.type}/${target.role}/${target.id}';
    if (destination != null && destination != key) return null;
    destination = key;
    result ??= uri;
  }
  return result;
}
