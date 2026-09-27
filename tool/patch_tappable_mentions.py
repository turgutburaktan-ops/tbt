#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def patch(path: str, replacements: list[tuple[str, str]]) -> None:
    p = ROOT / path
    text = p.read_text(encoding='utf-8')
    original = text
    for old, new in replacements:
        if old not in text:
            print(f'WARN missing pattern in {path}: {old[:80]!r}')
            continue
        text = text.replace(old, new, 1)
    if text != original:
        p.write_text(text, encoding='utf-8')
        print(f'patched {path}')


patch('lib/screens/post_detail_screen.dart', [
    (
        "import '../widgets/content_engagement_bar.dart';\n",
        "import '../widgets/content_engagement_bar.dart';\nimport '../widgets/mention_text.dart';\n",
    ),
    (
        "                  Text(\n                    caption,\n                    style: const TextStyle(\n                      color: Colors.white,\n                      height: 1.5,\n                      fontSize: 14.5,\n                    ),\n                  ),",
        "                  MentionText(\n                    text: caption,\n                    style: const TextStyle(\n                      color: Colors.white,\n                      height: 1.5,\n                      fontSize: 14.5,\n                    ),\n                    mentionStyle: const TextStyle(\n                      color: Color(0xFFA78BFA),\n                      height: 1.5,\n                      fontSize: 14.5,\n                      fontWeight: FontWeight.w900,\n                    ),\n                  ),",
    ),
])

patch('lib/widgets/content_engagement_bar.dart', [
    (
        "import '../services/content_engagement_service.dart';\n",
        "import '../services/content_engagement_service.dart';\nimport 'mention_text.dart';\n",
    ),
    (
        "                              subtitle: Text((data['text'] ?? '').toString()),",
        "                              subtitle: MentionText(\n                                text: (data['text'] ?? '').toString(),\n                                style: const TextStyle(color: Colors.white70),\n                                mentionStyle: const TextStyle(\n                                  color: Color(0xFFA78BFA),\n                                  fontWeight: FontWeight.w800,\n                                ),\n                              ),",
    ),
])
