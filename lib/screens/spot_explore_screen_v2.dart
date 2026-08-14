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
import '../services/nationwide_candidate_spot_resolver.dart';
import '../services/spot_repository.dart';
import '../widgets/spot_image.dart';
import 'spot_detail_screen.dart';

class SpotExploreScreen extends StatefulWidget {
  const SpotExploreScreen({super.key});

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
    } catch (_) {
      // Yerel katalog zaten ekranda; uzak kaynak başarısız olsa da kullanıcı beklemez.
    }
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
        desiredAccuracy: LocationAccuracy.medium,
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
      final haystack = '${spot.name} ${spot.city} ${spot.category} ${spot.description}'
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      color: const Color(0xFF8B5CF6),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Çekim Noktaları',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _position == null
                        ? 'Noktalar hemen yüklenir; konum gelince yakından uzağa sıralanır.'
                        : 'Sana en yakın noktalardan başlayarak sıralandı.',
                    style: const TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  _search = value;
                  _applyFilter();
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: 'Şehir veya çekim noktası ara...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xFF141126),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          if (_loading && _visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
              ),
            )
          else if (_visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('Çekim noktası bulunamadı.')),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
                child: Text(
                  '${_visible.length} çekim noktası',
                  style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: _visible.length,
              itemBuilder: (context, index) {
                final spot = _visible[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Card(
                    color: const Color(0xFF141126),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            SpotImage(
                              spot: spot,
                              width: 88,
                              height: 88,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                      if (_distanceLabel(spot).isNotEmpty)
                                        Text(
                                          _distanceLabel(spot),
                                          style: const TextStyle(
                                            color: Color(0xFF8B5CF6),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${spot.city} • ${spot.category}',
                                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded, size: 16, color: Color(0xFF8B5CF6)),
                                      const SizedBox(width: 3),
                                      Text(spot.rating.toStringAsFixed(1)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                          ],
                        ),
                      ),
                    ),
                  ),
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
