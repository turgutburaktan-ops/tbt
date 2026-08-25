import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RetentionNowOverlay extends StatelessWidget {
  final Widget child;

  const RetentionNowOverlay({super.key, required this.child});

  Future<void> _openNow(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101319),
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => const _NowSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 14,
          bottom: 84,
          child: SafeArea(
            top: false,
            child: Material(
              color: const Color(0xFF151922),
              elevation: 8,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: () => _openNow(context),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFB7BCC2).withValues(alpha: .42)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulseDot(),
                      SizedBox(width: 7),
                      Text(
                        'Şu An',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(width: 5),
                      Icon(Icons.keyboard_arrow_up_rounded, size: 17, color: Colors.white70),
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
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween<double>(begin: .45, end: 1).animate(_controller),
        child: const SizedBox(
          width: 9,
          height: 9,
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFF39DDE8)),
          ),
        ),
      );
}

class _NowSheet extends StatelessWidget {
  const _NowSheet();

  Query<Map<String, dynamic>> get _recentPosts => FirebaseFirestore.instance
      .collection('posts')
      .orderBy('createdAt', descending: true)
      .limit(60);

  Query<Map<String, dynamic>> get _upcomingEvents => FirebaseFirestore.instance
      .collection('social_events')
      .orderBy('startsAt')
      .limit(40);

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * .78;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Şu An', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                        SizedBox(height: 3),
                        Text('TBT’de şu anda neler oluyor?', style: TextStyle(color: Colors.white60, fontSize: 13)),
                      ],
                    ),
                  ),
                  Icon(Icons.radar_rounded, color: Color(0xFF39DDE8)),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _recentPosts.snapshots(),
                builder: (context, postsSnapshot) {
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _upcomingEvents.snapshots(),
                    builder: (context, eventsSnapshot) {
                      final posts = postsSnapshot.data?.docs ?? const [];
                      final now = DateTime.now();
                      final recentCutoff = now.subtract(const Duration(hours: 3));
                      final recentPosts = posts.where((doc) {
                        final raw = doc.data()['createdAt'];
                        return raw is Timestamp && raw.toDate().isAfter(recentCutoff);
                      }).toList();

                      final events = eventsSnapshot.data?.docs ?? const [];
                      final upcoming = events.where((doc) {
                        final raw = doc.data()['startsAt'];
                        if (raw is! Timestamp) return false;
                        final start = raw.toDate();
                        return start.isAfter(now.subtract(const Duration(hours: 1))) &&
                            start.isBefore(now.add(const Duration(hours: 24)));
                      }).toList();

                      final activeCreators = recentPosts
                          .map((doc) => (doc.data()['userId'] ?? '').toString())
                          .where((id) => id.isNotEmpty)
                          .toSet()
                          .length;

                      final loading = postsSnapshot.connectionState == ConnectionState.waiting &&
                          eventsSnapshot.connectionState == ConnectionState.waiting;

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                        children: [
                          if (loading) const LinearProgressIndicator(minHeight: 2),
                          _StatsCard(
                            recentPostCount: recentPosts.length,
                            activeCreatorCount: activeCreators,
                            eventCount: upcoming.length,
                          ),
                          const SizedBox(height: 14),
                          const _SectionTitle(icon: Icons.bolt_rounded, title: 'Son 3 saatte'),
                          const SizedBox(height: 8),
                          if (recentPosts.isEmpty)
                            const _EmptyCard(text: 'Henüz yeni hareket yok. İlk paylaşımı sen yapabilirsin.')
                          else
                            ...recentPosts.take(5).map((doc) => _RecentPostTile(data: doc.data())),
                          const SizedBox(height: 16),
                          const _SectionTitle(icon: Icons.event_available_rounded, title: 'Önümüzdeki 24 saat'),
                          const SizedBox(height: 8),
                          if (upcoming.isEmpty)
                            const _EmptyCard(text: 'Yaklaşan herkese açık etkinlik görünmüyor.')
                          else
                            ...upcoming.take(5).map((doc) => _EventTile(data: doc.data())),
                          const SizedBox(height: 16),
                          const _SectionTitle(icon: Icons.people_alt_rounded, title: 'Arkadaş hareketi'),
                          const SizedBox(height: 8),
                          const _FriendActivity(),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final int recentPostCount;
  final int activeCreatorCount;
  final int eventCount;

  const _StatsCard({required this.recentPostCount, required this.activeCreatorCount, required this.eventCount});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF171B23),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Expanded(child: _Stat(value: '$activeCreatorCount', label: 'aktif üretici')),
            const _Divider(),
            Expanded(child: _Stat(value: '$recentPostCount', label: 'yeni paylaşım')),
            const _Divider(),
            Expanded(child: _Stat(value: '$eventCount', label: 'yaklaşan etkinlik')),
          ],
        ),
      );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 35, color: Colors.white10);
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF39DDE8))),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
        ],
      );
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xFFB7BCC2)),
          const SizedBox(width: 7),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      );
}

class _RecentPostTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RecentPostTile({required this.data});
  @override
  Widget build(BuildContext context) {
    final name = (data['userName'] ?? 'TBT kullanıcısı').toString();
    final spot = (data['spotName'] ?? '').toString();
    final caption = (data['caption'] ?? '').toString();
    return _InfoCard(
      icon: Icons.photo_camera_back_rounded,
      title: name,
      subtitle: spot.isNotEmpty ? '$spot konumundan yeni paylaşım' : (caption.isNotEmpty ? caption : 'Yeni bir paylaşım yaptı'),
    );
  }
}

class _EventTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _EventTile({required this.data});
  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? data['name'] ?? 'Etkinlik').toString();
    final location = (data['locationName'] ?? data['location'] ?? '').toString();
    final raw = data['startsAt'];
    final start = raw is Timestamp ? raw.toDate().toLocal() : null;
    final time = start == null ? '' : '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    return _InfoCard(
      icon: Icons.event_rounded,
      title: title,
      subtitle: [if (time.isNotEmpty) time, if (location.isNotEmpty) location].join(' • '),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoCard({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF171B23), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 19, color: Colors.white70),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFF171B23), borderRadius: BorderRadius.circular(16)),
        child: Text(text, style: const TextStyle(color: Colors.white54, height: 1.35)),
      );
}

class _FriendActivity extends StatelessWidget {
  const _FriendActivity();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const _EmptyCard(text: 'Arkadaş hareketini görmek için giriş yap.');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('following')
          .limit(50)
          .snapshots(),
      builder: (context, followingSnapshot) {
        final ids = followingSnapshot.data?.docs.map((d) => d.id).toSet() ?? <String>{};
        if (ids.isEmpty) {
          return const _EmptyCard(text: 'Takip ettiğin kişiler paylaşım yaptığında burada görünecek.');
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).limit(80).snapshots(),
          builder: (context, postsSnapshot) {
            final posts = (postsSnapshot.data?.docs ?? const [])
                .where((doc) => ids.contains((doc.data()['userId'] ?? '').toString()))
                .take(4)
                .toList();
            if (posts.isEmpty) return const _EmptyCard(text: 'Takip ettiklerinden yeni hareket yok.');
            return Column(
              children: posts.map((doc) {
                final data = doc.data();
                return _InfoCard(
                  icon: Icons.people_rounded,
                  title: (data['userName'] ?? 'Takip ettiğin biri').toString(),
                  subtitle: (data['spotName'] ?? '').toString().isNotEmpty
                      ? '${data['spotName']} konumundan paylaşım yaptı'
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
