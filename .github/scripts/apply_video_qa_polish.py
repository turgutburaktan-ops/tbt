from pathlib import Path

# Feed: replace indefinite bare spinners with a lightweight skeleton-like state.
p = Path('lib/screens/feed_screen.dart')
s = p.read_text()
if 'class _FeedLoading extends StatelessWidget' not in s:
    s = s.replace(
        'return const Center(child: CircularProgressIndicator());',
        'return const _FeedLoading();',
        2,
    )
    s += '''

class _FeedLoading extends StatelessWidget {
  const _FeedLoading();

  @override
  Widget build(BuildContext context) => ListView.separated(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
    itemCount: 3,
    separatorBuilder: (_, __) => const SizedBox(height: 14),
    itemBuilder: (_, __) => Container(
      height: 290,
      decoration: BoxDecoration(
        color: const Color(0xFF121416),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(radius: 18, backgroundColor: Color(0xFF25292D)),
                SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xFF25292D)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: ColoredBox(color: Color(0xFF1A1D20))),
        ],
      ),
    ),
  );
}
'''
p.write_text(s)

# Create-post: keep the media preview useful without pushing every important
# field below the fold, and let a drag dismiss the keyboard.
p = Path('lib/screens/create_post_screen.dart')
s = p.read_text()
s = s.replace('''      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),''', '''      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),''', 1)
s = s.replace('              height: 330,', '              height: 260,', 1)
p.write_text(s)

# Business profile: the current UI already has meaningful empty states. Remove
# only an accidental duplicated social-proof summary if both copies coexist.
p = Path('lib/screens/business_profile_screen.dart')
s = p.read_text()
needle = "                        const SizedBox(height: 14),\n                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(\n"
first = s.find(needle)
if first >= 0:
    second = s.find(needle, first + len(needle))
    # Two adjacent summaries were introduced by overlapping product patches.
    if second >= 0 and second - first < 7000:
        s = s[:first] + s[second:]
p.write_text(s)

# Map: the national view should be readable, not a wall of pins. Keep the
# existing progressive reveal but use tighter limits until the user zooms in.
p = Path('lib/screens/map_screen.dart')
s = p.read_text()
s = s.replace(
    '''      final visibleSpots = _mapZoom < 7
          ? _spots.take(140)
          : _mapZoom < 9
          ? _spots.take(360)
          : _spots;''',
    '''      final visibleSpots = _mapZoom < 7
          ? _spots.take(48)
          : _mapZoom < 9
          ? _spots.take(140)
          : _mapZoom < 11
          ? _spots.take(420)
          : _spots;''',
    1,
)
# Nearby cafe/dining/hotel data is local to the user; keeping each category
# compact prevents another marker flood immediately after location resolves.
s = s.replace(
    '      return venues.take(40).toList(growable: false);',
    '      return venues.take(20).toList(growable: false);',
    1,
)
p.write_text(s)

# Favorite place picker: location providers and remote venue sources can stall
# on weak networks. Bound both waits so the UI reaches its retry/empty state.
p = Path('lib/widgets/profile_favorite_places_section.dart')
s = p.read_text()
s = s.replace(
    '      final position = await LocationService.getCurrentPosition();',
    '''      final position = await LocationService.getCurrentPosition().timeout(
        const Duration(seconds: 8),
      );''',
    1,
)
s = s.replace(
    '''    final venues = await NearbyVenueService.instance.nearby(
      category: category,
      latitude: latitude,
      longitude: longitude,
    );''',
    '''    final venues = await NearbyVenueService.instance
        .nearby(
          category: category,
          latitude: latitude,
          longitude: longitude,
        )
        .timeout(const Duration(seconds: 12));''',
    1,
)
p.write_text(s)

# Final launch-facing cleanup collected from the latest end-to-end recording.
launch = Path('.github/scripts/apply_launch_polish.py')
if launch.exists():
    exec(compile(launch.read_text(), str(launch), 'exec'))
