import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RetentionHubScreen extends StatefulWidget {
  final int initialTab;
  const RetentionHubScreen({super.key, this.initialTab = 0});

  @override
  State<RetentionHubScreen> createState() => _RetentionHubScreenState();
}

class _RetentionHubScreenState extends State<RetentionHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this, initialIndex: widget.initialTab.clamp(0, 3));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF090A0C),
        appBar: AppBar(
          backgroundColor: const Color(0xFF090A0C),
          title: const Text('TBT Keşif'),
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Bugün TBT'),
              Tab(text: 'Canlı Harita'),
              Tab(text: 'Karma Keşif'),
              Tab(text: 'Şehirlerim'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: const [
            _TodayTbtTab(),
            _LiveSocialMapTab(),
            _MixedDiscoveryTab(),
            _CityProgressTab(),
          ],
        ),
      );
}

class _TodayTbtTab extends StatelessWidget {
  const _TodayTbtTab();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final postCutoff = Timestamp.fromDate(now.subtract(const Duration(hours: 12)));
    final eventEnd = Timestamp.fromDate(now.add(const Duration(hours: 24)));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).limit(80).snapshots(),
      builder: (context, posts) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('social_events').orderBy('startsAt').limit(80).snapshots(),
        builder: (context, events) {
          final recent = (posts.data?.docs ?? const []).where((d) {
            final t = d.data()['createdAt'];
            return t is Timestamp && t.compareTo(postCutoff) >= 0;
          }).toList();
          final upcoming = (events.data?.docs ?? const []).where((d) {
            final t = d.data()['startsAt'];
            return t is Timestamp && t.toDate().isAfter(now) && t.compareTo(eventEnd) <= 0;
          }).toList();
          final spots = <String, int>{};
          for (final d in recent) {
            final s = (d.data()['spotName'] ?? '').toString().trim();
            if (s.isNotEmpty) spots[s] = (spots[s] ?? 0) + 1;
          }
          final trending = spots.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
            children: [
              const Text('Bugün TBT', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text('${_dayName(now.weekday)} • Çevrende ve toplulukta öne çıkanlar', style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _MetricCard(icon: Icons.photo_library_rounded, value: '${recent.length}', label: 'son 12 saatte paylaşım')),
                const SizedBox(width: 10),
                Expanded(child: _MetricCard(icon: Icons.event_available_rounded, value: '${upcoming.length}', label: '24 saatte etkinlik')),
              ]),
              const SizedBox(height: 16),
              _ActionCard(
                icon: Icons.radar_rounded,
                title: 'Şu an hareket nerede?',
                subtitle: 'Canlı haritada etkinlikleri ve topluluk sinyallerini gör.',
                onTap: () => DefaultTabController.of(context),
              ),
              const SizedBox(height: 16),
              const _SectionTitle('Bugün yükselen yerler'),
              const SizedBox(height: 8),
              if (trending.isEmpty)
                const _Empty('Bugün henüz konum etiketli yeterli paylaşım yok.')
              else
                ...trending.take(5).map((e) => _SimpleTile(icon: Icons.local_fire_department_rounded, title: e.key, subtitle: '${e.value} yeni paylaşım')),
              const SizedBox(height: 16),
              const _SectionTitle('Bugün / yarın'),
              const SizedBox(height: 8),
              if (upcoming.isEmpty)
                const _Empty('Önümüzdeki 24 saatte herkese açık etkinlik görünmüyor.')
              else
                ...upcoming.take(6).map((d) {
                  final data = d.data();
                  final t = data['startsAt'];
                  final date = t is Timestamp ? t.toDate().toLocal() : null;
                  return _SimpleTile(
                    icon: Icons.event_rounded,
                    title: (data['title'] ?? 'Etkinlik').toString(),
                    subtitle: date == null ? '' : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} • ${(data['locationLabel'] ?? data['city'] ?? '').toString()}',
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  static String _dayName(int d) => const ['Pazartesi','Salı','Çarşamba','Perşembe','Cuma','Cumartesi','Pazar'][d - 1];
}

class _LiveSocialMapTab extends StatelessWidget {
  const _LiveSocialMapTab();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final recent = now.subtract(const Duration(hours: 6));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('social_events').orderBy('startsAt').limit(120).snapshots(),
      builder: (context, eventSnapshot) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).limit(100).snapshots(),
        builder: (context, postSnapshot) {
          final markers = <Marker>{};
          for (final doc in eventSnapshot.data?.docs ?? const []) {
            final d = doc.data();
            final lat = (d['latitude'] as num?)?.toDouble();
            final lng = (d['longitude'] as num?)?.toDouble();
            final starts = d['startsAt'];
            if (lat == null || lng == null || starts is! Timestamp || starts.toDate().isBefore(now.subtract(const Duration(hours: 1)))) continue;
            markers.add(Marker(
              markerId: MarkerId('event_${doc.id}'),
              position: LatLng(lat, lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
              infoWindow: InfoWindow(title: (d['title'] ?? 'Etkinlik').toString(), snippet: 'Canlı etkinlik sinyali'),
            ));
          }
          for (final doc in postSnapshot.data?.docs ?? const []) {
            final d = doc.data();
            final t = d['createdAt'];
            final lat = (d['latitude'] as num?)?.toDouble();
            final lng = (d['longitude'] as num?)?.toDouble();
            if (lat == null || lng == null || t is! Timestamp || t.toDate().isBefore(recent)) continue;
            markers.add(Marker(
              markerId: MarkerId('post_${doc.id}'),
              position: LatLng(lat, lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
              infoWindow: InfoWindow(title: (d['spotName'] ?? 'Yeni paylaşım').toString(), snippet: 'Son 6 saatte topluluk hareketi'),
            ));
          }
          return Stack(children: [
            GoogleMap(
              initialCameraPosition: const CameraPosition(target: LatLng(38.9637, 35.2433), zoom: 5.2),
              markers: markers,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xE6101319), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  const Icon(Icons.radar_rounded, color: Color(0xFF39DDE8)),
                  const SizedBox(width: 9),
                  Expanded(child: Text('${markers.length} canlı topluluk sinyali', style: const TextStyle(fontWeight: FontWeight.w900))),
                  const Text('Kesin kişi konumu gösterilmez', style: TextStyle(color: Colors.white54, fontSize: 9.5)),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _MixedDiscoveryTab extends StatelessWidget {
  const _MixedDiscoveryTab();

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).limit(50).snapshots(),
        builder: (context, posts) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('social_events').orderBy('startsAt').limit(30).snapshots(),
          builder: (context, events) {
            final p = posts.data?.docs ?? const [];
            final e = (events.data?.docs ?? const []).where((d) {
              final t = d.data()['startsAt'];
              return t is Timestamp && t.toDate().isAfter(DateTime.now());
            }).toList();
            final widgets = <Widget>[];
            var ei = 0;
            for (var i = 0; i < p.length && widgets.length < 30; i++) {
              final d = p[i].data();
              widgets.add(_SimpleTile(
                icon: (d['videoUrl'] ?? '').toString().isNotEmpty ? Icons.play_circle_rounded : Icons.photo_rounded,
                title: (d['userName'] ?? 'TBT kullanıcısı').toString(),
                subtitle: (d['spotName'] ?? d['caption'] ?? 'Yeni paylaşım').toString(),
              ));
              if ((i + 1) % 3 == 0 && ei < e.length) {
                final ed = e[ei++].data();
                widgets.add(_SimpleTile(icon: Icons.event_available_rounded, title: (ed['title'] ?? 'Etkinlik').toString(), subtitle: 'Yaklaşan etkinlik • ${(ed['locationLabel'] ?? ed['city'] ?? '').toString()}'));
              }
            }
            if (widgets.isEmpty) return const Center(child: Text('Keşif akışı henüz boş.'));
            return ListView(padding: const EdgeInsets.fromLTRB(14, 16, 14, 30), children: widgets);
          },
        ),
      );
}

class _CityProgressTab extends StatelessWidget {
  const _CityProgressTab();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Şehir keşfini görmek için giriş yap.'));
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, profile) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('posts').where('userId', isEqualTo: uid).limit(120).snapshots(),
        builder: (context, posts) {
          final data = profile.data?.data() ?? const <String, dynamic>{};
          final configured = <String>{};
          final rawCities = data['visitedCities'];
          if (rawCities is Iterable) configured.addAll(rawCities.map((e) => e.toString().trim()).where((e) => e.isNotEmpty));
          final cityCounts = <String, int>{};
          final uniqueSpots = <String>{};
          for (final doc in posts.data?.docs ?? const []) {
            final d = doc.data();
            final city = (d['city'] ?? '').toString().trim();
            final spot = (d['spotName'] ?? '').toString().trim();
            if (city.isNotEmpty) {
              configured.add(city);
              cityCounts[city] = (cityCounts[city] ?? 0) + 1;
            }
            if (spot.isNotEmpty) uniqueSpots.add(spot);
          }
          final list = configured.toList()..sort();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
            children: [
              const Text('Keşif Haritan', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text('${list.length} şehir • ${uniqueSpots.length} farklı nokta', style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 18),
              if (list.isEmpty)
                const _Empty('Paylaşımlarına şehir/konum ekledikçe keşif haritan burada oluşacak.')
              else
                ...list.map((city) {
                  final count = cityCounts[city] ?? 0;
                  final progress = (count / 10).clamp(0.05, 1.0);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFF151922), borderRadius: BorderRadius.circular(17)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Expanded(child: Text(city, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))), Text('$count paylaşım', style: const TextStyle(color: Colors.white54, fontSize: 11))]),
                      const SizedBox(height: 9),
                      LinearProgressIndicator(value: progress, minHeight: 7, borderRadius: BorderRadius.circular(999)),
                    ]),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon; final String value; final String label;
  const _MetricCard({required this.icon, required this.value, required this.label});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF151922), borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: const Color(0xFF39DDE8)), const SizedBox(height: 10), Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11))]));
}

class _SectionTitle extends StatelessWidget { final String text; const _SectionTitle(this.text); @override Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)); }
class _Empty extends StatelessWidget { final String text; const _Empty(this.text); @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF151922), borderRadius: BorderRadius.circular(16)), child: Text(text, style: const TextStyle(color: Colors.white54))); }
class _SimpleTile extends StatelessWidget { final IconData icon; final String title; final String subtitle; const _SimpleTile({required this.icon, required this.title, required this.subtitle}); @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFF151922), borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(icon, color: const Color(0xFFB7BCC2)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)), if (subtitle.isNotEmpty) Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11.5))]))])); }
class _ActionCard extends StatelessWidget { final IconData icon; final String title; final String subtitle; final VoidCallback onTap; const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap}); @override Widget build(BuildContext context) => const SizedBox.shrink(); }
