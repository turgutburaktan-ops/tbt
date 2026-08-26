import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/photo_spot.dart';
import '../services/spot_repository.dart';
import '../widgets/spot_image.dart';
import 'spot_detail_screen.dart';

enum _OpportunityMode { nearby, popular }

class SpotExploreScreen extends StatefulWidget {
  const SpotExploreScreen({super.key});

  @override
  State<SpotExploreScreen> createState() => _SpotExploreScreenState();
}

class _SpotExploreScreenState extends State<SpotExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PhotoSpot> _all = const [];
  List<PhotoSpot> _visible = const [];
  bool _loading = true;
  bool _locationChecked = false;
  String? _error;
  String _search = '';
  Position? _position;
  _OpportunityMode _mode = _OpportunityMode.nearby;

  @override
  void initState() {
    super.initState();
    _reload();
    _resolveLocationInBackground();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _resolveLocationInBackground() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _locationChecked = true);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationChecked = true);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 3),
        ),
      ).timeout(const Duration(seconds: 4));
      if (!mounted) return;
      setState(() {
        _position = position;
        _locationChecked = true;
        _applyView();
      });
    } catch (_) {
      if (mounted) setState(() => _locationChecked = true);
    }
  }

  double? _distanceMeters(PhotoSpot spot) {
    final p = _position;
    if (p == null) return null;
    return Geolocator.distanceBetween(
      p.latitude,
      p.longitude,
      spot.latitude,
      spot.longitude,
    );
  }

  String _distanceLabel(PhotoSpot spot) {
    final meters = _distanceMeters(spot);
    if (meters == null) return '';
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }

  void _applyView() {
    final key = _search.trim().toLowerCase();
    final next = _all.where((spot) {
      if (key.isEmpty) return true;
      final haystack =
          '${spot.name} ${spot.city} ${spot.category} ${spot.description} ${spot.tags.join(' ')} ${spot.bestTime}'
              .toLowerCase();
      return haystack.contains(key);
    }).toList();

    if (_mode == _OpportunityMode.nearby && _position != null) {
      next.sort(
        (a, b) => (_distanceMeters(a) ?? double.infinity).compareTo(
          _distanceMeters(b) ?? double.infinity,
        ),
      );
    } else {
      next.sort((a, b) {
        final rating = b.rating.compareTo(a.rating);
        if (rating != 0) return rating;
        return a.name.compareTo(b.name);
      });
    }
    _visible = next;
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final loaded = await SpotRepository.instance.discover(
        query: SpotDiscoveryQuery(text: _search, sort: SpotSort.rating),
      );
      if (!mounted) return;
      setState(() {
        _all = List<PhotoSpot>.from(loaded);
        _applyView();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Çekim fırsatları yüklenemedi.';
      });
    }
  }

  void _setMode(_OpportunityMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _applyView();
    });
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _mode == _OpportunityMode.nearby
        ? (_position != null
              ? 'Sana en yakın çekim noktaları önce gösteriliyor.'
              : (_locationChecked
                    ? 'Konum izni verirsen en yakın noktaları önce gösterebiliriz.'
                    : 'Konumun hazırlanıyor; yakındaki noktalar birazdan sıralanacak.'))
        : 'En yüksek puanlı çekim noktaları önce gösteriliyor.';

    return RefreshIndicator(
      onRefresh: _reload,
      color: const Color(0xFFB7BCC2),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Çekim Fırsatları',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF121416),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeButton(
                        label: 'Yakındakiler',
                        icon: Icons.near_me_rounded,
                        selected: _mode == _OpportunityMode.nearby,
                        onTap: () => _setMode(_OpportunityMode.nearby),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _ModeButton(
                        label: 'Popüler',
                        icon: Icons.local_fire_department_rounded,
                        selected: _mode == _OpportunityMode.popular,
                        onTap: () => _setMode(_OpportunityMode.popular),
                      ),
                    ),
                  ],
                ),
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
                  _applyView();
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: 'Şehir, nokta, gün batımı, mimari...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _search = '';
                            _applyView();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
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
          if (_loading && _visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFB7BCC2)),
              ),
            )
          else if (_error != null && _visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _ExploreState(
                icon: Icons.cloud_off_rounded,
                title: _error!,
                actionLabel: 'Tekrar dene',
                onAction: _reload,
              ),
            )
          else if (_visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _ExploreState(
                icon: Icons.search_off_rounded,
                title: 'Bu aramada çekim fırsatı bulunamadı.',
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
                child: Text(
                  '${_visible.length} çekim fırsatı',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: _visible.length,
              itemBuilder: (context, index) => _SpotCard(
                spot: _visible[index],
                distanceLabel: _distanceLabel(_visible[index]),
                showDistance: _mode == _OpportunityMode.nearby,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF20262B) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF42F5E9) : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: selected ? const Color(0xFF42F5E9) : Colors.white54,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : Colors.white60,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SpotCard extends StatelessWidget {
  final PhotoSpot spot;
  final String distanceLabel;
  final bool showDistance;

  const _SpotCard({
    required this.spot,
    required this.distanceLabel,
    required this.showDistance,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Card(
        color: const Color(0xFF121416),
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
                          if (showDistance && distanceLabel.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              distanceLabel,
                              style: const TextStyle(
                                color: Color(0xFF42F5E9),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Color(0xFFB7BCC2),
                          ),
                          const SizedBox(width: 3),
                          Text(spot.rating.toStringAsFixed(1)),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.schedule_rounded,
                            size: 15,
                            color: Colors.white54,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              spot.bestTime,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExploreState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ExploreState({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: Colors.white30),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
