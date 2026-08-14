import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/photo_spot.dart';
import '../services/spot_repository.dart';
import '../widgets/spot_image.dart';
import 'spot_detail_screen.dart';

class SpotExploreScreen extends StatefulWidget {
  const SpotExploreScreen({super.key});

  @override
  State<SpotExploreScreen> createState() => _SpotExploreScreenState();
}

class _SpotExploreScreenState extends State<SpotExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PhotoSpot> _spots = const [];
  List<String> _cities = const [];
  List<String> _categories = const [];
  bool _loading = true;
  bool _locationChecked = false;
  String? _error;
  String _search = '';
  String? _city;
  String? _category;
  SpotSort _sort = SpotSort.rating;
  Position? _position;

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
            accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 3)),
      ).timeout(const Duration(seconds: 4));

      if (!mounted) return;
      setState(() {
        _position = position;
        _locationChecked = true;
        final sorted = List<PhotoSpot>.from(_spots);
        _sortByDistanceIfPossible(sorted);
        _spots = sorted;
      });
    } catch (_) {
      if (mounted) setState(() => _locationChecked = true);
    }
  }

  double? _distanceMeters(PhotoSpot spot) {
    final p = _position;
    if (p == null) return null;
    return Geolocator.distanceBetween(
        p.latitude, p.longitude, spot.latitude, spot.longitude);
  }

  String _distanceLabel(PhotoSpot spot) {
    final meters = _distanceMeters(spot);
    if (meters == null) return '';
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }

  void _sortByDistanceIfPossible(List<PhotoSpot> spots) {
    if (_position == null) return;
    spots.sort((a, b) => (_distanceMeters(a) ?? double.infinity)
        .compareTo(_distanceMeters(b) ?? double.infinity));
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final spotFuture = SpotRepository.instance.discover(
        query: SpotDiscoveryQuery(
            text: _search, city: _city, category: _category, sort: _sort),
      );
      final metaFuture = Future.wait([
        SpotRepository.instance.availableCities(),
        SpotRepository.instance.availableCategories(),
      ]);

      final loaded = List<PhotoSpot>.from(await spotFuture);
      _sortByDistanceIfPossible(loaded);
      if (!mounted) return;
      setState(() {
        _spots = loaded;
        _loading = false;
      });

      try {
        final meta = await metaFuture;
        if (!mounted) return;
        setState(() {
          _cities = meta[0];
          _categories = meta[1];
        });
      } catch (_) {}
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Çekim noktaları yüklenemedi.';
      });
    }
  }

  Future<void> _applySearch(String value) async {
    _search = value;
    await _reload();
  }

  void _openFilters() {
    String? draftCity = _city;
    String? draftCategory = _category;
    SpotSort draftSort = _sort;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF11181D),
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Keşfet filtreleri',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 18),
                DropdownButtonFormField<String?>(
                  value: draftCity,
                  decoration: const InputDecoration(labelText: 'Şehir'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Tüm şehirler')),
                    ..._cities.map((city) => DropdownMenuItem<String?>(
                        value: city, child: Text(city))),
                  ],
                  onChanged: (value) => setSheetState(() => draftCity = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: draftCategory,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Tüm kategoriler')),
                    ..._categories.map((category) => DropdownMenuItem<String?>(
                        value: category, child: Text(category))),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => draftCategory = value),
                ),
                const SizedBox(height: 12),
                SegmentedButton<SpotSort>(
                  segments: const [
                    ButtonSegment(
                        value: SpotSort.rating,
                        label: Text('Puana göre'),
                        icon: Icon(Icons.star_rounded)),
                    ButtonSegment(
                        value: SpotSort.name,
                        label: Text('İsme göre'),
                        icon: Icon(Icons.sort_by_alpha_rounded)),
                  ],
                  selected: {draftSort},
                  onSelectionChanged: (value) =>
                      setSheetState(() => draftSort = value.first),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  TextButton(
                    onPressed: () => setSheetState(() {
                      draftCity = null;
                      draftCategory = null;
                      draftSort = SpotSort.rating;
                    }),
                    child: const Text('Temizle'),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16B8A6),
                        foregroundColor: Colors.black),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      setState(() {
                        _city = draftCity;
                        _category = draftCategory;
                        _sort = draftSort;
                      });
                      _reload();
                    },
                    child: const Text('Uygula'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      color: const Color(0xFF16B8A6),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Çekim Noktaları',
                            style: TextStyle(
                                fontSize: 26, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          _position != null
                              ? 'Sana en yakın noktalardan başlayarak sıralandı.'
                              : (_locationChecked
                                  ? 'Noktalar hazır. Konum izni verirsen yakınlığa göre sıralanır.'
                                  : 'Noktalar yükleniyor; konum arka planda hazırlanıyor.'),
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ]),
                ),
                IconButton.filledTonal(
                    tooltip: 'Filtrele',
                    onPressed: _openFilters,
                    icon: const Icon(Icons.tune_rounded)),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: TextField(
                controller: _searchController,
                onSubmitted: _applySearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Şehir, nokta, gün batımı, mimari...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _applySearch('');
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: const Color(0xFF11181D),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          if (_city != null || _category != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  if (_city != null)
                    InputChip(
                        label: Text(_city!),
                        onDeleted: () {
                          setState(() => _city = null);
                          _reload();
                        }),
                  if (_category != null)
                    InputChip(
                        label: Text(_category!),
                        onDeleted: () {
                          setState(() => _category = null);
                          _reload();
                        }),
                ]),
              ),
            ),
          if (_loading && _spots.isEmpty)
            const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF16B8A6))))
          else if (_error != null && _spots.isEmpty)
            SliverFillRemaining(
                hasScrollBody: false,
                child: _ExploreState(
                    icon: Icons.cloud_off_rounded,
                    title: _error!,
                    actionLabel: 'Tekrar dene',
                    onAction: _reload))
          else if (_spots.isEmpty)
            const SliverFillRemaining(
                hasScrollBody: false,
                child: _ExploreState(
                    icon: Icons.search_off_rounded,
                    title: 'Bu filtrelerde çekim noktası bulunamadı.'))
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Row(children: [
                  Text('${_spots.length} çekim noktası',
                      style: const TextStyle(
                          color: Colors.white54, fontWeight: FontWeight.w600)),
                  if (_loading) ...[
                    const SizedBox(width: 10),
                    const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF16B8A6))),
                  ],
                ]),
              ),
            ),
            SliverList.builder(
              itemCount: _spots.length,
              itemBuilder: (context, index) => _SpotCard(
                  spot: _spots[index],
                  distanceLabel: _distanceLabel(_spots[index])),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ],
      ),
    );
  }
}

class _SpotCard extends StatelessWidget {
  final PhotoSpot spot;
  final String distanceLabel;
  const _SpotCard({required this.spot, required this.distanceLabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Card(
        color: const Color(0xFF11181D),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot))),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              SpotImage(
                  spot: spot,
                  width: 88,
                  height: 88,
                  borderRadius: BorderRadius.circular(12)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(spot.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16))),
                        if (distanceLabel.isNotEmpty)
                          Text(distanceLabel,
                              style: const TextStyle(
                                  color: Color(0xFF16B8A6),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12)),
                      ]),
                      const SizedBox(height: 4),
                      Text('${spot.city} • ${spot.category}',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.star_rounded,
                            size: 16, color: Color(0xFF16B8A6)),
                        const SizedBox(width: 3),
                        Text(spot.rating.toStringAsFixed(1)),
                        const SizedBox(width: 12),
                        const Icon(Icons.schedule_rounded,
                            size: 15, color: Colors.white54),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(spot.bestTime,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 11))),
                      ]),
                    ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ]),
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
  const _ExploreState(
      {required this.icon,
      required this.title,
      this.actionLabel,
      this.onAction});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 54, color: Colors.white30),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ]),
        ),
      );
}
