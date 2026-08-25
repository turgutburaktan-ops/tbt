import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/nearby_venue.dart';
import '../services/business_service.dart';
import '../services/venue_rating_service.dart';
import '../theme/app_theme.dart';
import '../widgets/firebase_media_image.dart';
import '../widgets/venue_reviews_section.dart';
import 'business_hub_screen.dart';
import 'post_detail_screen.dart';

class BusinessProfileScreen extends StatelessWidget {
  final NearbyVenue venue;
  final String distance;
  final VenueRatingSummary rating;

  const BusinessProfileScreen({
    super.key,
    required this.venue,
    this.distance = '',
    this.rating = VenueRatingSummary.empty,
  });

  String get _key => BusinessService.instance.venueKey(
        venue.category.name,
        venue.id,
      );

  IconData get _icon => switch (venue.category) {
        NearbyVenueCategory.cafe => Icons.local_cafe_rounded,
        NearbyVenueCategory.dining => Icons.restaurant_rounded,
        NearbyVenueCategory.hotel => Icons.hotel_rounded,
      };

  String get _menuLabel => venue.category == NearbyVenueCategory.hotel
      ? 'Odalar & Hizmetler'
      : 'Menü';

  Future<void> _launch(BuildContext context, Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bağlantı açılamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final venueRef = FirebaseFirestore.instance.collection('business_venues').doc(_key);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: venueRef.snapshots(),
      builder: (context, snapshot) {
        final profile = snapshot.data?.data() ?? const <String, dynamic>{};
        final verified = profile['verified'] == true;
        final ownerUid = (profile['ownerUid'] ?? '').toString();
        final isOwner = verified && ownerUid.isNotEmpty &&
            FirebaseAuth.instance.currentUser?.uid == ownerUid;
        final coverUrl = (profile['coverUrl'] ?? '').toString();
        final logoUrl = (profile['logoUrl'] ?? '').toString();
        final managedPhone = (profile['phone'] ?? '').toString().trim();
        final managedWebsite = (profile['website'] ?? '').toString().trim();
        final phone = managedPhone.isNotEmpty ? managedPhone : venue.phone.trim();
        final website = managedWebsite.isNotEmpty ? managedWebsite : venue.website.trim();

        return DefaultTabController(
          length: 5,
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: NestedScrollView(
              headerSliverBuilder: (context, innerScrolled) => [
                SliverAppBar(
                  expandedHeight: 260,
                  pinned: true,
                  stretch: true,
                  title: innerScrolled ? Text(venue.name) : null,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _BusinessHeader(
                      venue: venue,
                      coverUrl: coverUrl,
                      logoUrl: logoUrl,
                      verified: verified,
                      icon: _icon,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                              venue.name,
                              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (verified)
                            const Icon(Icons.verified_rounded, color: AppColors.cyan, size: 22),
                        ]),
                        const SizedBox(height: 5),
                        Text(
                          [
                            venue.category.label,
                            if (distance.isNotEmpty) distance,
                            if (rating.count > 0) '⭐ ${rating.average.toStringAsFixed(1)} (${rating.count})',
                          ].join('  •  '),
                          style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700),
                        ),
                        if (venue.address.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(venue.address, style: const TextStyle(color: Colors.white54)),
                        ],
                        const SizedBox(height: 14),
                        Row(children: [
                          _QuickAction(
                            icon: Icons.directions_rounded,
                            label: 'Yol tarifi',
                            onTap: () => _launch(
                              context,
                              Uri.https('www.google.com', '/maps/dir/', {
                                'api': '1',
                                'destination': '${venue.latitude},${venue.longitude}',
                              }),
                            ),
                          ),
                          _QuickAction(
                            icon: Icons.call_outlined,
                            label: 'Ara',
                            enabled: phone.isNotEmpty,
                            onTap: () => _launch(context, Uri(scheme: 'tel', path: phone)),
                          ),
                          _QuickAction(
                            icon: Icons.language_rounded,
                            label: 'Web',
                            enabled: website.isNotEmpty,
                            onTap: () {
                              final uri = Uri.tryParse(website.startsWith('http') ? website : 'https://$website');
                              if (uri != null) _launch(context, uri);
                            },
                          ),
                          _QuickAction(
                            icon: isOwner ? Icons.dashboard_customize_outlined : Icons.storefront_outlined,
                            label: isOwner ? 'Yönet' : 'Benim',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BusinessHubScreen(
                                  initialCategory: venue.category.name,
                                  initialVenueId: venue.id,
                                  initialVenueName: venue.name,
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabHeaderDelegate(
                    TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        const Tab(text: 'Genel'),
                        Tab(text: _menuLabel),
                        const Tab(text: 'Kampanyalar'),
                        const Tab(text: 'Etkinlikler'),
                        const Tab(text: 'Paylaşımlar'),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(children: [
                _OverviewTab(venue: venue, profile: profile, venueKey: _key),
                _BusinessCollectionTab(
                  stream: venueRef.collection('menu').snapshots(),
                  emptyIcon: venue.category == NearbyVenueCategory.hotel
                      ? Icons.bed_outlined
                      : Icons.restaurant_menu_rounded,
                  emptyText: venue.category == NearbyVenueCategory.hotel
                      ? 'Oda ve hizmet bilgisi henüz eklenmedi.'
                      : 'Menü henüz eklenmedi.',
                  builder: (data) => _MenuCard(data: data),
                ),
                _BusinessCollectionTab(
                  stream: venueRef.collection('campaigns').snapshots(),
                  emptyIcon: Icons.local_offer_outlined,
                  emptyText: 'Aktif kampanya bulunmuyor.',
                  activeOnly: true,
                  builder: (data) => _CampaignCard(data: data),
                ),
                _BusinessCollectionTab(
                  stream: venueRef.collection('program').snapshots(),
                  emptyIcon: Icons.event_outlined,
                  emptyText: 'Yaklaşan etkinlik veya program bulunmuyor.',
                  activeOnly: true,
                  builder: (data) => _ProgramCard(data: data),
                ),
                _BusinessPostsTab(venueKey: _key),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _BusinessHeader extends StatelessWidget {
  final NearbyVenue venue;
  final String coverUrl;
  final String logoUrl;
  final bool verified;
  final IconData icon;
  const _BusinessHeader({required this.venue, required this.coverUrl, required this.logoUrl, required this.verified, required this.icon});

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF10252B), Color(0xFF241735)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        if (coverUrl.isNotEmpty)
          FirebaseMediaImage(imageUrl: coverUrl, fit: BoxFit.cover),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Color(0xD905060A)], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
        Positioned(
          left: 18,
          bottom: 16,
          child: Container(
            width: 76,
            height: 76,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: AppColors.surfaceStrong, borderRadius: BorderRadius.circular(22), border: Border.all(color: verified ? AppColors.cyan : Colors.white24, width: 2)),
            child: logoUrl.isEmpty ? Icon(icon, size: 36, color: AppColors.cyan) : FirebaseMediaImage(imageUrl: logoUrl, fit: BoxFit.cover),
          ),
        ),
      ]);
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  const _QuickAction({required this.icon, required this.label, required this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(children: [
              Icon(icon, color: enabled ? AppColors.cyan : Colors.white24),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: enabled ? Colors.white70 : Colors.white24)),
            ]),
          ),
        ),
      );
}

class _OverviewTab extends StatelessWidget {
  final NearbyVenue venue;
  final Map<String, dynamic> profile;
  final String venueKey;
  const _OverviewTab({required this.venue, required this.profile, required this.venueKey});

  @override
  Widget build(BuildContext context) {
    final managedHours = (profile['openingHours'] ?? '').toString().trim();
    final openingHours = managedHours.isNotEmpty ? managedHours : venue.openingHours;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
      children: [
        _InfoCard(icon: Icons.schedule_rounded, title: 'Çalışma saatleri', value: openingHours.isEmpty ? 'İşletme henüz çalışma saati eklemedi.' : openingHours),
        if ((profile['description'] ?? '').toString().isNotEmpty)
          _InfoCard(icon: Icons.info_outline_rounded, title: 'Hakkında', value: profile['description'].toString()),
        const SizedBox(height: 8),
        const Text('Puanlar ve yorumlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        VenueReviewsSection(category: venue.category.name, venueId: venue.id, venueName: venue.name),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _InfoCard({required this.icon, required this.title, required this.value});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: AppColors.cyan),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white60, height: 1.4)),
            ])),
          ]),
        ),
      );
}

class _BusinessCollectionTab extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final Widget Function(Map<String, dynamic>) builder;
  final IconData emptyIcon;
  final String emptyText;
  final bool activeOnly;
  const _BusinessCollectionTab({required this.stream, required this.builder, required this.emptyIcon, required this.emptyText, this.activeOnly = false});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const _EmptyState(icon: Icons.cloud_off_outlined, text: 'Bilgiler yüklenemedi.');
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs.where((doc) {
            final d = doc.data();
            if (activeOnly && d['active'] == false) return false;
            final end = d['validUntil'] ?? d['startsAt'];
            return end is! Timestamp || end.toDate().isAfter(DateTime.now().subtract(const Duration(hours: 4)));
          }).toList()
            ..sort((a, b) {
              final ad = a.data()['createdAt'] as Timestamp?;
              final bd = b.data()['createdAt'] as Timestamp?;
              return (bd?.millisecondsSinceEpoch ?? 0).compareTo(ad?.millisecondsSinceEpoch ?? 0);
            });
          if (docs.isEmpty) return _EmptyState(icon: emptyIcon, text: emptyText);
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) => builder(docs[index].data()),
          );
        },
      );
}

class _MenuCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MenuCard({required this.data});
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text((data['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text([(data['section'] ?? '').toString(), (data['description'] ?? '').toString()].where((e) => e.isNotEmpty).join('\n')),
          trailing: Text(
            '${(((data['priceMinor'] as num?)?.toInt() ?? 0) / 100).toStringAsFixed(2)} ₺',
            style: const TextStyle(
              color: AppColors.cyan,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
}

class _CampaignCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CampaignCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final until = data['validUntil'] as Timestamp?;
    return Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.local_offer_rounded, color: AppColors.violetBright),
      const SizedBox(height: 8),
      Text((data['title'] ?? '').toString(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      Text((data['description'] ?? '').toString(), style: const TextStyle(color: Colors.white60, height: 1.4)),
      if (until != null) ...[const SizedBox(height: 8), Text('${until.toDate().day}.${until.toDate().month}.${until.toDate().year} tarihine kadar', style: const TextStyle(color: AppColors.cyan, fontSize: 11, fontWeight: FontWeight.w800))],
    ])));
  }
}

class _ProgramCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ProgramCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final starts = data['startsAt'] as Timestamp?;
    final d = starts?.toDate();
    return Card(child: ListTile(
      leading: const Icon(Icons.event_rounded, color: AppColors.cyan),
      title: Text((data['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text([(data['description'] ?? '').toString(), if (d != null) '${d.day}.${d.month}.${d.year} • ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'].where((e) => e.isNotEmpty).join('\n')),
    ));
  }
}

class _BusinessPostsTab extends StatelessWidget {
  final String venueKey;
  const _BusinessPostsTab({required this.venueKey});
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('posts').where('businessVenueKey', isEqualTo: venueKey).limit(60).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs.toList()..sort((a, b) => ((b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0).compareTo((a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0));
          if (docs.isEmpty) return const _EmptyState(icon: Icons.photo_library_outlined, text: 'İşletme henüz fotoğraf veya video paylaşmadı.');
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 30),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 3, mainAxisSpacing: 3),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = {...docs[index].data(), 'id': docs[index].id};
              return InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: data))),
                child: Stack(fit: StackFit.expand, children: [
                  FirebaseMediaImage(imageUrl: (data['imageUrl'] ?? data['thumbnailUrl'] ?? '').toString(), storagePath: (data['storagePath'] ?? data['thumbnailStoragePath'] ?? '').toString()),
                  if ((data['mediaType'] ?? '').toString() == 'video') const Positioned(top: 6, right: 6, child: Icon(Icons.play_circle_fill_rounded, shadows: [Shadow(blurRadius: 5)])),
                ]),
              );
            },
          );
        },
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyState({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 48, color: Colors.white24), const SizedBox(height: 12), Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54))])));
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabHeaderDelegate(this.tabBar);
  @override double get minExtent => tabBar.preferredSize.height;
  @override double get maxExtent => tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => ColoredBox(color: AppColors.background, child: tabBar);
  @override bool shouldRebuild(covariant _TabHeaderDelegate oldDelegate) => false;
}
