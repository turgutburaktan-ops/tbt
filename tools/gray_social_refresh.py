from pathlib import Path

ROOT = Path('lib')

REPLACEMENTS = {
    '0xFF090D10': '0xFF090A0C',
    '0xFF0D1418': '0xFF0E1012',
    '0xFF0E1519': '0xFF0F1113',
    '0xFF11181D': '0xFF121416',
    '0xFF121A1F': '0xFF15181B',
    '0xFF152128': '0xFF1A1D20',
    '0xFF16B8A6': '0xFFB7BCC2',
    '0xFF4FD1C5': '0xFFD7DADF',
    '0xFF5EEAD4': '0xFF9FA5AC',
    '0xFF22D3EE': '0xFFC5C9CE',
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

    if text != original:
        path.write_text(text, encoding='utf-8')
        changed.append(str(path))

print(f'Graphite gray refresh changed {len(changed)} Dart files.')
for item in changed:
    print(item)
