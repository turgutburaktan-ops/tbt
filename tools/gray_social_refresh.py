from pathlib import Path

ROOT = Path('lib')

REPLACEMENTS = {
    '0xFF090D10': '0xFF090A0C',
    '0xFF0D1418': '0xFF0E1012',
    '0xFF0E1519': '0xFF0F1113',
    '0xFF0D0A15': '0xFF0F1113',
    '0xFF11181D': '0xFF121416',
    '0xFF121A1F': '0xFF15181B',
    '0xFF152128': '0xFF1A1D20',
    '0xFF16B8A6': '0xFFB7BCC2',
    '0xFF4FD1C5': '0xFFD7DADF',
    '0xFF5EEAD4': '0xFF9FA5AC',
    '0xFF22D3EE': '0xFFC5C9CE',
    '0xFF38C7B7': '0xFF5A6067',
    '0xFF0F8F83': '0xFF3A3F45',
    '0xFF123D3B': '0xFF202428',
    '0xFF75DED4': '0xFFBFC4CA',
    '0xFFB5C0C3': '0xFFB8BDC4',
    '0xFF26383D': '0xFF2A2E33',
    '0x3316B8A6': '0x334B5158',
    '0x3322D3EE': '0x33383D43',
    '0xFF1B1728': '0xFF17191C',
    '0xFF241A3A': '0xFF2A2E33',
}

changed = []
for path in ROOT.rglob('*.dart'):
    lower = str(path).lower()
    if 'camera' in lower or 'iris' in lower:
        continue
    text = path.read_text(encoding='utf-8')
    original = text
    for old, new in REPLACEMENTS.items():
        text = text.replace(old, new)

    if path.name == 'content_engagement_bar.dart':
        text = text.replace('this.showTagAction = true,', 'this.showTagAction = false,')

    if path.name == 'profile_page_v2.dart':
        needle = """                          IconButton(\n                            onPressed: () => _editProfile(displayName, bio),\n                            icon: const Icon(Icons.edit_outlined,\n                                color: Color(0xFFB7BCC2)),\n                          ),\n"""
        insert = """                          IconButton(\n                            tooltip: 'Mesajlar',\n                            onPressed: () => Navigator.pushNamed(context, '/messages'),\n                            icon: const Icon(Icons.chat_bubble_outline_rounded,\n                                color: Colors.white70),\n                          ),\n                          IconButton(\n                            onPressed: () => _editProfile(displayName, bio),\n                            icon: const Icon(Icons.edit_outlined,\n                                color: Colors.white70),\n                          ),\n"""
        if needle in text:
            text = text.replace(needle, insert, 1)

    if path.name == 'library_screen.dart':
        text = text.replace(
            "builder: (_) => const Scaffold(\n            appBar: AppBar(title: Text('Etkinlikler')),\n            body: SocialEventsScreen(),\n          ),",
            "builder: (_) => Scaffold(\n            appBar: AppBar(title: const Text('Etkinlikler')),\n            body: const SocialEventsScreen(),\n          ),",
        )

    if path.name == 'post_detail_screen.dart':
        text = text.replace(
            "import '../widgets/mention_text.dart';\nimport '../widgets/mention_text.dart';",
            "import '../widgets/mention_text.dart';",
        )
        outer = """            padding: const EdgeInsets.all(1.2),\n            decoration: BoxDecoration(\n              gradient: const LinearGradient(\n                begin: Alignment.topLeft,\n                end: Alignment.bottomRight,\n                colors: [\n                  Color(0xFF5A6067),\n                  Color(0xFF3A3F45),\n                  Color(0xFF202428),\n                ],\n              ),\n              borderRadius: BorderRadius.circular(26),\n              boxShadow: const [\n                BoxShadow(\n                  color: Color(0x334B5158),\n                  blurRadius: 24,\n                  spreadRadius: -10,\n                  offset: Offset(0, 10),\n                ),\n              ],\n            ),\n"""
        simpler = """            decoration: BoxDecoration(\n              borderRadius: BorderRadius.circular(22),\n              border: Border.all(color: const Color(0xFF34383D)),\n            ),\n"""
        text = text.replace(outer, simpler)
        text = text.replace('borderRadius: BorderRadius.circular(25),', 'borderRadius: BorderRadius.circular(21),')
        avatar = """                        Container(\n                          width: 38,\n                          height: 38,\n                          decoration: const BoxDecoration(\n                            shape: BoxShape.circle,\n                            gradient: LinearGradient(\n                              colors: [Color(0xFFB7BCC2), Color(0xFF9FA5AC)],\n                            ),\n                          ),\n                          child: const Icon(\n                            Icons.person_outline_rounded,\n                            size: 21,\n                            color: Colors.white,\n                          ),\n                        ),\n"""
        avatar_gray = """                        Container(\n                          width: 38,\n                          height: 38,\n                          decoration: BoxDecoration(\n                            color: const Color(0xFF1A1D20),\n                            shape: BoxShape.circle,\n                            border: Border.all(color: const Color(0xFF454A50)),\n                          ),\n                          child: const Icon(\n                            Icons.person_outline_rounded,\n                            size: 21,\n                            color: Colors.white70,\n                          ),\n                        ),\n"""
        text = text.replace(avatar, avatar_gray)
        sparkle = """                        const Icon(\n                          Icons.auto_awesome_rounded,\n                          size: 17,\n                          color: Color(0xFFB7BCC2),\n                        ),\n"""
        text = text.replace(sparkle, '')

    if text != original:
        path.write_text(text, encoding='utf-8')
        changed.append(str(path))

print(f'Graphite gray refresh changed {len(changed)} Dart files.')
for item in changed:
    print(item)
