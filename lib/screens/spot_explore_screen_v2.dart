import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../data/curated_photo_spots.dart';
import '../data/curated_photo_spots_cities.dart';
import '../data/curated_photo_spots_extra.dart';
import '../data/curated_photo_spots_official_bulk.dart';
import '../data/curated_photo_spots_official_complete.dart';
import '../data/curated_photo_spots_official_routes.dart';
import '../data/curated_photo_spots_regions.dart';
import '../data/curated_photo_spots_verified_expansion.dart';
import '../models/photo_spot.dart';
import '../models/route_place.dart';
import '../services/nationwide_candidate_spot_resolver.dart';
import '../services/route_selection_service.dart';
import '../services/spot_repository.dart';
import '../widgets/route_selection_button.dart';
import '../widgets/spot_image.dart';
import 'spot_detail_screen.dart';

class SpotExploreScreen extends StatefulWidget {
  final bool embedded;

  const SpotExploreScreen({super.key, this.embedded = false});

  @override
  State<SpotExploreScreen> createState() => _SpotExploreScreenState();
}

class _SpotExploreScreenState extends State<SpotExploreScreen> {
  final _searchController = TextEditingController();
  List<PhotoSpot> _all = const [];
  List<PhotoSpot> _visible = const [];
  bool _loading = true;
  Position? _position;
  String _search = '';

  String _routeId(PhotoSpot spot) => 'spot:${spot.id}';

  @override
  void initState() {
    super.initState();
    _loadLocalImmediately();
    _refreshRemote();
    _prepareLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleRoute(PhotoSpot spot) {
    RouteSelectionService.instance.toggle(
      RoutePlace(
        id: _routeId(spot),
        name: spot.name,
        category: 'Gezilecek Yerler',
        latitude: spot.latitude,
        longitude: spot.longitude,
      ),
    );
    setState(() {});
  }

  void _loadLocalImmediately() {
    final byId = <String, PhotoSpot>{};
    for (final group in <List<PhotoSpot>>[
      demoSpots,
      curatedPhotoSpots,
      curatedPhotoSpotsExtra,
      curatedPhotoSpotsCities,
      curatedPhotoSpotsRegions,
      curatedPhotoSpotsOfficialRoutes,
      curatedPhotoSpotsOfficialBulk,
      curatedPhotoSpotsVerifiedExpansion,
      curatedPhotoSpotsOfficialComplete,
    ]) {
      for (final spot in group) {
        byId[spot.id] = spot;
      }
    }
    _all = NationwideCandidateSpotResolver.mergeInto(byId.values.toList());
    _applyFilter();
    _loading = false;
  }

  Future<void> _refreshRemote() async {
    try {
      final remote = await SpotRepository.instance
          .discover()
          .timeout(const Duration(seconds: 4));
      if (!mounted || remote.isEmpty) return;
      _all = remote;
      _applyFilter();
      setState(() {});
    } catch (_) {}
  }

  Future<void> _prepareLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 4));
      if (!mounted) return;
      _position = position;
      _applyFilter();
      setState(() {});
    } catch (_) {}
  }

  void _applyFilter() {
    final key = _search.trim().toLowerCase();
    final next = _all.where((spot) {
      if (key.isEmpty) return true;
      final haystack =
          '${spot.name} ${spot.city} ${spot.category} ${spot.description} ${spot.tags.join(' ')}'
              .toLowerCase();
      return haystack.contains(key);
    }).toList();
    if (_position != null) {
      next.sort((a, b) => _distance(a).compareTo(_distance(b)));
    } else {
      next.sort((a, b) => b.rating.compareTo(a.rating));
    }
    _visible = next;
  }

  double _distance(PhotoSpot spot) {
    final p = _position;
    if (p == null) return double.infinity;
    return Geolocator.distanceBetween(
      p.latitude,
      p.longitude,
      spot.latitude,
      spot.longitude,
    );
  }

  String _distanceLabel(PhotoSpot spot) {
    final meters = _distance(spot);
    if (!meters.isFinite) return '';
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    _loadLocalImmediately();
    setState(() {});
    await _refreshRemote();
    if (mounted) setState(() => _loading = false);
  }

  void _openSpot(PhotoSpot spot) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      color: const Color(0xFFB7BCC2),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (!widget.embedded)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gezilecek Yerler',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _position == null
                          ? 'Gerçek gezi noktalarını keşfet; fotoğraf önerilerini yer detayında gör.'
                          : 'Yakınındaki gezilecek yerlerden başlayarak sıralandı.',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                widget.embedded ? 6 : 0,
                20,
                14,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  _search = value;
                  _applyFilter();
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: 'Yer, şehir veya kategori ara...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xFF121416),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: RouteSelectionButton(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
            ),
          ),
          if (_loading && _visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFB7BCC2)),
              ),
            )
          else if (_visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('Gezilecek yer bulunamadı.')),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
                child: Text(
                  '${_visible.length} gezilecek yer',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: _visible.length,
              itemBuilder: (context, index) {
                final spot = _visible[index];
                final selected =
                    RouteSelectionService.instance.contains(_routeId(spot));
                return _SpotVenueCard(
                  spot: spot,
                  selected: selected,
                  distanceLabel: _distanceLabel(spot),
                  onOpen: () => _openSpot(spot),
                  onToggleRoute: () => _toggleRoute(spot),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ],
      ),
    );
  }
}

class _SpotVenueCard extends StatelessWidget {
  final PhotoSpot spot;
  final bool selected;
  final String distanceLabel;
  final VoidCallback onOpen;
  final VoidCallback onToggleRoute;

  const _SpotVenueCard({
    required this.spot,
    required this.selected,
    required this.distanceLabel,
    required this.onOpen,
    required this.onToggleRoute,
  });

  @override
  Widget build(BuildContext context) {
    final verified = spot.tags.contains('Doğrulanmış');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Card(
        color: const Color(0xFF121416),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(12),
                child: SpotImage(
                  spot: spot,
                  width: 88,
                  height: 88,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: onOpen,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              spot.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (distanceLabel.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              distanceLabel,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Color(0xFFB7BCC2),
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${spot.city} • ${spot.category}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      if (spot.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          spot.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            height: 1.25,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Color(0xFFB7BCC2),
                          ),
                          const SizedBox(width: 3),
                          Text(spot.rating.toStringAsFixed(1)),
                          if (verified) ...[
                            const SizedBox(width: 7),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF262A2E),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_outlined,
                                      size: 13,
                                      color: Color(0xFFB7BCC2),
                                    ),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Doğrulanmış',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 2),
              SizedBox(
                width: 42,
                child: IconButton(
                  tooltip: selected ? 'Rotadan çıkar' : 'Rotaya ekle',
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggleRoute,
                  icon: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline_rounded,
                    color: selected
                        ? const Color(0xFF42F5E9)
                        : Colors.white54,
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
