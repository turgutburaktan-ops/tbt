from pathlib import Path


def main() -> None:
    path = Path('lib/screens/home_screen.dart')
    text = path.read_text()

    if "import 'chat_inbox_screen.dart';" not in text:
        marker = "import 'camera_screen.dart';\n"
        if marker not in text:
            raise SystemExit('camera_screen import marker not found')
        text = text.replace(marker, marker + "import 'chat_inbox_screen.dart';\n", 1)

    text = text.replace(
        "      const _SavedPage(),\n",
        "      const ChatInboxScreen(),\n",
        1,
    )

    text = text.replace(
        """          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Kaydedilenler',
          ),
""",
        """          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Mesajlar',
          ),
""",
        1,
    )

    path.write_text(text)
    print('Bottom navigation patched: Kaydedilenler -> Mesajlar')


if __name__ == '__main__':
    main()
