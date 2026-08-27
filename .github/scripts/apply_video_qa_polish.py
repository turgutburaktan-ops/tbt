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
