import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/activity_demand_screen.dart';
import '../screens/event_create_screen_v2.dart';

class RetentionNowOverlay extends StatelessWidget {
  final Widget child;
  const RetentionNowOverlay({super.key, required this.child});

  Future<void> _openNow(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .62),
    builder: (_) => const _NowSheet(),
  );

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      Positioned(
        left: 12,
        bottom: 84,
        child: SafeArea(
          top: false,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openNow(context),
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xE60D1118),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .11),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulseDot(),
                    SizedBox(width: 6),
                    Text(
                      'Buradayım / Buluşalım',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 15,
                      color: Colors.white54,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: .42, end: 1).animate(_controller),
    child: const SizedBox(
      width: 8,
      height: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF45E7F2),
        ),
      ),
    ),
  );
}

class _NowSheet extends StatelessWidget {
  const _NowSheet();

  @override
  Widget build(BuildContext context) {
    final recentPosts = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(60);
    final upcomingEvents = FirebaseFirestore.instance
        .collection('social_events')
        .orderBy('startsAt')
        .limit(40);
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: .78,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0B0E14),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 9),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 17, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Buradayım / Buluşalım',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.5,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Yakınındaki planlara katıl veya yeni bir plan başlat',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _RadarBadge(),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _NowActions(),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: recentPosts.snapshots(),
                  builder: (context, postsSnapshot) =>
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: upcomingEvents.snapshots(),
                        builder: (context, eventsSnapshot) {
                          final now = DateTime.now();
                          final cutoff = now.subtract(const Duration(hours: 3));
                          final posts = (postsSnapshot.data?.docs ?? const [])
                              .where((doc) {
                                final t = doc.data()['createdAt'];
                                return t is Timestamp &&
                                    t.toDate().isAfter(cutoff);
                              })
                              .toList();
                          final events = (eventsSnapshot.data?.docs ?? const [])
                              .where((doc) {
                                final t = doc.data()['startsAt'];
                                if (t is! Timestamp) return false;
                                final date = t.toDate();
                                return date.isAfter(
                                      now.subtract(const Duration(hours: 1)),
                                    ) &&
                                    date.isBefore(
                                      now.add(const Duration(hours: 24)),
                                    );
                              })
                              .toList();
                          final creators = posts
                              .map((d) => (d.data()['userId'] ?? '').toString())
                              .where((e) => e.isNotEmpty)
                              .toSet()
                              .length;
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                            children: [
                              _StatsCard(
                                creators: creators,
                                posts: posts.length,
                                events: events.length,
                              ),
                              const SizedBox(height: 18),
                              const _Section(
                                icon: Icons.bolt_rounded,
                                title: 'Son 3 saat',
                              ),
                              const SizedBox(height: 8),
                              if (posts.isEmpty)
                                const _Empty(
                                  'Henüz yeni hareket yok. İlk paylaşımı sen yapabilirsin.',
                                )
                              else
                                ...posts
                                    .take(4)
                                    .map((d) => _PostTile(d.data())),
                              const SizedBox(height: 18),
                              const _Section(
                                icon: Icons.event_available_rounded,
                                title: 'Önümüzdeki 24 saat',
                              ),
                              const SizedBox(height: 8),
                              if (events.isEmpty)
                                const _Empty(
                                  'Yaklaşan herkese açık etkinlik görünmüyor.',
                                )
                              else
                                ...events
                                    .take(4)
                                    .map((d) => _EventTile(d.data())),
                              const SizedBox(height: 18),
                              const _Section(
                                icon: Icons.people_alt_rounded,
                                title: 'Arkadaş hareketi',
                              ),
                              const SizedBox(height: 8),
                              const _FriendActivity(),
                            ],
                          );
                        },
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NowActions extends StatelessWidget {
  const _NowActions();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ActivityDemandScreen(
                    initialActivity: 'Sosyal',
                  ),
                ),
              ),
              icon: const Icon(Icons.near_me_rounded),
              label: const Text('Buradayım'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EventCreateScreenV2(
                    initialTitle: 'Buluşalım',
                    initialDescription: 'Yakındaki insanlarla yeni bir plan.',
                  ),
                ),
              ),
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Buluşalım'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      const Text(
        'Buradayım yalnızca seçtiğin şehir ve aktivite sinyalini paylaşır; kesin konum yayınlanmaz.',
        style: TextStyle(color: Colors.white46, fontSize: 10.5, height: 1.3),
      ),
    ],
  );
}

class _RadarBadge extends StatelessWidget {
  const _RadarBadge();
  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: const Color(0x1645E7F2),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0x3345E7F2)),
    ),
    child: const Icon(Icons.radar_rounded, color: Color(0xFF45E7F2), size: 22),
  );
}

class _StatsCard extends StatelessWidget {
  final int creators, posts, events;
  const _StatsCard({
    required this.creators,
    required this.posts,
    required this.events,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 13),
    decoration: BoxDecoration(
      color: const Color(0xFF111620),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .06)),
    ),
    child: Row(
      children: [
        Expanded(child: _Stat('$creators', 'aktif üretici')),
        const _Divider(),
        Expanded(child: _Stat('$posts', 'yeni paylaşım')),
        const _Divider(),
        Expanded(child: _Stat('$events', 'etkinlik')),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: Color(0xFF45E7F2),
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          color: Colors.white.withValues(alpha: .46),
        ),
      ),
    ],
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 30, color: Colors.white10);
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  const _Section({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: Colors.white60),
      const SizedBox(width: 7),
      Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
    ],
  );
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF111620),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: .50),
        height: 1.35,
      ),
    ),
  );
}

class _PostTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PostTile(this.data);
  @override
  Widget build(BuildContext context) {
    final name = (data['userName'] ?? 'TBT kullanıcısı').toString();
    final spot = (data['spotName'] ?? '').toString();
    final caption = (data['caption'] ?? '').toString();
    return _InfoTile(
      icon: Icons.photo_camera_back_rounded,
      title: name,
      subtitle: spot.isNotEmpty
          ? '$spot konumundan yeni paylaşım'
          : (caption.isNotEmpty ? caption : 'Yeni paylaşım yaptı'),
    );
  }
}

class _EventTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _EventTile(this.data);
  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? data['name'] ?? 'Etkinlik').toString();
    final raw = data['startsAt'];
    final date = raw is Timestamp ? raw.toDate().toLocal() : null;
    final time = date == null
        ? ''
        : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final location = [data['locationLabel'], data['venueName'], data['city']]
        .map((e) => (e ?? '').toString().trim())
        .firstWhere((e) => e.isNotEmpty, orElse: () => '');
    return _InfoTile(
      icon: Icons.event_rounded,
      title: title,
      subtitle: [
        if (time.isNotEmpty) time,
        if (location.isNotEmpty) location,
      ].join(' • '),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 7),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: const Color(0xFF111620),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: Colors.white60),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .46),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _FriendActivity extends StatelessWidget {
  const _FriendActivity();
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null)
      return const _Empty('Arkadaş hareketini görmek için giriş yap.');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('following')
          .limit(50)
          .snapshots(),
      builder: (context, following) {
        final ids = following.data?.docs.map((d) => d.id).toSet() ?? <String>{};
        if (ids.isEmpty)
          return const _Empty(
            'Takip ettiğin kişiler paylaşım yaptığında burada görünecek.',
          );
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .orderBy('createdAt', descending: true)
              .limit(80)
              .snapshots(),
          builder: (context, posts) {
            final items = (posts.data?.docs ?? const [])
                .where(
                  (d) => ids.contains((d.data()['userId'] ?? '').toString()),
                )
                .take(4)
                .toList();
            if (items.isEmpty)
              return const _Empty('Takip ettiklerinden yeni hareket yok.');
            return Column(
              children: items.map((d) {
                final x = d.data();
                return _InfoTile(
                  icon: Icons.people_rounded,
                  title: (x['userName'] ?? 'Takip ettiğin biri').toString(),
                  subtitle: (x['spotName'] ?? '').toString().isNotEmpty
                      ? '${x['spotName']} konumundan paylaşım yaptı'
                      : 'Yeni paylaşım yaptı',
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}
