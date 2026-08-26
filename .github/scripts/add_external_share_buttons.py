from pathlib import Path

# Add native external sharing to the common engagement bar.
p = Path('lib/widgets/content_engagement_bar.dart')
s = p.read_text()
if "import '../services/invite_link_service.dart';" not in s:
    s = s.replace(
        "import '../services/content_engagement_service.dart';\n",
        "import '../services/content_engagement_service.dart';\nimport '../services/invite_link_service.dart';\n",
        1,
    )
if 'Future<void> _shareOutside(BuildContext context)' not in s:
    marker = '  @override\n  Widget build(BuildContext context) {'
    method = '''  Future<void> _shareOutside(BuildContext context) async {
    if (contentId.trim().isEmpty) return;
    try {
      if (sourceType == 'post') {
        await InviteLinkService.instance.sharePost(postId: contentId, title: title);
      } else if (sourceType == 'event') {
        await InviteLinkService.instance.shareEvent(eventId: contentId, eventTitle: title);
      } else {
        _message(context, 'Bu içerik dışarıya paylaşılamıyor.');
      }
    } catch (_) {
      if (context.mounted) _message(context, 'Paylaşım menüsü açılamadı.');
    }
  }

'''
    s = s.replace(marker, method + marker, 1)
old = """        const Spacer(),
        IconButton(
          tooltip: 'Gönder',
"""
new = """        const Spacer(),
        IconButton(
          tooltip: 'WhatsApp veya başka uygulamada paylaş',
          visualDensity: VisualDensity.compact,
          onPressed: contentId.trim().isEmpty ? null : () => _shareOutside(context),
          icon: const Icon(Icons.ios_share_rounded, size: 25),
        ),
        IconButton(
          tooltip: 'TBT içinde gönder',
"""
if old in s:
    s = s.replace(old, new, 1)
p.write_text(s)

# Add native venue sharing to the business profile header.
p = Path('lib/screens/business_profile_screen.dart')
s = p.read_text()
if "package:share_plus/share_plus.dart" not in s:
    s = s.replace("import 'package:flutter/material.dart';\n", "import 'package:flutter/material.dart';\nimport 'package:share_plus/share_plus.dart';\n", 1)
if 'Future<void> _shareVenue() async' not in s:
    marker = '  Future<void> _recordMetric(String metric) async {'
    method = '''  Future<void> _shareVenue() async {
    final maps = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${venue.latitude},${venue.longitude}',
    });
    final address = venue.address.trim();
    await Share.share(
      '${venue.name} mekanına göz at.${address.isEmpty ? '' : '\\n$address'}\\n$maps',
      subject: venue.name,
    );
  }

'''
    s = s.replace(marker, method + marker, 1)
old = """                  title: innerScrolled ? Text(venue.name) : null,
                  flexibleSpace: FlexibleSpaceBar(
"""
new = """                  title: innerScrolled ? Text(venue.name) : null,
                  actions: [
                    IconButton(
                      tooltip: 'Mekanı paylaş',
                      onPressed: _shareVenue,
                      icon: const Icon(Icons.ios_share_rounded),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
"""
if old in s:
    s = s.replace(old, new, 1)
p.write_text(s)
