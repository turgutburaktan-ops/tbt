Uri? externalSourceUrl(String text) {
  for (final match in RegExp(r'https?://[^\s<>]+').allMatches(text)) {
    final uri = Uri.tryParse(match.group(0)!.replaceAll(RegExp(r'[.,;)]+$'), ''));
    if (uri == null || uri.userInfo.isNotEmpty || uri.hasPort) continue;
    final host = uri.host.toLowerCase();
    if (['instagram.com', 'www.instagram.com', 'x.com', 'www.x.com', 'twitter.com', 'www.twitter.com', 'mobile.twitter.com'].contains(host)) {
      return Uri(scheme: 'https', host: host.replaceFirst(RegExp(r'^(www\.|mobile\.)'), '').replaceFirst('twitter.com', 'x.com'), path: uri.path);
    }
  }
  return null;
}

