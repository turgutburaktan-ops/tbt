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
old_nearby = """    final labels = campusEligible
        ? const ['Radar', 'Etkinlikler', 'Kampüs']
        : const ['Radar', 'Etkinlikler'];
    final effectiveSection = _section >= labels.length ? 0 : _section;
    final pages = <Widget>[
      const RadarScreen(embedded: true),
      const EventsHubScreen(),
      if (campusEligible) const CampusHomeScreen(),
    ];"""
new_nearby = """    final labels = campusEligible
        ? const ['Çevrende', 'Kampüs']
        : const ['Çevrende'];
    final effectiveSection = _section >= labels.length ? 0 : _section;
    final pages = <Widget>[
      const RadarScreen(embedded: true),
      if (campusEligible) const CampusHomeScreen(),
    ];"""
if old_nearby in s:
    s = s.replace(old_nearby, new_nearby, 1)
s = s.replace("'Radar, etkinlikler ve öğrencilere özel kampüs.'", "'Yakındaki planlar, etkinlikler ve öğrencilere özel kampüs.'", 1)
old_tabs = """              child: _CompactTabs(
                firstLabel: 'Sana Özel',
                secondLabel: 'Takip',
                selected: _section,
                onChanged: (value) => setState(() => _section = value),
              ),"""
new_tabs = """              child: _NearbyTabs(
                labels: const ['Sana Özel', 'Takip', 'Reels'],
                selected: _section,
                onChanged: (value) => setState(() => _section = value),
              ),"""
if old_tabs in s:
    s = s.replace(old_tabs, new_tabs, 1)
old_pages = """                children: const [
                  _AuthAwareFeed(mode: FeedMode.forYou),
                  _AuthAwareFeed(mode: FeedMode.following),
                ],"""
new_pages = """                children: const [
                  _AuthAwareFeed(mode: FeedMode.forYou),
                  _AuthAwareFeed(mode: FeedMode.following),
                  ReelsScreen(),
                ],"""
if old_pages in s:
    s = s.replace(old_pages, new_pages, 1)
p.write_text(s)

# Radar: one clear create action, less duplicate content, better empty-state language.
p = Path('lib/screens/radar_screen.dart')
s = p.read_text()
if "import 'event_photo_create_screen.dart';" not in s:
    s = s.replace("import 'event_deep_link_screen.dart';\n", "import 'event_deep_link_screen.dart';\nimport 'event_photo_create_screen.dart';\n")
old_create = """        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              if (FirebaseAuth.instance.currentUser == null) {
                _message('Etkinlik oluşturmak için giriş yapmalısın.');
                return;
              }
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const EventPhotoCreateScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Etkinlik Oluştur'),
          ),
        ),
        const SizedBox(height: 10),
"""
s = s.replace(old_create, '')
s = s.replace("hintText: 'Şehir seç veya Türkiye geneli bırak'", "hintText: 'Şehir seç; boş bırakırsan Türkiye geneli gösterilir'")
s = s.replace("'ŞEHİR ŞU AN HAREKETLİ'", "'ŞEHRİN CANLI DURUMU'")
old_bottom = """                      const SizedBox(height: 20),
                      _sectionTitle(
                        '⚡ Planı sen başlat',
                        'Bir fikir seç, çevrendekilere haber ver',
                      ),
                      const SizedBox(height: 9),
                      _quickStartStrip(alwaysShow: true),
"""
s = s.replace(old_bottom, '')
p.write_text(s)

# Main video/Reels capture is 60 sec. Story remains 15 sec.
p = Path('lib/screens/camera_screen.dart')
s = p.read_text()
s = s.replace(
    "int get _videoLimitSeconds => widget.storyMode ? 15 : 30;",
    "int get _videoLimitSeconds => widget.storyMode ? 15 : 60;",
)
p.write_text(s)

# Profile: Story add action + content tabs for all/photos/videos.
p = Path('lib/screens/profile_page_v2.dart')
s = p.read_text()
if "import 'camera_screen.dart';" not in s:
    s = s.replace("import 'create_post_screen.dart';\n", "import 'camera_screen.dart';\nimport 'create_post_screen.dart';\n")
if "String _contentTab = 'all';" not in s:
    s = s.replace("class _ProfileBodyState extends State<_ProfileBody> {", "class _ProfileBodyState extends State<_ProfileBody> {\n  String _contentTab = 'all';")
s = s.replace(
    "onTap: () =>\n                                          _editProfile(displayName, bio),",
    "onTap: () => Navigator.push(\n                                          context,\n                                          MaterialPageRoute(builder: (_) => const CameraScreen(storyMode: true)),\n                                        ),",
    1,
)
needle = """              posts.sort((a, b) {
                final at = a.data()['createdAt'];
                final bt = b.data()['createdAt'];
                if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
                return 0;
              });
"""
if needle in s and "final visiblePosts = posts.where" not in s:
    s = s.replace(needle, needle + """              final visiblePosts = posts.where((post) {
                final data = post.data();
                final isVideo = (data['mediaType'] ?? '').toString() == 'video' ||
                    (data['videoUrl'] ?? '').toString().isNotEmpty;
                if (_contentTab == 'photos') return !isVideo;
                if (_contentTab == 'videos') return isVideo;
                return true;
              }).toList();
""", 1)
# Insert tabs just before loading/grid branch.
tab_marker = """                  if (postSnapshot.connectionState == ConnectionState.waiting)
"""
if tab_marker in s and "value: 'videos'" not in s:
    tabs = """                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'all', icon: Icon(Icons.grid_on_rounded), label: Text('Tümü')),
                          ButtonSegment(value: 'photos', icon: Icon(Icons.photo_outlined), label: Text('Fotoğraf')),
                          ButtonSegment(value: 'videos', icon: Icon(Icons.play_circle_outline_rounded), label: Text('Reels')),
                        ],
                        selected: {_contentTab},
                        onSelectionChanged: (value) => setState(() => _contentTab = value.first),
                      ),
                    ),
                  ),
"""
    s = s.replace(tab_marker, tabs + tab_marker, 1)
s = s.replace("else if (posts.isEmpty)", "else if (visiblePosts.isEmpty)")
s = s.replace("childCount: posts.length", "childCount: visiblePosts.length")
s = s.replace("final post = posts[index];", "final post = visiblePosts[index];")
p.write_text(s)

# Campus: make student status explicit and give empty screens a clear next action.
p = Path('lib/screens/campus_home_screen.dart')
s = p.read_text()
marker = """            children: [
              if (newStudent)
                _WelcomeCard("""
insert = """            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school_outlined, size: 20, color: Colors.white70),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Kampüs profili aktif', style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text('$university • ${classYear == 'Hazırlık' ? 'Hazırlık' : '$classYear. sınıf'}', style: const TextStyle(color: Colors.white60, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/campus-profile'),
                      child: const Text('Düzenle'),
                    ),
                  ],
                ),
              ),
              if (newStudent)
                _WelcomeCard("""
if marker in s and "Kampüs profili aktif" not in s:
    s = s.replace(marker, insert, 1)
s = s.replace("const _Empty('Henüz talep yok. İlk talebi sen oluştur.')", "const _Empty('Henüz talep yok. Ne yapmak istediğini seçerek ilk talebi oluştur.')")
s = s.replace("const _Empty('Bu üniversitede henüz topluluk yok.')", "const _Empty('Henüz topluluk yok. Tüm toplulukları keşfet veya ilk topluluğu oluştur.')")
s = s.replace("const _Empty('Yaklaşan kampüs etkinliği henüz yok.')", "const _Empty('Yaklaşan kampüs etkinliği yok. Çevrende sekmesinden yeni bir etkinlik oluşturabilirsin.')")
p.write_text(s)

# Statistics: tabs + true active/completed event split.
p = Path('lib/screens/user_statistics_screen.dart')
s = p.read_text()
if "String _section = 'all';" not in s:
    s = s.replace("Future<_UserStatistics>? _future;", "Future<_UserStatistics>? _future;\n  String _section = 'all';")
s = s.replace("var openHostedEvents = 0;", "var activeHostedEvents = 0;\n    var completedHostedEvents = 0;")
old_status = """      if (status == 'cancelled') {
        cancelledHostedEvents++;
      } else {
        openHostedEvents++;
      }
"""
new_status = """      if (status == 'cancelled') {
        cancelledHostedEvents++;
      } else {
        final startsAt = data['startsAt'];
        final endsAt = data['endsAt'];
        final reference = endsAt is Timestamp ? endsAt.toDate() : (startsAt is Timestamp ? startsAt.toDate() : null);
        if (reference != null && reference.isBefore(now)) {
          completedHostedEvents++;
        } else {
          activeHostedEvents++;
        }
      }
"""
s = s.replace(old_status, new_status)
s = s.replace("openHostedEvents: openHostedEvents,", "activeHostedEvents: activeHostedEvents,\n      completedHostedEvents: completedHostedEvents,")
s = s.replace("final int openHostedEvents;", "final int activeHostedEvents;\n  final int completedHostedEvents;")
s = s.replace("required this.openHostedEvents,", "required this.activeHostedEvents,\n    required this.completedHostedEvents,")
s = s.replace("_Metric('Aktif / tamamlanan', stats.openHostedEvents, Icons.event_available_outlined)", "_Metric('Aktif', stats.activeHostedEvents, Icons.event_available_outlined),\n                    _Metric('Tamamlanan', stats.completedHostedEvents, Icons.task_alt_rounded)")
s = s.replace("_Metric('Aktif / tamamlanmış', stats.openHostedEvents, Icons.event_available_outlined)", "_Metric('Aktif', stats.activeHostedEvents, Icons.event_available_outlined),\n                    _Metric('Tamamlanan', stats.completedHostedEvents, Icons.task_alt_rounded)")
stat_marker = """                _OverviewCard(stats: stats),
"""
if stat_marker in s and "ButtonSegment(value: 'story'" not in s:
    s = s.replace(stat_marker, """                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('Genel')),
                    ButtonSegment(value: 'posts', label: Text('İçerik')),
                    ButtonSegment(value: 'story', label: Text('Story')),
                    ButtonSegment(value: 'events', label: Text('Etkinlik')),
                  ],
                  selected: {_section},
                  onSelectionChanged: (value) => setState(() => _section = value.first),
                ),
                const SizedBox(height: 12),
                if (_section == 'all') _OverviewCard(stats: stats),
""", 1)
s = s.replace("                _Section(\n                  title: 'Sosyal',", "                if (_section == 'all') _Section(\n                  title: 'Sosyal',")
s = s.replace("                _Section(\n                  title: 'Gönderiler',", "                if (_section == 'all' || _section == 'posts') _Section(\n                  title: 'Gönderiler',")
s = s.replace("                _Section(\n                  title: 'Story',", "                if (_section == 'all' || _section == 'story') _Section(\n                  title: 'Story',")
s = s.replace("                _Section(\n                  title: 'Etkinlikler',", "                if (_section == 'all' || _section == 'events') _Section(\n                  title: 'Etkinlikler',")
s = s.replace(
    "'Rakamlar Firebase’deki mevcut kayıtların tamamından hesaplanır. Yenile ile güncel değerleri tekrar çekebilirsin.'",
    "'Toplam değerler tüm kayıtları, “Son 30 gün” satırları ise yakın dönemi gösterir. Yenile ile güncel değerleri tekrar çekebilirsin.'",
)
p.write_text(s)

# Admin: make role preview impossible to miss in the management center.
p = Path('lib/screens/admin_portal_screen.dart')
s = p.read_text()
s = s.replace("title: 'Rol Önizleme'", "title: 'Uygulamayı Rol Olarak Önizle'")
s = s.replace("subtitle: 'Misafir, kullanıcı, etkinlik düzenleyici, işletme ve premium işletme gibi gör.'", "subtitle: 'Hesap açmadan Misafir, Kullanıcı, Düzenleyici, İşletme, Doğrulanmış ve Premium görünümünü test et.'")
p.write_text(s)

# Event cover attachment: support both the legacy creator and EventCreateScreenV2.
p = Path('lib/screens/event_photo_create_screen.dart')
s = p.read_text()
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
if old in s:
    if "package:cloud_functions/cloud_functions.dart" not in s:
        s = s.replace("import 'package:cloud_firestore/cloud_firestore.dart';\n", "import 'package:cloud_firestore/cloud_firestore.dart';\nimport 'package:cloud_functions/cloud_functions.dart';\n")
    s = s.replace(old, new, 1)
    p.write_text(s)
elif "EventCreateScreenV2" in s:
    v2 = Path('lib/screens/event_create_screen_v2.dart').read_text()
    required = [
        "package:cloud_functions/cloud_functions.dart",
        "httpsCallable('setSocialEventCover')",
        "'coverStoragePath': ref.fullPath",
    ]
    missing = [item for item in required if item not in v2]
    if missing:
        raise SystemExit('EventCreateScreenV2 cover attachment incomplete: ' + ', '.join(missing))
elif "httpsCallable('setSocialEventCover')" not in s:
    raise SystemExit('Missing compatible event cover attachment implementation')

# The old all-fields create sheet is no longer the main route, but keep it photo-capable too.
p = Path('lib/screens/social_events_screen.dart')
s = p.read_text()
if "import 'event_photo_create_screen.dart';" not in s:
    s = s.replace("import 'event_location_picker_screen.dart';\n", "import 'event_location_picker_screen.dart';\nimport 'event_photo_create_screen.dart';\n")
start = s.find('  Future<void> _openCreate() async {')
end = s.find('\n  @override\n  Widget build(BuildContext context)', start)
if start >= 0 and end >= 0:
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

# Remove obsolete OSM packages. Google Maps is the only in-app map renderer.
p = Path('pubspec.yaml')
s = p.read_text().replace('  flutter_map: ^8.2.2\n', '').replace('  latlong2: ^0.9.1\n', '')
p.write_text(s)

# Block actual OSM renderer/tile dependencies, not harmless historical text/comments.
offenders = []
for f in Path('lib').rglob('*.dart'):
    t = f.read_text()
    forbidden = (
        "package:flutter_map/",
        "package:latlong2/",
        "tile.openstreetmap.org",
        "{s}.tile.openstreetmap.org",
    )
    if any(item in t for item in forbidden):
        offenders.append(str(f))
if offenders:
    raise SystemExit('OpenStreetMap renderer refs remain: ' + ', '.join(offenders))

# Build trigger: requested UI fixes are intentionally idempotent.
