from pathlib import Path


def main() -> None:
    path = Path('lib/screens/social_events_screen.dart')
    if not path.exists():
        raise SystemExit('social_events_screen.dart not found')

    text = path.read_text(encoding='utf-8')
    old = """          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Etkinlikler', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            SizedBox(height: 3),
            Text('Keşfet, katıl ve birlikte deneyimle.', style: TextStyle(color: Colors.white60)),
          ])),
"""
    new = """          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Etkinlikler',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Keşfet, katıl ve birlikte deneyimle.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
"""
    if old in text:
        text = text.replace(old, new, 1)
    elif 'textScaler: TextScaler.noScaling' not in text:
        raise SystemExit('social events header anchor not found')

    path.write_text(text, encoding='utf-8')
    print('Social events header fixed against extreme text scaling')


if __name__ == '__main__':
    main()
