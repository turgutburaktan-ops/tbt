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
import '../theme/app_theme.dart';
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
      color: AppColors.cyan,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (!widget.embedded)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gezilecek Yerler',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _position == null
                          ? 'Gerçek gezi noktalarını keşfet; fotoğraf önerilerini detayda gör.'
                          : 'Yakınındaki gezilecek yerlerden başlayarak sıralandı.',
                      style: const TextStyle(color: const Color(0x75FFFFFF), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                widget.embedded ? 4 : 0,
                14,
                8,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  _search = value;
                  _applyFilter();
                  setState(() {});
                },
                decoration: const InputDecoration(
                  hintText: 'Yer, şehir veya kategori ara',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: RouteSelectionButton(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 7),
            ),
          ),
          if (_loading && _visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('Gezilecek yer bulunamadı.')),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 7),
                child: Text(
                  '${_visible.length} gezilecek yer',
                  style: const TextStyle(
                    color: const Color(0x75FFFFFF),
                    fontSize: 11.5,
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
            const SliverToBoxAdapter(child: SizedBox(height: 92)),
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
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: selected
                    ? AppColors.cyan.withValues(alpha: .38)
                    : AppColors.border,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SpotImage(
                  spot: spot,
                  width: 78,
                  height: 78,
                  borderRadius: BorderRadius.circular(11),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        spot.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${spot.city}  •  ${spot.category}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: const Color(0x75FFFFFF),
                                fontSize: 10.8,
                              ),
                            ),
                          ),
                          if (distanceLabel.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              distanceLabel,
                              style: const TextStyle(
                                color: AppColors.cyan,
                                fontWeight: FontWeight.w900,
                                fontSize: 10.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppColors.cyan,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            spot.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 7),
                            const Icon(
                              Icons.verified_rounded,
                              size: 13,
                              color: Colors.white38,
                            ),
                            const SizedBox(width: 3),
                            const Flexible(
                              child: Text(
                                'Doğrulanmış',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 9.8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: selected ? 'Rotadan çıkar' : 'Rotaya ekle',
                  onPressed: onToggleRoute,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(38, 38),
                    backgroundColor:
                        selected ? AppColors.cyan : AppColors.surfaceStrong,
                    foregroundColor:
                        selected ? const Color(0xFF041311) : Colors.white70,
                  ),
                  icon: Icon(
                    selected ? Icons.check_rounded : Icons.add_rounded,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
