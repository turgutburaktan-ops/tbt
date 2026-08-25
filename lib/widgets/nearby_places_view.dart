import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/nearby_venue.dart';
import '../models/route_place.dart';
import '../services/location_service.dart';
import '../services/nearby_venue_service.dart';
import '../services/route_selection_service.dart';
import '../services/venue_rating_service.dart';
import '../theme/app_theme.dart';
import '../screens/business_profile_screen.dart';
import 'route_selection_button.dart';
import 'venue_reviews_section.dart';

enum _VenueSort { nearest, rating, popular }

class NearbyPlacesView extends StatefulWidget {
  final NearbyVenueCategory category;

  const NearbyPlacesView({super.key, required this.category});

  @override
  State<NearbyPlacesView> createState() => _NearbyPlacesViewState();
}

class _NearbyPlacesViewState extends State<NearbyPlacesView> {
  final _searchController = TextEditingController();
  Position? _position;
  List<NearbyVenue> _venues = const [];
  final Set<String> _selectedIds = <String>{};
  final Set<String> _boostedKeys = <String>{};
  final Map<String, VenueRatingSummary> _ratings = {};
  _VenueSort _sort = _VenueSort.nearest;
  double? _maxDistanceKm;
  bool _loading = true;
  String? _error;

  String _routeId(NearbyVenue venue) => 'venue:${venue.category.name}:${venue.id}';
  String _ratingKey(NearbyVenue venue) => '${venue.category.name}:${venue.id}';
  String _businessKey(NearbyVenue venue) => '${venue.category.name}:${venue.id}';
  bool _isBoosted(NearbyVenue venue) => _boostedKeys.contains(_businessKey(venue));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant NearbyPlacesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) {
      _searchController.clear();
      _ratings.clear();
      _boostedKeys.clear();
      _sort = _VenueSort.nearest;
      _maxDistanceKm = null;
      _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Set<String>> _loadBoostedKeys(List<NearbyVenue> venues) async {
    final keys = venues.map(_businessKey).toSet().toList();
    if (keys.isEmpty) return <String>{};
    final boosted = <String>{};
    final now = DateTime.now();
    for (var offset = 0; offset < keys.length; offset += 30) {
      final end = math.min(offset + 30, keys.length);
      final chunk = keys.sublist(offset, end);
      try {
        final snap = await FirebaseFirestore.instance
            .collection('business_venues')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final data = doc.data();
          final until = data['boostActiveUntil'];
          if (data['boostActive'] == true &&
              until is Timestamp &&
              until.toDate().isAfter(now)) {
            boosted.add(doc.id);
          }
        }
      } catch (_) {
        // Boost keşfi yüklenemese bile normal mekan listesini göstermeye devam et.
      }
    }
    return boosted;
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final position = await LocationService.getCurrentPosition();
      if (position == null) throw const _LocationUnavailable();
      final venues = await NearbyVenueService.instance.nearby(
        category: widget.category,
        latitude: position.latitude,
        longitude: position.longitude,
        forceRefresh: forceRefresh,
      );
      final boosted = await _loadBoostedKeys(venues);
      venues.sort((a, b) {
        final aBoost = boosted.contains(_businessKey(a));
        final bBoost = boosted.contains(_businessKey(b));
        if (aBoost != bBoost) return aBoost ? -1 : 1;
        return _distance(position, a).compareTo(_distance(position, b));
      });
      if (!mounted) return;
      setState(() {
        _position = position;
        _venues = venues;
        _boostedKeys
          ..clear()
          ..addAll(boosted);
        _selectedIds
          ..clear()
          ..addAll(
            venues
                .where((v) => RouteSelectionService.instance.contains(_routeId(v)))
                .map(_routeId),
          );
        _loading = false;
      });
      _loadRatings(venues);
    } on _LocationUnavailable {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Yakındaki mekanlar için konumu ve konum iznini aç.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Mekanlar şu anda yüklenemedi. Bağlantını kontrol edip tekrar dene.';
      });
    }
  }

  Future<void> _loadRatings(List<NearbyVenue> venues) async {
    for (final venue in venues.take(120)) {
      try {
        final summary = await VenueRatingService.instance.summary(
          venue.category.name,
          venue.id,
        );
        if (!mounted) return;
        setState(() => _ratings[_ratingKey(venue)] = summary);
      } catch (_) {}
    }
  }

  double _distance(Position position, NearbyVenue venue) => Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        venue.latitude,
        venue.longitude,
      );

  double _distanceKm(NearbyVenue venue) {
    final position = _position;
    if (position == null) return double.infinity;
    return _distance(position, venue) / 1000;
  }

  String _distanceLabel(NearbyVenue venue) {
    final position = _position;
    if (position == null) return '';
    final meters = _distance(position, venue);
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }

  List<NearbyVenue> get _visibleVenues {
    final query = _searchController.text.trim().toLowerCase();
    final items = _venues.where((venue) {
      if (_maxDistanceKm != null && _distanceKm(venue) > _maxDistanceKm!) return false;
      if (query.isEmpty) return true;
      return '${venue.name} ${venue.address}'.toLowerCase().contains(query);
    }).toList();
    final position = _position;
    items.sort((a, b) {
      final aBoost = _isBoosted(a);
      final bBoost = _isBoosted(b);
      if (aBoost != bBoost) return aBoost ? -1 : 1;
      final ar = _ratings[_ratingKey(a)] ?? VenueRatingSummary.empty;
      final br = _ratings[_ratingKey(b)] ?? VenueRatingSummary.empty;
      switch (_sort) {
        case _VenueSort.rating:
          final c = br.average.compareTo(ar.average);
          if (c != 0) return c;
          return br.count.compareTo(ar.count);
        case _VenueSort.popular:
          final ap = ar.average * math.log(ar.count + 1);
          final bp = br.average * math.log(br.count + 1);
          return bp.compareTo(ap);
        case _VenueSort.nearest:
          if (position == null) return 0;
          return _distance(position, a).compareTo(_distance(position, b));
      }
    });
    return items;
  }

  List<NearbyVenue> get _featuredVenues {
    final candidates = _venues.where((v) => _distanceKm(v) <= 5).toList();
    candidates.sort((a, b) {
      final ar = _ratings[_ratingKey(a)] ?? VenueRatingSummary.empty;
      final br = _ratings[_ratingKey(b)] ?? VenueRatingSummary.empty;
      final aScore = ar.average * math.log(ar.count + 2) - (_distanceKm(a) * .08) + (_isBoosted(a) ? 100 : 0);
      final bScore = br.average * math.log(br.count + 2) - (_distanceKm(b) * .08) + (_isBoosted(b) ? 100 : 0);
      return bScore.compareTo(aScore);
    });
    return candidates.take(6).toList();
  }

  List<NearbyVenue> get _communityFavorites {
    final items = _venues.where((venue) {
      final rating = _ratings[_ratingKey(venue)] ?? VenueRatingSummary.empty;
      return rating.count >= 2 && rating.average >= 4;
    }).toList();
    items.sort((a, b) {
      final ar = _ratings[_ratingKey(a)] ?? VenueRatingSummary.empty;
      final br = _ratings[_ratingKey(b)] ?? VenueRatingSummary.empty;
      final ratingCompare = br.average.compareTo(ar.average);
      return ratingCompare != 0 ? ratingCompare : br.count.compareTo(ar.count);
    });
    return items.take(6).toList();
  }

  Future<void> _openDirections(NearbyVenue venue) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${venue.latitude},${venue.longitude}',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harita uygulaması açılamadı.')));
    }
  }

  void _openBusinessProfile(NearbyVenue venue) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessProfileScreen(
          venue: venue,
          distance: _distanceLabel(venue),
          rating: _ratings[_ratingKey(venue)] ?? VenueRatingSummary.empty,
        ),
      ),
    );
  }

  Future<void> _openReviews(NearbyVenue venue) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      venue.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                child: VenueReviewsSection(
                  category: venue.category.name,
                  venueId: venue.id,
                  venueName: venue.name,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    try {
      final summary = await VenueRatingService.instance.summary(venue.category.name, venue.id);
      if (mounted) setState(() => _ratings[_ratingKey(venue)] = summary);
    } catch (_) {}
  }

  void _toggleSelection(NearbyVenue venue) {
    final id = _routeId(venue);
    RouteSelectionService.instance.toggle(
      RoutePlace(
        id: id,
        name: venue.name,
        category: venue.category.label,
        latitude: venue.latitude,
        longitude: venue.longitude,
      ),
    );
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  void _openMap() {
    final position = _position;
    if (position == null || _venues.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _NearbyVenueMapScreen(
          category: widget.category,
          position: position,
          venues: _venues,
        ),
      ),
    );
  }

  Future<void> _pickForMe() async {
    final pool = _featuredVenues.isNotEmpty ? _featuredVenues : _visibleVenues.take(10).toList();
    if (pool.isEmpty) return;
    final picked = pool[math.Random().nextInt(pool.length)];
    final rating = _ratings[_ratingKey(picked)] ?? VenueRatingSummary.empty;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('🎲 Bugünün seçimi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text(picked.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            if (_isBoosted(picked)) ...[
              const SizedBox(height: 5),
              const _BoostBadge(),
            ],
            const SizedBox(height: 5),
            Text(
              '${_distanceLabel(picked)}${rating.count > 0 ? ' • ⭐ ${rating.average.toStringAsFixed(1)}' : ''}',
              style: const TextStyle(color: Colors.white60),
            ),
            if (picked.address.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(picked.address, style: const TextStyle(color: Colors.white54)),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _openReviews(picked);
                    },
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Yorumlar'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _openDirections(picked);
                    },
                    icon: const Icon(Icons.directions_rounded),
                    label: const Text('Hadi Gidelim'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _MessageState(
        icon: Icons.location_off_outlined,
        message: _error!,
        actionLabel: 'Tekrar Dene',
        onAction: _load,
      );
    }

    final venues = _visibleVenues;
    final featured = _featuredVenues;
    final favorites = _communityFavorites;
    return RefreshIndicator(
      color: AppColors.cyan,
      onRefresh: () => _load(forceRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '${widget.category.label} içinde ara',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              IconButton(
                tooltip: 'Haritada göster',
                onPressed: _venues.isEmpty ? null : _openMap,
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  backgroundColor: AppColors.surfaceAlt,
                  side: const BorderSide(color: AppColors.border),
                ),
                icon: const Icon(Icons.map_outlined, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _DiscoveryHero(
            category: widget.category,
            venueCount: _venues.length,
            onPick: _pickForMe,
            onMap: _openMap,
          ),
          if (featured.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionTitle(
              title: '✨ Yakınında öne çıkanlar',
              subtitle: 'Yakınlık, topluluk puanı ve aktif Boost görünürlüğüne göre',
            ),
            const SizedBox(height: 9),
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: featured.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final venue = featured[index];
                  return _FeaturedVenueCard(
                    venue: venue,
                    rating: _ratings[_ratingKey(venue)] ?? VenueRatingSummary.empty,
                    distance: _distanceLabel(venue),
                    boosted: _isBoosted(venue),
                    onTap: () => _openBusinessProfile(venue),
                  );
                },
              ),
            ),
          ],
          if (favorites.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionTitle(
              title: '🔥 Topluluk favorileri',
              subtitle: 'TBT kullanıcılarının yüksek puan verdiği yerler',
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: favorites.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (_, index) {
                  final venue = favorites[index];
                  final rating = _ratings[_ratingKey(venue)]!;
                  return ActionChip(
                    avatar: const Icon(Icons.star_rounded, size: 16),
                    label: Text('${venue.name} • ${rating.average.toStringAsFixed(1)}'),
                    onPressed: () => _openBusinessProfile(venue),
                  );
                },
              ),
            ),
          ],
          const RouteSelectionButton(padding: EdgeInsets.fromLTRB(0, 12, 0, 0)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _DistanceChip(label: 'Tümü', selected: _maxDistanceKm == null, onTap: () => setState(() => _maxDistanceKm = null)),
                const SizedBox(width: 6),
                _DistanceChip(label: '1 km', selected: _maxDistanceKm == 1, onTap: () => setState(() => _maxDistanceKm = 1)),
                const SizedBox(width: 6),
                _DistanceChip(label: '3 km', selected: _maxDistanceKm == 3, onTap: () => setState(() => _maxDistanceKm = 3)),
                const SizedBox(width: 6),
                _DistanceChip(label: '10 km', selected: _maxDistanceKm == 10, onTap: () => setState(() => _maxDistanceKm = 10)),
              ],
            ),
          ),
          const SizedBox(height: 9),
          SegmentedButton<_VenueSort>(
            segments: const [
              ButtonSegment(value: _VenueSort.nearest, label: Text('Yakın')),
              ButtonSegment(value: _VenueSort.rating, label: Text('Puan')),
              ButtonSegment(value: _VenueSort.popular, label: Text('Popüler')),
            ],
            selected: {_sort},
            showSelectedIcon: false,
            onSelectionChanged: (value) => setState(() => _sort = value.first),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 12, 2, 7),
            child: Row(
              children: [
                const Expanded(child: Text('Yakındaki mekanlar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                Text('${venues.length} mekan', style: const TextStyle(color: Color(0x75FFFFFF), fontSize: 11.5)),
              ],
            ),
          ),
          if (venues.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: _MessageState(icon: Icons.place_outlined, message: 'Bu bölgede eşleşen mekan bulunamadı.'),
            )
          else
            ...venues.map((venue) {
              final rating = _ratings[_ratingKey(venue)] ?? VenueRatingSummary.empty;
              return _VenueCard(
                venue: venue,
                rating: rating,
                distance: _distanceLabel(venue),
                boosted: _isBoosted(venue),
                onDirections: () => _openDirections(venue),
                onReviews: () => _openReviews(venue),
                selected: _selectedIds.contains(_routeId(venue)),
                onSelected: () => _toggleSelection(venue),
                onOpenProfile: () => _openBusinessProfile(venue),
              );
            }),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse('https://www.openstreetmap.org/copyright'),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('Mekan verisi © OpenStreetMap katkıda bulunanlar', style: TextStyle(color: Color(0x52FFFFFF), fontSize: 10.5)),
          ),
        ],
      ),
    );
  }
}

class _BoostBadge extends StatelessWidget {
  const _BoostBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.violetBright.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.violetBright.withValues(alpha: .32)),
        ),
        child: const Text('Öne Çıkan', style: TextStyle(color: AppColors.violetBright, fontSize: 9.5, fontWeight: FontWeight.w900)),
      );
}

class _DiscoveryHero extends StatelessWidget {
  final NearbyVenueCategory category;
  final int venueCount;
  final VoidCallback onPick;
  final VoidCallback onMap;

  const _DiscoveryHero({required this.category, required this.venueCount, required this.onPick, required this.onMap});

  String get _question => switch (category) {
        NearbyVenueCategory.cafe => 'Kahve için nereye gidelim?',
        NearbyVenueCategory.dining => 'Bugün nerede yiyelim?',
        NearbyVenueCategory.hotel => 'Yakında nerede kalalım?',
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(colors: [Color(0xFF151B24), Color(0xFF191226)]),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_question, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              'Yakınında $venueCount seçenek var. Kararsızsan TBT senin için seçsin.',
              style: const TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.35),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: venueCount == 0 ? null : onPick,
                    icon: const Icon(Icons.casino_outlined, size: 18),
                    label: const Text('Bana Mekan Seç'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: venueCount == 0 ? null : onMap,
                  icon: const Icon(Icons.radar_rounded, size: 18),
                  label: const Text('Harita'),
                ),
              ],
            ),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
        ],
      );
}

class _DistanceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DistanceChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
}

class _FeaturedVenueCard extends StatelessWidget {
  final NearbyVenue venue;
  final VenueRatingSummary rating;
  final String distance;
  final bool boosted;
  final VoidCallback onTap;

  const _FeaturedVenueCard({required this.venue, required this.rating, required this.distance, required this.boosted, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: boosted ? AppColors.violetBright.withValues(alpha: .45) : AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place_rounded, color: AppColors.cyan, size: 18),
                      const Spacer(),
                      Text(distance, style: const TextStyle(color: AppColors.cyan, fontSize: 10, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  if (boosted) ...[
                    const SizedBox(height: 5),
                    const _BoostBadge(),
                  ],
                  const SizedBox(height: 7),
                  Text(
                    venue.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  Text(
                    rating.count == 0 ? 'Henüz TBT puanı yok' : '⭐ ${rating.average.toStringAsFixed(1)} • ${rating.count} yorum',
                    maxLines: 1,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _VenueCard extends StatelessWidget {
  final NearbyVenue venue;
  final VenueRatingSummary rating;
  final String distance;
  final bool boosted;
  final VoidCallback onDirections;
  final VoidCallback onReviews;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback onOpenProfile;

  const _VenueCard({
    required this.venue,
    required this.rating,
    required this.distance,
    required this.boosted,
    required this.onDirections,
    required this.onReviews,
    required this.selected,
    required this.onSelected,
    required this.onOpenProfile,
  });

  IconData get _icon => switch (venue.category) {
        NearbyVenueCategory.dining => Icons.restaurant_rounded,
        NearbyVenueCategory.cafe => Icons.local_cafe_rounded,
        NearbyVenueCategory.hotel => Icons.hotel_rounded,
      };

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onOpenProfile,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: boosted
                  ? AppColors.violetBright.withValues(alpha: .45)
                  : selected
                      ? AppColors.cyan.withValues(alpha: .40)
                      : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppColors.surfaceStrong, borderRadius: BorderRadius.circular(12)),
                child: Icon(_icon, size: 21, color: AppColors.cyan),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (boosted) ...[
                      const _BoostBadge(),
                      const SizedBox(height: 5),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            venue.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, height: 1.15),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(distance, style: const TextStyle(color: AppColors.cyan, fontSize: 10.5, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: onReviews,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 17, color: Color(0xFFFFC857)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                rating.count == 0 ? 'İlk puanı ve yorumu sen ver' : '${rating.average.toStringAsFixed(1)} · ${rating.count} değerlendirme',
                                style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      venue.address.isEmpty ? venue.category.label : '${venue.category.label}  •  ${venue.address}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0x75FFFFFF), fontSize: 11),
                    ),
                    if (venue.openingHours.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        venue.openingHours,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0x52FFFFFF), fontSize: 10),
                      ),
                    ],
                    const SizedBox(height: 3),
                    TextButton.icon(
                      onPressed: onReviews,
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                      icon: const Icon(Icons.rate_review_outlined, size: 16),
                      label: const Text('Yorumları gör / yorum yap'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: selected ? 'Rotadan çıkar' : 'Rotaya ekle',
                    onPressed: onSelected,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(38, 38),
                      backgroundColor: selected ? AppColors.cyan : AppColors.surfaceStrong,
                      foregroundColor: selected ? const Color(0xFF041311) : Colors.white70,
                    ),
                    icon: Icon(selected ? Icons.check_rounded : Icons.add_rounded, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Yol tarifi',
                    onPressed: onDirections,
                    style: IconButton.styleFrom(minimumSize: const Size(38, 38), foregroundColor: const Color(0x75FFFFFF)),
                    icon: const Icon(Icons.directions_rounded, size: 19),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageState({required this.icon, required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
                child: Icon(icon, size: 26, color: Colors.white38),
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.4)),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 14),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      );
}

class _NearbyVenueMapScreen extends StatelessWidget {
  final NearbyVenueCategory category;
  final Position position;
  final List<NearbyVenue> venues;

  const _NearbyVenueMapScreen({required this.category, required this.position, required this.venues});

  @override
  Widget build(BuildContext context) {
    final markers = venues
        .map(
          (venue) => Marker(
            markerId: MarkerId('venue-${venue.id}'),
            position: LatLng(venue.latitude, venue.longitude),
            infoWindow: InfoWindow(
              title: venue.name,
              snippet: venue.address.isEmpty ? category.label : venue.address,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BusinessProfileScreen(venue: venue)),
              ),
            ),
          ),
        )
        .toSet();
    return Scaffold(
      appBar: AppBar(title: Text('${category.label} Haritası')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 13),
        markers: markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        mapToolbarEnabled: true,
      ),
    );
  }
}

class _LocationUnavailable implements Exception {
  const _LocationUnavailable();
}
