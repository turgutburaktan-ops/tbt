from pathlib import Path

path = Path('lib/screens/map_screen.dart')
text = path.read_text(encoding='utf-8')

if "import 'route_planner_screen.dart';" not in text:
    text = text.replace(
        "import 'social_events_screen.dart';",
        "import 'route_planner_screen.dart';\nimport 'social_events_screen.dart';",
        1,
    )

if 'void _openRoutePlanner()' not in text:
    marker = "  void _openEvents() {\n"
    method = """  void _openRoutePlanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RoutePlannerScreen()),
    );
  }

"""
    if marker not in text:
        raise SystemExit('Could not find _openEvents insertion point')
    text = text.replace(marker, method + marker, 1)

route_button = """                        IconButton(
                          tooltip: 'Rota oluştur',
                          onPressed: _openRoutePlanner,
                          icon: const Icon(Icons.route_rounded,
                              color: Colors.white70),
                        ),
"""
refresh_marker = """                        IconButton(
                            onPressed: () {
                              setState(() => _loadingSpots = true);
                              _loadSpots();
                            },
                            icon: const Icon(Icons.refresh,
                                color: Colors.white70)),
"""
if "tooltip: 'Rota oluştur'" not in text:
    if refresh_marker not in text:
        raise SystemExit('Could not find map refresh button insertion point')
    text = text.replace(refresh_marker, route_button + refresh_marker, 1)

path.write_text(text, encoding='utf-8')
print('Route planner wired into Map screen.')
