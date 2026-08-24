from pathlib import Path


def require_replace(text: str, old: str, new: str, label: str, count: int = 1) -> str:
    if old in text:
        return text.replace(old, new, count)
    if new in text:
        return text
    raise SystemExit(f"Missing patch target: {label}")


# Home: unify Radar + Events into Çevrende and move Reels into Home.
p = Path('lib/screens/home_shell_screen.dart')
s = p.read_text()
s = s.replace("import 'events_hub_screen.dart';\n", '')
if "import 'reels_screen.dart';" not in s:
    s = s.replace("import 'radar_screen.dart';\n", "import 'radar_screen.dart';\nimport 'reels_screen.dart';\n")
s = require_replace(
    s,
    """    final labels = campusEligible
        ? const ['Radar', 'Etkinlikler', 'Kampüs']
        : const ['Radar', 'Etkinlikler'];
    final effectiveSection = _section >= labels.length ? 0 : _section;
    final pages = <Widget>[
      const RadarScreen(embedded: true),
      const EventsHubScreen(),
      if (campusEligible) const CampusHomeScreen(),
    ];""",
    """    final labels = campusEligible
        ? const ['Çevrende', 'Kampüs']
        : const ['Çevrende'];
    final effectiveSection = _section >= labels.length ? 0 : _section;
    final pages = <Widget>[
      const RadarScreen(embedded: true),
      if (campusEligible) const CampusHomeScreen(),
    ];""",
    'nearby tabs',
)
s = s.replace("'Radar, etkinlikler ve öğrencilere özel kampüs.'", "'Yakındaki planlar, etkinlikler ve öğrencilere özel kampüs.'", 1)
s = require_replace(
    s,
    """              child: _CompactTabs(
                firstLabel: 'Sana Özel',
                secondLabel: 'Takip',
                selected: _section,
                onChanged: (value) => setState(() => _section = value),
              ),""",
    """              child: _NearbyTabs(
                labels: const ['Sana Özel', 'Takip', 'Reels'],
                selected: _section,
                onChanged: (value) => setState(() => _section = value),
              ),""",
    'home reels tabs',
)
s = require_replace(
    s,
    """                children: const [
                  _AuthAwareFeed(mode: FeedMode.forYou),
                  _AuthAwareFeed(mode: FeedMode.following),
                ],""",
    """                children: const [
                  _AuthAwareFeed(mode: FeedMode.forYou),
                  _AuthAwareFeed(mode: FeedMode.following),
                  ReelsScreen(),
                ],""",
    'home reels page',
)
p.write_text(s)

# Radar: keep event creation on the single Çevrende page and use the photo creator.
p = Path('lib/screens/radar_screen.dart')
s = p.read_text()
if "import 'event_photo_create_screen.dart';" not in s:
    s = s.replace("import 'event_deep_link_screen.dart';\n", "import 'event_deep_link_screen.dart';\nimport 'event_photo_create_screen.dart';\n")
marker = """        SearchableSelectionField(
          controller: _cityController,"""
insert = """        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              if (FirebaseAuth.instance.currentUser == null) {
                _message('Etkinlik oluşturmak için giriş yapmalısın.');
                return;
              }
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const EventPhotoCreateScreen()),
              );
            },
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Etkinlik Oluştur'),
          ),
        ),
        const SizedBox(height: 10),
        SearchableSelectionField(
          controller: _cityController,"""
if insert not in s:
    if marker not in s:
        raise SystemExit('Missing patch target: radar event create')
    s = s.replace(marker, insert, 1)
p.write_text(s)

# Main video/Reels capture is 60 sec. Story remains 15 sec.
p = Path('lib/screens/camera_screen.dart')
s = p.read_text()
s = require_replace(
    s,
    "int get _videoLimitSeconds => widget.storyMode ? 15 : 30;",
    "int get _videoLimitSeconds => widget.storyMode ? 15 : 60;",
    'video duration',
)
p.write_text(s)

# Dedicated photo-event creator: avoid a Firestore host update that rules reject.
# Add a server function call after upload to attach the cover safely.
p = Path('lib/screens/event_photo_create_screen.dart')
s = p.read_text()
if "package:cloud_functions/cloud_functions.dart" not in s:
    s = s.replace("import 'package:cloud_firestore/cloud_firestore.dart';\n", "import 'package:cloud_firestore/cloud_firestore.dart';\nimport 'package:cloud_functions/cloud_functions.dart';\n")
old = """      await FirebaseFirestore.instance
          .collection(SocialEventService.collection)
          .doc(eventId)
          .set({
        'coverImageUrl': url,
        'coverImageUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));"""
new = """      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('setSocialEventCover')
          .call({
        'eventId': eventId,
        'coverImageUrl': url,
        'coverStoragePath': ref.fullPath,
      });"""
s = require_replace(s, old, new, 'event cover function call')
p.write_text(s)

# The old all-fields create sheet is no longer the main route, but keep it photo-capable too.
p = Path('lib/screens/social_events_screen.dart')
s = p.read_text()
if "import 'event_photo_create_screen.dart';" not in s:
    s = s.replace("import 'event_location_picker_screen.dart';\n", "import 'event_location_picker_screen.dart';\nimport 'event_photo_create_screen.dart';\n")
start = s.find('  Future<void> _openCreate() async {')
end = s.find('\n  @override\n  Widget build(BuildContext context)', start)
if start < 0 or end < 0:
    raise SystemExit('Missing patch target: social event creator')
replacement = """  Future<void> _openCreate() async {
    if (FirebaseAuth.instance.currentUser == null) {
      _showMessage('Etkinlik oluşturmak için giriş yapmalısın.');
      return;
    }
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EventPhotoCreateScreen()),
    );
    if (created == true) {
      _showMessage('Etkinlik oluşturuldu.');
    }
  }
"""
if 'EventPhotoCreateScreen()' not in s[start:end]:
    s = s[:start] + replacement + s[end:]
p.write_text(s)

# Remove OSM deps now that selected route preview is Google Maps.
p = Path('pubspec.yaml')
s = p.read_text().replace('  flutter_map: ^8.2.2\n', '').replace('  latlong2: ^0.9.1\n', '')
p.write_text(s)

# No OSM code may remain in lib.
offenders = []
for f in Path('lib').rglob('*.dart'):
    t = f.read_text()
    if 'flutter_map' in t or 'openstreetmap.org' in t or 'package:latlong2' in t:
        offenders.append(str(f))
if offenders:
    raise SystemExit('OpenStreetMap refs remain: ' + ', '.join(offenders))
