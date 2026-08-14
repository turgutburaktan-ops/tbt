from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Camera/Iris implementation files are deliberately excluded.
EXCLUDED_NAMES = {'camera_screen.dart'}

def excluded(path: Path) -> bool:
    n = path.name.lower()
    return n in EXCLUDED_NAMES or 'iris' in n or 'camera' in n

replacements = {
    '0xFF090812': '0xFF090D10',
    '0xFF141126': '0xFF11181D',
    '0xFF1C1733': '0xFF152128',
    '0xFF1C1630': '0xFF152128',
    '0xFF0F0B1A': '0xFF0D1418',
    '0xFF171126': '0xFF121A1F',
    '0xFF11151C': '0xFF0E1519',
    '0xFF8B5CF6': '0xFF16B8A6',
    '0xFFA78BFA': '0xFF4FD1C5',
    '0xFFC084FC': '0xFF5EEAD4',
    '0xFF9F7AEA': '0xFF38C7B7',
    '0xFF6D28D9': '0xFF0F8F83',
    '0xFF3B1B68': '0xFF123D3B',
    '0xFF352A55': '0xFF26383D',
    '0xFFAAA1C2': '0xFFA7B4B8',
    '0xFFC4B5FD': '0xFF75DED4',
    '0xFFB9B1C8': '0xFFB5C0C3',
    '0xFFE879F9': '0xFFFF5D7A',
    '0x338B5CF6': '0x3316B8A6',
    '0x888B5CF6': '0x8816B8A6',
}

for base in [ROOT / 'lib' / 'screens', ROOT / 'lib' / 'widgets', ROOT / 'lib' / 'theme']:
    for path in base.rglob('*.dart'):
        if excluded(path):
            continue
        text = path.read_text(encoding='utf-8')
        original = text
        for old, new in replacements.items():
            text = text.replace(old, new)
        if text != original:
            path.write_text(text, encoding='utf-8')

# Keep the center camera FAB fixed when keyboard appears. The login form itself
# remains scrollable and gets keyboard-aware bottom padding below.
home = ROOT / 'lib/screens/home_shell_screen.dart'
text = home.read_text(encoding='utf-8')
needle = "    return Scaffold(\n      backgroundColor: const Color(0xFF090D10),"
if needle in text and 'resizeToAvoidBottomInset: false' not in text:
    text = text.replace(needle, "    return Scaffold(\n      resizeToAvoidBottomInset: false,\n      backgroundColor: const Color(0xFF090D10),", 1)
home.write_text(text, encoding='utf-8')

login = ROOT / 'lib/screens/login_screen.dart'
text = login.read_text(encoding='utf-8')
text = text.replace(
    "        padding: const EdgeInsets.all(24),",
    "        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),",
)
login.write_text(text, encoding='utf-8')

# Compact social actions: icon-first layout, like count is small and no large
# 'Beğen' text button. Tag action remains only where callers explicitly enable it.
eng = ROOT / 'lib/widgets/content_engagement_bar.dart'
text = eng.read_text(encoding='utf-8')
start = text.index('  @override\n  Widget build(BuildContext context) {')
end = text.rfind('\n  }\n}')
new_build = r'''  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF16B8A6);
    const likedColor = Color(0xFFFF5D7A);
    return Row(
      children: [
        StreamBuilder<bool>(
          stream: ContentEngagementService.instance.isLiked(collection, contentId),
          builder: (_, likedSnapshot) => StreamBuilder<int>(
            stream: ContentEngagementService.instance.likesCount(collection, contentId),
            builder: (_, countSnapshot) {
              final liked = likedSnapshot.data ?? false;
              final count = countSnapshot.data ?? 0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: liked ? 'Beğeniyi kaldır' : 'Beğen',
                    visualDensity: VisualDensity.compact,
                    onPressed: contentId.trim().isEmpty ? null : () async {
                      try {
                        await ContentEngagementService.instance.toggleLike(
                          collection: collection,
                          id: contentId,
                          ownerId: ownerId,
                          title: title,
                          sourceType: sourceType,
                        );
                      } catch (e) {
                        if (context.mounted) {
                          _message(context, e.toString().replaceFirst('Exception: ', ''));
                        }
                      }
                    },
                    icon: Icon(
                      liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: liked ? likedColor : Colors.white,
                      size: 27,
                    ),
                  ),
                  if (count > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                ],
              );
            },
          ),
        ),
        IconButton(
          tooltip: 'Yorumlar',
          visualDensity: VisualDensity.compact,
          onPressed: contentId.trim().isEmpty ? null : () => _comments(context),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 25),
        ),
        if (showTagAction)
          IconButton(
            tooltip: 'Etiketle',
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              final user = await _pickUser(context, 'Birini etiketle');
              if (user == null || !context.mounted) return;
              try {
                await ContentEngagementService.instance.tagUser(
                  collection: collection,
                  id: contentId,
                  userId: user['id'] ?? '',
                  userName: user['name'] ?? 'Kullanıcı',
                  title: title,
                  sourceType: sourceType,
                );
                if (context.mounted) _message(context, '${user['name']} etiketlendi.');
              } catch (e) {
                if (context.mounted) _message(context, e.toString().replaceFirst('Exception: ', ''));
              }
            },
            icon: const Icon(Icons.alternate_email_rounded, size: 25, color: accent),
          ),
        const Spacer(),
        IconButton(
          tooltip: 'Gönder',
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            final user = await _pickUser(context, 'Kime göndermek istiyorsun?');
            if (user == null || !context.mounted) return;
            try {
              await ContentEngagementService.instance.shareToUser(
                targetUserId: user['id'] ?? '',
                sourceType: sourceType,
                sourceId: contentId,
                title: title,
              );
              if (context.mounted) _message(context, '${user['name']} kullanıcısına gönderildi.');
            } catch (e) {
              if (context.mounted) _message(context, e.toString().replaceFirst('Exception: ', ''));
            }
          },
          icon: const Icon(Icons.send_outlined, size: 26),
        ),
      ],
    );
  }'''
text = text[:start] + new_build + text[end + len('\n  }'):]
eng.write_text(text, encoding='utf-8')

# More resilient Commons search for spots without a packaged photo: try several
# Turkish/English queries and allow more time instead of immediately falling back.
svc = ROOT / 'lib/services/spot_image_search_service.dart'
text = svc.read_text(encoding='utf-8')
text = text.replace("      final query = '${spot.name} ${spot.city} Türkiye Turkey';\n      final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {",
'''      final queries = <String>[
        '${spot.name} ${spot.city}',
        '${spot.name} Türkiye',
        '${spot.name} Turkey',
      ];
      for (final query in queries) {
      final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {''')
text = text.replace("      ).timeout(const Duration(seconds: 4));", "      ).timeout(const Duration(seconds: 8));")
text = text.replace("      if (response.statusCode != 200) {\n        _cache[key] = null;\n        return null;\n      }", "      if (response.statusCode != 200) continue;")
text = text.replace("      if (decoded is! Map<String, dynamic>) {\n        _cache[key] = null;\n        return null;\n      }", "      if (decoded is! Map<String, dynamic>) continue;")
text = text.replace("      if (queryData is! Map<String, dynamic>) {\n        _cache[key] = null;\n        return null;\n      }", "      if (queryData is! Map<String, dynamic>) continue;")
text = text.replace("      if (pages is! List || pages.isEmpty) {\n        _cache[key] = null;\n        return null;\n      }", "      if (pages is! List || pages.isEmpty) continue;")
marker = "          return thumbUrl;\n        }\n      }\n\n      _cache[key] = null;"
text = text.replace(marker, "          return thumbUrl;\n        }\n      }\n      }\n\n      _cache[key] = null;")
svc.write_text(text, encoding='utf-8')

print('Applied teal/antracite refresh without touching camera/Iris implementation files.')
