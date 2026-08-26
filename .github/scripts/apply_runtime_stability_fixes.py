from pathlib import Path
import re


def replace_once(path: str, old: str, new: str, label: str, marker: str | None = None) -> None:
    p = Path(path)
    text = p.read_text()
    if (marker and marker in text) or new in text:
        return
    if old not in text:
        raise SystemExit(f"Missing patch target: {label}")
    p.write_text(text.replace(old, new, 1))


# 1) Visitor posts at a venue are ordinary user posts, not official business posts.
replace_once(
    'lib/services/post_service.dart',
    """      'businessVenueKey': businessVenueKey,
      'businessVenueName': businessVenueName,
      'createdAt': FieldValue.serverTimestamp(),""",
    """      'businessVenueKey': businessVenueKey,
      'businessVenueName': businessVenueName,
      // Visitor check-ins may reference a venue but must never impersonate the
      // verified business account. Official business publishing is separately
      // protected by Firestore ownership checks.
      'businessOfficial': false,
      // Keep the legacy field used by business profile queries in sync.
      'venueKey': businessVenueKey,
      'createdAt': FieldValue.serverTimestamp(),""",
    'post venue metadata',
    marker="'businessOfficial': false",
)

replace_once(
    'lib/screens/create_post_screen.dart',
    """          widget.businessVenueName.isEmpty
              ? 'Paylaş'
              : '${widget.businessVenueName} adına paylaş',""",
    """          widget.businessVenueName.isEmpty
              ? 'Paylaş'
              : '${widget.businessVenueName} • Paylaş',""",
    'visitor post title',
    marker="${widget.businessVenueName} • Paylaş",
)

# 2) Firestore: allow a signed-in visitor to tag a venue. Only an explicit
# official business post requires a verified venue owned by the caller.
p = Path('firestore.rules')
s = p.read_text()
old_rule = """    function validBusinessPost() {
      let key = request.resource.data.get('businessVenueKey', '');
      return key == '' || (
        exists(/databases/$(database)/documents/business_venues/$(key)) &&
        get(/databases/$(database)/documents/business_venues/$(key)).data.verified == true &&
        get(/databases/$(database)/documents/business_venues/$(key)).data.ownerUid == request.auth.uid
      );
    }"""
new_rule = """    function validBusinessPost() {
      let key = request.resource.data.get('businessVenueKey', '');
      let name = request.resource.data.get('businessVenueName', '');
      let official = request.resource.data.get('businessOfficial', false);
      return key == '' || (
        key is string && key.size() <= 240 &&
        name is string && name.size() <= 160 &&
        official is bool &&
        (!official || (
          exists(/databases/$(database)/documents/business_venues/$(key)) &&
          get(/databases/$(database)/documents/business_venues/$(key)).data.verified == true &&
          get(/databases/$(database)/documents/business_venues/$(key)).data.ownerUid == request.auth.uid
        ))
      );
    }"""
if "request.resource.data.get('businessOfficial', false)" not in s:
    if old_rule not in s:
        raise SystemExit('Missing patch target: validBusinessPost')
    p.write_text(s.replace(old_rule, new_rule, 1))

# 3) Favorite shooting places must use the same nationwide catalogue that the
# Mekanlar screen actually displays, instead of relying on a sparse Firestore
# status query only.
p = Path('lib/widgets/profile_favorite_places_section.dart')
s = p.read_text()
imports = """import '../data/curated_photo_spots.dart';
import '../data/curated_photo_spots_cities.dart';
import '../data/curated_photo_spots_extra.dart';
import '../data/curated_photo_spots_official_bulk.dart';
import '../data/curated_photo_spots_official_complete.dart';
import '../data/curated_photo_spots_official_routes.dart';
import '../data/curated_photo_spots_regions.dart';
import '../data/curated_photo_spots_verified_expansion.dart';
import '../models/photo_spot.dart';
import '../services/nationwide_candidate_spot_resolver.dart';
"""
if "import '../data/curated_photo_spots.dart';" not in s:
    s = s.replace("import 'package:flutter/material.dart';\n", "import 'package:flutter/material.dart';\n\n" + imports, 1)
old_spot_load = """    if (widget.type.key == 'spot') {
      final snap = await FirebaseFirestore.instance
          .collection('photo_spots')
          .where('status', isEqualTo: 'published')
          .limit(500)
          .get();
      return snap.docs.map((doc) {
        final d = doc.data();
        return _PlaceChoice(
          id: doc.id,
          name: (d['name'] ?? 'Gezilecek yer').toString(),
          subtitle: (d['city'] ?? d['district'] ?? '').toString(),
        );
      }).toList()..sort((a, b) => a.name.compareTo(b.name));
    }"""
new_spot_load = """    if (widget.type.key == 'spot') {
      final byId = <String, PhotoSpot>{};
      for (final group in <List<PhotoSpot>>[
        demoSpots,
        curatedPhotoSpots,
        curatedPhotoSpotsExtra,
        curatedPhotoSpotsCities,
        curatedPhotoSpotsRegions,
        curatedPhotoSpotsOfficialRoutes,
        curatedPhotoSpotsOfficialBulk,
        curatedPhotoSpotsVerifiedExpansion,
        curatedPhotoSpotsOfficialComplete,
      ]) {
        for (final spot in group) {
          byId[spot.id] = spot;
        }
      }
      final spots = NationwideCandidateSpotResolver.mergeInto(byId.values.toList());
      return spots
          .map(
            (spot) => _PlaceChoice(
              id: spot.id,
              name: spot.name,
              subtitle: spot.city,
            ),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    }"""
if 'NationwideCandidateSpotResolver.mergeInto' not in s:
    if old_spot_load not in s:
        raise SystemExit('Missing patch target: favorite spot catalogue')
    s = s.replace(old_spot_load, new_spot_load, 1)
p.write_text(s)

# 4) Guest home must expose Discover just like the signed-in home.
p = Path('lib/screens/guest_home_screen.dart')
s = p.read_text()
if "import 'home_discover_screen.dart';" not in s:
    s = s.replace("import 'camera_screen.dart';\n", "import 'camera_screen.dart';\nimport 'home_discover_screen.dart';\n", 1)
old_method = """  Future<void> _openLogin(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
"""
new_method = old_method + """
  Future<void> _openDiscover(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('Keşfet')),
          body: const HomeDiscoverScreen(),
        ),
      ),
    );
  }
"""
if 'Future<void> _openDiscover' not in s:
    if old_method not in s:
        raise SystemExit('Missing patch target: guest discover method')
    s = s.replace(old_method, new_method, 1)
old_login_button = """                TextButton(
                  onPressed: () => _openLogin(context),
                  child: const Text('Giriş yap'),
                ),"""
new_login_button = """                TextButton.icon(
                  onPressed: () => _openDiscover(context),
                  icon: const Icon(Icons.explore_outlined, size: 18),
                  label: const Text('Keşfet'),
                ),
                TextButton(
                  onPressed: () => _openLogin(context),
                  child: const Text('Giriş yap'),
                ),"""
if "label: const Text('Keşfet')" not in s:
    if old_login_button not in s:
        raise SystemExit('Missing patch target: guest header')
    s = s.replace(old_login_button, new_login_button, 1)
p.write_text(s)

# 5) Mekanlar had two independent city selectors. The parent selector rebuilt
# the child while its dialog route was being disposed, which can trigger the
# Flutter _dependents assertion. Keep only NearbyPlacesView's lifecycle-safe
# city selector.
p = Path('lib/screens/home_shell_v3.dart')
s = p.read_text()
s = s.replace("import '../services/city_location_service.dart';\n", '')
s = s.replace("  String _cityLabel = 'Konumum';\n  bool _cityLoading = false;\n\n", '', 1)
s = re.sub(
    r"\n  Future<void> _pickCity\(\) async \{.*?\n  \}\n\n  @override\n  Widget build",
    "\n  @override\n  Widget build",
    s,
    count=1,
    flags=re.S,
)
s = re.sub(
    r"\n            if \(_category != 'Gezilecek Yerler'\)\n              Padding\(.*?\n              \),\n            Expanded\(child: content\),",
    "\n            Expanded(child: content),",
    s,
    count=1,
    flags=re.S,
)
p.write_text(s)

# 6) Earlier UI patchers can accidentally insert the same GoogleMap named
# argument more than once. Remove every gestureRecognizers block after the
# first one, regardless of whitespace/formatting.
p = Path('lib/screens/spot_suggestion_screen.dart')
s = p.read_text()
pattern = re.compile(
    r"\n\s*gestureRecognizers:\s*<Factory<OneSequenceGestureRecognizer>>\s*\{\s*"
    r"Factory<OneSequenceGestureRecognizer>\s*\(\s*"
    r"\(\)\s*=>\s*EagerGestureRecognizer\(\)\s*,?\s*\)\s*,?\s*\}\s*,?",
    re.S,
)
matches = list(pattern.finditer(s))
if len(matches) > 1:
    for match in reversed(matches[1:]):
        s = s[:match.start()] + s[match.end():]
p.write_text(s)
