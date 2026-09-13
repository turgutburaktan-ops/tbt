import '../services/spot_browsing.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/turkey_selection_data.dart';
import '../services/nearby_venue_service.dart';
import '../widgets/searchable_selection_field.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/photo_spot.dart';
import '../models/route_place.dart';
import '../services/route_selection_service.dart';
import '../services/spot_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_share_sheet.dart';
import '../widgets/route_selection_button.dart';
import '../widgets/spot_image.dart';
import '../widgets/sponsored_native_ad.dart';
import 'spot_detail_screen.dart';
import 'spot_suggestion_screen.dart';

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
  String? _city;
  String? _detectedCity;
  String _sort = 'nearest';
  final _cityController = TextEditingController();

  String _routeId(PhotoSpot spot) => 'spot:${spot.id}';

  @override
  void initState() {
    super.initState();
    _city = NearbyVenueService.instance.selectedCityName;
    _refreshRemote();
    _prepareLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _refreshRemote() async {
    try {
      final remote = await SpotRepository.instance.discover();
      if (!mounted) return;
      // Replacement also applies to empty results: unpublished places must
      // never reappear from the bundled catalog.
      _all = remote;
      _applyFilter();
      setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gezilecek yerler alınamadı. Yeniden deneyebilirsin.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 4));
      if (!mounted) return;
      _position = position;
      await _detectCity(position);
      if (!mounted) return;
      _applyFilter();
      setState(() {});
    } catch (_) {}
  }

  void _applyFilter() {
    _visible = browseCitySpots(
      _all,
      city: _city ?? _detectedCity,
      query: _search,
      nearest: _sort == 'nearest',
      latitude: _position?.latitude,
      longitude: _position?.longitude,
    );
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

  String _fold(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  Future<void> _detectCity(Position position) async {
    try {
      final response = await http
          .get(
            Uri.https('nominatim.openstreetmap.org', '/reverse', {
              'lat': '${position.latitude}',
              'lon': '${position.longitude}',
              'format': 'jsonv2',
              'zoom': '5',
              'accept-language': 'tr',
            }),
            headers: {'User-Agent': 'TBT-mobile/0.1 (city places)'},
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return;
      final address = (jsonDecode(response.body) as Map)['address'] as Map?;
      final candidates = [
        address?['province'],
        address?['state'],
        address?['city'],
      ];
      for (final city in turkeyCities) {
        if (candidates.any((v) => _fold('$v') == _fold(city))) {
          _detectedCity = city;
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _chooseCity() async {
    _cityController.text = _city ?? '';
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          16,
          18,
          18 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Şehir seç',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            const Text(
              'Seçtiğin şehirdeki gezilecek yerler gösterilir.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 14),
            SearchableSelectionField(
              controller: _cityController,
              options: turkeyCities,
              labelText: 'Şehir',
              hintText: 'Örn. Elazığ, İzmir, İstanbul',
              prefixIcon: Icons.location_city_outlined,
              maxSuggestions: 7,
              onSelected: (city) => Navigator.pop(sheetContext, city),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(sheetContext, ''),
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('Konumumdaki şehre dön'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _city = picked.isEmpty ? null : picked;
      _search = '';
      _searchController.clear();
      _applyFilter();
    });
    if (picked.isEmpty) await _prepareLocation();
  }

  Widget _cityAndSort() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: InkWell(
          onTap: _chooseCity,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_city_outlined,
                  color: AppColors.cyan,
                  size: 19,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _city ?? _detectedCity ?? 'Bulunduğun şehir',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const Text(
                        'Şehir değiştirmek için dokun',
                        style: TextStyle(color: Colors.white54, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white54,
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Future<void> _reload() async {
    setState(() => _loading = true);
    SpotRepository.instance.invalidateCache();
    await _refreshRemote();
    if (mounted) setState(() => _loading = false);
  }

  void _toggleRoute(PhotoSpot spot) {
    RouteSelectionService.instance.toggle(
      RoutePlace(
        id: _routeId(spot),
        spot: spot,
        name: spot.name,
        category: 'Gezilecek Yerler',
        latitude: spot.latitude,
        longitude: spot.longitude,
      ),
    );
    setState(() {});
  }

  Future<void> _suggestSpot() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SpotSuggestionScreen()),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önerin admin incelemesine gönderildi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _reload,
    color: AppColors.cyan,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, widget.embedded ? 10 : 14, 14, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gezilecek Yerler',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _suggestSpot,
                  icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: const Text('Yer Öner'),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _cityAndSort()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                _search = value;
                _applyFilter();
                setState(() {});
              },
              decoration: const InputDecoration(
                hintText: 'Gezilecek yerlerde ara',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Wrap(
              spacing: 7,
              children: [
                for (final item in [
                  ('popular', 'Popüler'),
                  ('nearest', 'En yakın'),
                ])
                  ChoiceChip(
                    label: Text(item.$2),
                    selected: _sort == item.$1,
                    onSelected: (_) {
                      if (item.$1 == 'nearest' && _position == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Mesafeye göre sıralamak için konumunu aç.',
                            ),
                          ),
                        );
                        _prepareLocation();
                      }
                      setState(() {
                        _sort = item.$1;
                        _applyFilter();
                      });
                    },
                  ),
              ],
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
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                _city == null && _detectedCity == null
                    ? 'Gezilecek yerleri görmek için bir şehir seç veya konumunu aç.'
                    : 'Bu şehirde aramana uygun gezilecek yer bulunamadı.',
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 7),
              child: Text(
                '${_visible.length} gezilecek yer',
                style: const TextStyle(
                  color: Color(0x75FFFFFF),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SliverList.builder(
            itemCount:
                _visible.length +
                (_visible.length <= 6 ? 0 : 1 + ((_visible.length - 7) ~/ 10)),
            itemBuilder: (context, index) {
              final isAd = index >= 6 && (index - 6) % 11 == 0;
              if (isAd) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: SponsoredNativeAd(),
                );
              }
              final adsBefore = index < 6 ? 0 : 1 + ((index - 6) ~/ 11);
              final spot = _visible[index - adsBefore];
              final selected = RouteSelectionService.instance.contains(
                _routeId(spot),
              );
              return _SpotVenueCard(
                spot: spot,
                pinned: false,
                selected: selected,
                distanceLabel: _distanceLabel(spot),
                onOpen: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SpotDetailScreen(spot: spot),
                  ),
                ),
                onToggleRoute: () => _toggleRoute(spot),
                onShare: () => shareCardToChat(
                  context,
                  sharedType: 'spot',
                  sharedId: '${spot.latitude},${spot.longitude}',
                  title: spot.name,
                  imageUrl: spot.imageUrl,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 92)),
        ],
      ],
    ),
  );
}

class _SpotVenueCard extends StatelessWidget {
  final PhotoSpot spot;
  final bool pinned;
  final bool selected;
  final String distanceLabel;
  final VoidCallback onOpen;
  final VoidCallback onToggleRoute;
  final VoidCallback onShare;
  const _SpotVenueCard({
    required this.spot,
    required this.pinned,
    required this.selected,
    required this.distanceLabel,
    required this.onOpen,
    required this.onToggleRoute,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) => Padding(
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
              color: pinned || selected
                  ? AppColors.cyan.withValues(alpha: .38)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              SpotImage(
                spot: spot,
                width: 96,
                height: 108,
                borderRadius: BorderRadius.circular(11),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pinned) ...[
                      const Row(
                        children: [
                          Icon(
                            Icons.push_pin_rounded,
                            size: 13,
                            color: AppColors.cyan,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Sabitlenen yer',
                            style: TextStyle(
                              color: AppColors.cyan,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      spot.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${spot.city} • ${spot.category}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        if (distanceLabel.isNotEmpty)
                          Text(
                            distanceLabel,
                            style: const TextStyle(
                              color: AppColors.cyan,
                              fontWeight: FontWeight.w900,
                              fontSize: 10.5,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
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
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            spot.bestTime,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Mesaj olarak gönder',
                    onPressed: onShare,
                    icon: const Icon(
                      Icons.send_outlined,
                      color: Colors.white54,
                    ),
                  ),
                  IconButton(
                    tooltip: selected ? 'Rotadan çıkar' : 'Rotaya ekle',
                    onPressed: onToggleRoute,
                    style: IconButton.styleFrom(
                      backgroundColor: selected
                          ? AppColors.cyan
                          : AppColors.surfaceStrong,
                      foregroundColor: selected
                          ? const Color(0xFF041311)
                          : Colors.white70,
                    ),
                    icon: Icon(
                      selected ? Icons.check_rounded : Icons.add_rounded,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
