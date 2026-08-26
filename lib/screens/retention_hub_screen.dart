import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/location_service.dart';
import '../widgets/firebase_media_image.dart';

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
    _tabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
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
        tabAlignment: TabAlignment.start,
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
    final postCutoff = Timestamp.fromDate(
      now.subtract(const Duration(hours: 12)),
    );
    final eventEnd = Timestamp.fromDate(now.add(const Duration(hours: 24)));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(80)
          .snapshots(),
      builder: (context, posts) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('social_events')
                .orderBy('startsAt')
                .limit(80)
                .snapshots(),
            builder: (context, events) {
              final recent = (posts.data?.docs ?? const []).where((d) {
                final t = d.data()['createdAt'];
                return t is Timestamp && t.compareTo(postCutoff) >= 0;
              }).toList();
              final upcoming = (events.data?.docs ?? const []).where((d) {
                final t = d.data()['startsAt'];
                return t is Timestamp &&
                    t.toDate().isAfter(now) &&
                    t.compareTo(eventEnd) <= 0;
              }).toList();
              final spots = <String, int>{};
              for (final d in recent) {
                final s = (d.data()['spotName'] ?? '').toString().trim();
                if (s.isNotEmpty) spots[s] = (spots[s] ?? 0) + 1;
              }
              final trending = spots.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                children: [
                  const Text(
                    'Bugün TBT',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_dayName(now.weekday)} • Bugünün öne çıkanları',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.photo_library_rounded,
                          value: '${recent.length}',
                          label: 'son 12 saatte',
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.event_available_rounded,
                          value: '${upcoming.length}',
                          label: '24 saatte etkinlik',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _SectionTitle('Yükselen yerler'),
                  const SizedBox(height: 8),
                  if (trending.isEmpty)
                    const _Empty(
                      'Bugün henüz konum etiketli yeterli paylaşım yok.',
                    )
                  else
                    ...trending
                        .take(5)
                        .map(
                          (e) => _SimpleTile(
                            icon: Icons.local_fire_department_rounded,
                            title: e.key,
                            subtitle: '${e.value} yeni paylaşım',
                          ),
                        ),
                  const SizedBox(height: 18),
                  const _SectionTitle('Bugün / yarın'),
                  const SizedBox(height: 8),
                  if (upcoming.isEmpty)
                    const _Empty(
                      'Önümüzdeki 24 saatte herkese açık etkinlik görünmüyor.',
                    )
                  else
                    ...upcoming.take(6).map((d) {
                      final x = d.data();
                      final t = x['startsAt'];
                      final date = t is Timestamp ? t.toDate().toLocal() : null;
                      final place =
                          [x['locationLabel'], x['venueName'], x['city']]
                              .map((e) => (e ?? '').toString().trim())
                              .firstWhere(
                                (e) => e.isNotEmpty,
                                orElse: () => '',
                              );
                      return _SimpleTile(
                        icon: Icons.event_rounded,
                        title: (x['title'] ?? 'Etkinlik').toString(),
                        subtitle: [
                          if (date != null)
                            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                          if (place.isNotEmpty) place,
                        ].join(' • '),
                      );
                    }),
                ],
              );
            },
          ),
    );
  }

  static String _dayName(int d) => const [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ][d - 1];
}

class _LiveSocialMapTab extends StatefulWidget {
  const _LiveSocialMapTab();
  @override
  State<_LiveSocialMapTab> createState() => _LiveSocialMapTabState();
}

class _LiveSocialMapTabState extends State<_LiveSocialMapTab> {
  GoogleMapController? _map;
  LatLng? _user;
  bool _locating = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusUser());
  }

  Future<void> _focusUser() async {
    if (_locating) return;
    setState(() => _locating = true);
    final p = await LocationService.getCurrentPosition();
    if (!mounted) return;
    if (p != null) {
      _user = LatLng(p.latitude, p.longitude);
      await _map?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _user!, zoom: 12.6),
        ),
      );
    }
    setState(() => _locating = false);
  }

  Future<void> _fitSignals(Set<Marker> markers) async {
    if (_user != null || markers.isEmpty || _map == null) return;
    final points = markers.map((m) => m.position).toList();
    if (points.length == 1) {
      await _map!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: points.first, zoom: 11.5),
        ),
      );
      return;
    }
    var minLat = points.first.latitude,
        maxLat = points.first.latitude,
        minLng = points.first.longitude,
        maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    await _map!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        72,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now(), recent = now.subtract(const Duration(hours: 6));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('social_events')
          .orderBy('startsAt')
          .limit(120)
          .snapshots(),
      builder: (context, eventSnapshot) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .orderBy('createdAt', descending: true)
                .limit(100)
                .snapshots(),
            builder: (context, postSnapshot) {
              final markers = <Marker>{};
              for (final doc in eventSnapshot.data?.docs ?? const []) {
                final d = doc.data();
                final lat = (d['latitude'] as num?)?.toDouble(),
                    lng = (d['longitude'] as num?)?.toDouble(),
                    starts = d['startsAt'];
                if (lat == null ||
                    lng == null ||
                    starts is! Timestamp ||
                    starts.toDate().isBefore(
                      now.subtract(const Duration(hours: 1)),
                    ))
                  continue;
                markers.add(
                  Marker(
                    markerId: MarkerId('event_${doc.id}'),
                    position: LatLng(lat, lng),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueViolet,
                    ),
                    infoWindow: InfoWindow(
                      title: (d['title'] ?? 'Etkinlik').toString(),
                      snippet: 'Etkinlik sinyali',
                    ),
                  ),
                );
              }
              for (final doc in postSnapshot.data?.docs ?? const []) {
                final d = doc.data();
                final t = d['createdAt'];
                final lat = (d['latitude'] as num?)?.toDouble(),
                    lng = (d['longitude'] as num?)?.toDouble();
                if (lat == null ||
                    lng == null ||
                    t is! Timestamp ||
                    t.toDate().isBefore(recent))
                  continue;
                markers.add(
                  Marker(
                    markerId: MarkerId('post_${doc.id}'),
                    position: LatLng(lat, lng),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueCyan,
                    ),
                    infoWindow: InfoWindow(
                      title: (d['spotName'] ?? 'Yeni paylaşım').toString(),
                      snippet: 'Son 6 saatte hareket',
                    ),
                  ),
                );
              }
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _fitSignals(markers),
              );
              return Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(39.0, 35.2),
                      zoom: 6.2,
                    ),
                    markers: markers,
                    myLocationEnabled: _user != null,
                    myLocationButtonEnabled: false,
                    zoomGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    rotateGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: false,
                    onMapCreated: (c) {
                      _map = c;
                      if (_user != null)
                        c.moveCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(target: _user!, zoom: 12.6),
                          ),
                        );
                    },
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE6101319),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.radar_rounded,
                            color: Color(0xFF45E7F2),
                            size: 21,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${markers.length} topluluk sinyali',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Text(
                            'Kişi konumu gösterilmez',
                            style: TextStyle(
                              color: Color(0x75FFFFFF),
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 14,
                    bottom: 24,
                    child: FloatingActionButton.small(
                      heroTag: 'live-map-location',
                      onPressed: _focusUser,
                      child: _locating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }
}

class _MixedDiscoveryTab extends StatelessWidget {
  const _MixedDiscoveryTab();
  bool _hasVisual(Map<String, dynamic> d) => [
    'imageUrl',
    'storagePath',
    'thumbnailUrl',
    'thumbnailStoragePath',
  ].any((k) => (d[k] ?? '').toString().trim().isNotEmpty);
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .limit(90)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final docs = (snapshot.data?.docs ?? const [])
              .where((d) => _hasVisual(d.data()))
              .toList();
          if (docs.isEmpty)
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Keşifte gösterecek görsel içerik henüz yok.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            );
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
            itemCount: docs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
              childAspectRatio: .78,
            ),
            itemBuilder: (context, i) {
              final doc = docs[i], d = doc.data();
              return _DiscoveryCard(postId: doc.id, data: d);
            },
          );
        },
      );
}

class _DiscoveryCard extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> data;
  const _DiscoveryCard({required this.postId, required this.data});
  @override
  Widget build(BuildContext context) {
    final video =
        (data['videoUrl'] ?? '').toString().isNotEmpty ||
        (data['mediaType'] ?? '').toString() == 'video';
    final image = (data['thumbnailUrl'] ?? data['imageUrl'] ?? '').toString();
    final path = (data['thumbnailStoragePath'] ?? data['storagePath'] ?? '')
        .toString();
    final user = (data['userName'] ?? 'TBT').toString();
    final spot = (data['spotName'] ?? '').toString();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FirebaseMediaImage(
            imageUrl: image,
            storagePath: path,
            fit: BoxFit.cover,
            placeholder: const ColoredBox(color: Color(0xFF151922)),
            errorWidget: const ColoredBox(
              color: Color(0xFF151922),
              child: Icon(
                Icons.image_not_supported_outlined,
                color: Colors.white24,
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC05060A)],
              ),
            ),
          ),
          if (video)
            const Center(
              child: CircleAvatar(
                radius: 21,
                backgroundColor: Color(0xAA090A0C),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 9,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (spot.isNotEmpty)
                  Text(
                    spot,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CityProgressTab extends StatelessWidget {
  const _CityProgressTab();
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null)
      return const Center(child: Text('Şehir keşfini görmek için giriş yap.'));
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, profile) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('userId', isEqualTo: uid)
                .limit(120)
                .snapshots(),
            builder: (context, posts) {
              final data = profile.data?.data() ?? const <String, dynamic>{};
              final configured = <String>{};
              final raw = data['visitedCities'];
              if (raw is Iterable)
                configured.addAll(
                  raw
                      .map((e) => e.toString().trim())
                      .where((e) => e.isNotEmpty),
                );
              final cityCounts = <String, int>{}, uniqueSpots = <String>{};
              for (final doc in posts.data?.docs ?? const []) {
                final d = doc.data(),
                    city = (d['city'] ?? '').toString().trim(),
                    spot = (d['spotName'] ?? '').toString().trim();
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
                  const Text(
                    'Keşif Haritan',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${list.length} şehir • ${uniqueSpots.length} farklı nokta',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 18),
                  if (list.isEmpty)
                    const _Empty(
                      'Paylaşımlarına şehir/konum ekledikçe keşif haritan burada oluşacak.',
                    )
                  else
                    ...list.map((city) {
                      final count = cityCounts[city] ?? 0,
                          progress = (count / 10).clamp(.05, 1.0);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151922),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    city,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$count paylaşım',
                                  style: const TextStyle(
                                    color: Color(0x75FFFFFF),
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 9),
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ],
                        ),
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
  final IconData icon;
  final String value, label;
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFF151922),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF45E7F2), size: 20),
        const SizedBox(height: 9),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Color(0x75FFFFFF), fontSize: 10.5),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
  );
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF151922),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(text, style: const TextStyle(color: Color(0x80FFFFFF))),
  );
}

class _SimpleTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _SimpleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: const Color(0xFF151922),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFFB7BCC2), size: 20),
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
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0x75FFFFFF),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
