from pathlib import Path


def add_once(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    s = p.read_text()
    if new in s:
        return
    if old not in s:
        raise SystemExit(f'Missing patch target: {label}')
    p.write_text(s.replace(old, new, 1))


# New place suggestion: GoogleMap sits inside a ListView. Claim gestures eagerly so
# one-finger pan and two-finger zoom are handled by the map instead of the parent list.
add_once(
    'lib/screens/spot_suggestion_screen.dart',
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/foundation.dart';\nimport 'package:flutter/gestures.dart';\nimport 'package:flutter/material.dart';\n",
    'spot map gesture imports',
)
add_once(
    'lib/screens/spot_suggestion_screen.dart',
    "              onMapCreated: (c) => _mapController = c,\n",
    "              onMapCreated: (c) => _mapController = c,\n              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{\n                Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),\n              },\n",
    'spot map eager gestures',
)

# Own profile: allow user to choose and publish three favorite places.
add_once(
    'lib/screens/profile_page_v2.dart',
    "import '../widgets/firebase_media_image.dart';\n",
    "import '../widgets/firebase_media_image.dart';\nimport '../widgets/profile_favorite_places_section.dart';\n",
    'own profile favorites import',
)
add_once(
    'lib/screens/profile_page_v2.dart',
    "                  SliverToBoxAdapter(child: _typeModule(type)),\n                  SliverToBoxAdapter(child: _contentTabs()),\n",
    "                  SliverToBoxAdapter(child: _typeModule(type)),\n                  SliverToBoxAdapter(\n                    child: ProfileFavoritePlacesSection(\n                      userId: widget.user.uid,\n                      editable: true,\n                    ),\n                  ),\n                  SliverToBoxAdapter(child: _contentTabs()),\n",
    'own profile favorites section',
)

# Visitor profile: favorites are public profile information. Empty favorites stay hidden.
add_once(
    'lib/screens/user_profile_screen.dart',
    "import '../widgets/firebase_media_image.dart';\n",
    "import '../widgets/firebase_media_image.dart';\nimport '../widgets/profile_favorite_places_section.dart';\n",
    'visitor profile favorites import',
)
add_once(
    'lib/screens/user_profile_screen.dart',
    "                  const SliverToBoxAdapter(\n                    child: Divider(height: 1, color: Color(0xFF2A2E33)),\n                  ),\n",
    "                  SliverToBoxAdapter(\n                    child: ProfileFavoritePlacesSection(\n                      userId: userId,\n                      editable: isOwnProfile,\n                    ),\n                  ),\n                  const SliverToBoxAdapter(\n                    child: Divider(height: 1, color: Color(0xFF2A2E33)),\n                  ),\n",
    'visitor profile favorites section',
)
