import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/turkey_selection_data.dart';
import '../models/nearby_venue.dart';
import '../models/route_place.dart';
import '../screens/business_profile_screen.dart';
import '../services/location_service.dart';
import '../services/nearby_venue_service.dart';
import '../services/route_selection_service.dart';
import '../services/venue_rating_service.dart';
import '../theme/app_theme.dart';
import 'chat_share_sheet.dart';
import 'searchable_selection_field.dart';
import 'sponsored_native_ad.dart';

class NearbyPlacesView extends StatefulWidget {
  final NearbyVenueCategory category;
  const NearbyPlacesView({super.key, required this.category});

  @override
  State<NearbyPlacesView> createState() => _NearbyPlacesViewState();
}

class _NearbyPlacesViewState extends State<NearbyPlacesView> {
  final _searchController = TextEditingController();
  final _cityController = TextEditingController();
  Position? _userPosition;
  List<NearbyVenue> _venues = const [];
  final Map<String, VenueRatingSummary> _ratings = {};
  bool _loading = true;
  bool _refreshing = false;
  bool _citySearching = false;
  String? _error;
  String _sort = 'popular';
  int _loadGeneration = 0;
  int _ratingGeneration = 0;

  @override
  void initState() {
    super.initState();
    _cityController.text = NearbyVenueService.instance.selectedCityName ?? '';
    _load();
  }

  @override
  void didUpdateWidget(covariant NearbyPlacesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) {
      _searchController.clear();
      _ratings.clear();
      _ratingGeneration++;
      _load(forceRefresh: false);
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _ratingGeneration++;
    _searchController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final generation = ++_loadGeneration;
    final category = widget.category;
    final keepExisting = _venues.isNotEmpty;
    if (mounted) {
      setState(() {
        _loading = !keepExisting;
        _refreshing = keepExisting;
        _error = null;
      });
    }
    try {
      Position? position;
      try {
        position = await LocationService.getCurrentPosition(
          forceRefresh: forceRefresh,
        );
      } catch (_) {}
      if (!mounted || generation != _loadGeneration) return;

      final hasCity = NearbyVenueService.instance.hasSelectedCity;
      if (position == null && !hasCity) {
        setState(() {
          _loading = false;
          _refreshing = false;
          _error = 'Mekanları görmek için konumunu aç veya bir şehir seç.';
        });
        return;
      }

      final lat = position?.latitude ?? 39.0;
      final lon = position?.longitude ?? 35.0;
      final items = await NearbyVenueService.instance.nearby(
        category: category,
        latitude: lat,
        longitude: lon,
        forceRefresh: forceRefresh,
      );
      if (!mounted || generation != _loadGeneration || category != widget.category) {
        return;
      }

      setState(() {
        _userPosition = position;
        _venues = items;
        _loading = false;
        _refreshing = false;
        _error = null;
      });
      _loadRatings(items);
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        if (_venues.isEmpty) {
          _error = NearbyVenueService.instance.hasSelectedCity
              ? '${NearbyVenueService.instance.selectedCityName} mekanları şu an yüklenemedi. Tekrar deneyebilirsin.'
              : 'Mekanlar şu an yüklenemedi. Bağlantını kontrol edip tekrar dene.';
        }
      });
    }
  }

  Future<void> _loadRatings(List<NearbyVenue> items) async {
    final generation = ++_ratingGeneration;
    final candidates = items.take(48).toList(growable: false);
    const batchSize = 12;
    for (var start = 0; start < candidates.length; start += batchSize) {
      if (!mounted || generation != _ratingGeneration) return;
      final end = math.min(start + batchSize, candidates.length);
      final batch = candidates.sublist(start, end);
      final results = await Future.wait(
        batch.map((venue) async {
          try {
            final rating = await VenueRatingService.instance.summary(
              venue.category.name,
              venue.id,
            );
            return MapEntry(_key(venue), rating);
          } catch (_) {
            return null;
          }
        }),
      );
      if (!mounted || generation != _ratingGeneration) return;
      final loaded = <String, VenueRatingSummary>{};
      for (final entry in results) {
        if (entry != null) loaded[entry.key] = entry.value;
      }
      if (loaded.isNotEmpty) setState(() => _ratings.addAll(loaded));
    }
  }

  String _key(NearbyVenue v) => '${v.category.name}:${v.id}';

  double _distanceKm(NearbyVenue v) {
    final p = _userPosition;
    if (p == null) return double.infinity;
    return Geolocator.distanceBetween(
          p.latitude,
          p.longitude,
          v.latitude,
          v.longitude,
        ) /
        1000;
  }

  String _distanceLabel(NearbyVenue v) {
    final km = _distanceKm(v);
    if (!km.isFinite) return '';
    if (km < 1) return '${(km * 1000).round()} m';
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }

  double _popularityScore(NearbyVenue v) {
    final rating = _ratings[_key(v)] ?? VenueRatingSummary.empty;
    final ratingSignal = rating.count > 0
        ? rating.average * math.log(rating.count + 2)
        : 0.0;
    final distance = _distanceKm(v);
    final proximitySignal = !distance.isFinite
        ? 0.0
        : math.max(0.0, 2.2 - (distance / 25));
    final infoSignal =
        (v.imageUrl.trim().isNotEmpty ? .7 : 0) +
        (v.address.trim().isNotEmpty ? .25 : 0) +
        (v.openingHours.trim().isNotEmpty ? .25 : 0);
    return ratingSignal + proximitySignal + infoSignal;
  }

  List<NearbyVenue> get _visible {
    final q = _searchController.text.trim().toLowerCase();
    final out = _venues
        .where(
          (v) =>
              q.isEmpty || '${v.name} ${v.address}'.toLowerCase().contains(q),
        )
        .toList();
    out.sort((a, b) {
      final ar = _ratings[_key(a)] ?? VenueRatingSummary.empty;
      final br = _ratings[_key(b)] ?? VenueRatingSummary.empty;
      if (_sort == 'nearest' && _userPosition != null) {
        return _distanceKm(a).compareTo(_distanceKm(b));
      }
      if (_sort == 'popular') {
        final score = _popularityScore(b).compareTo(_popularityScore(a));
        if (score != 0) return score;
        if (_userPosition != null) {
          return _distanceKm(a).compareTo(_distanceKm(b));
        }
        return a.name.compareTo(b.name);
      }
      final rating = br.average.compareTo(ar.average);
      if (rating != 0) return rating;
      return br.count.compareTo(ar.count);
    });
    return out;
  }

  Future<void> _chooseCity() async {
    _cityController.text = NearbyVenueService.instance.selectedCityName ?? '';
    final picked = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            16,
            18,
            18 + MediaQuery.viewInsetsOf(context).bottom,
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
                'Seçtiğin şehir sınırındaki mekanlar gösterilir. Konumun yalnızca mesafe ve sıralama için kullanılır.',
                style: TextStyle(color: Colors.white60, height: 1.35),
              ),
              const SizedBox(height: 14),
              SearchableSelectionField(
                controller: _cityController,
                options: turkeyCities,
                labelText: 'Şehir',
                hintText: 'Örn. Elazığ, İzmir, İstanbul',
                prefixIcon: Icons.location_city_outlined,
                enabled: !_citySearching,
                maxSuggestions: 7,
                onSelected: (_) => _searchCity(sheetContext, setSheet),
              ),
              const SizedBox(height: 8),
              Text(
                _citySearching
                    ? 'Şehir hazırlanıyor…'
                    : 'Listeden şehre dokunduğunda doğrudan açılır.',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              if (NearbyVenueService.instance.hasSelectedCity) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    NearbyVenueService.instance.useCurrentCity();
                    Navigator.pop(sheetContext, true);
                  },
                  icon: const Icon(Icons.my_location_rounded),
                  label: const Text('Konumumdaki şehre dön'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (picked == true && mounted) {
      _cityController.text = NearbyVenueService.instance.selectedCityName ?? '';
      _ratings.clear();
      _ratingGeneration++;
      _venues = const [];
      await _load(forceRefresh: true);
    }
  }

  Future<void> _searchCity(
    BuildContext sheetContext,
    StateSetter setSheet,
  ) async {
    final text = _cityController.text.trim();
    if (text.length < 2 || _citySearching) return;
    setSheet(() => _citySearching = true);
    final city = await NearbyVenueService.instance.findCity(text);
    if (!sheetContext.mounted) return;
    setSheet(() => _citySearching = false);
    if (city == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şehir bulunamadı. İl adını yazarak tekrar dene.'),
        ),
      );
      return;
    }
    NearbyVenueService.instance.selectCity(
      name: city.name,
      latitude: city.latitude,
      longitude: city.longitude,
      south: city.south,
      west: city.west,
      north: city.north,
      east: city.east,
    );
    if (sheetContext.mounted) Navigator.pop(sheetContext, true);
  }

  Future<void> _directions(NearbyVenue venue) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${venue.latitude},${venue.longitude}',
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harita uygulaması açılamadı.')),
      );
    }
  }

  void _profile(NearbyVenue venue) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessProfileScreen(
          venue: venue,
          distance: _distanceLabel(venue),
          rating: _ratings[_key(venue)] ?? VenueRatingSummary.empty,
        ),
      ),
    );
  }

  void _toggleRoute(NearbyVenue venue) {
    RouteSelectionService.instance.toggle(
      RoutePlace(
        id: 'venue:${venue.category.name}:${venue.id}',
        name: venue.name,
        category: venue.category.label,
        latitude: venue.latitude,
        longitude: venue.longitude,
      ),
    );
    if (mounted) setState(() {});
  }

  void _map() {
    final items = _visible;
    if (items.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VenueMapScreen(
          category: widget.category,
          venues: items,
          userPosition: _userPosition,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final city = NearbyVenueService.instance.selectedCityName;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Row(
            children: [
              Expanded(
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
                        const Icon(Icons.location_city_outlined, color: AppColors.cyan, size: 19),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                city ?? 'Bulunduğun şehir',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                              Text(
                                city == null
                                    ? 'Şehir değiştirmek için dokun'
                                    : '$city içindeki ${widget.category.label.toLowerCase()}',
                                style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _map,
                tooltip: 'Haritada gör',
                icon: const Icon(Icons.map_outlined),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: '${widget.category.label} içinde ara',
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Row(
            children: [
              _SortChip(
                label: 'Popüler',
                selected: _sort == 'popular',
                onTap: () => setState(() => _sort = 'popular'),
              ),
              if (_userPosition != null) ...[
                const SizedBox(width: 7),
                _SortChip(
                  label: 'En yakın',
                  selected: _sort == 'nearest',
                  onTap: () => setState(() => _sort = 'nearest'),
                ),
              ],
              const Spacer(),
              if (_refreshing)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (!_loading)
                Text(
                  '${_visible.length} yer',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
            ],
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_loading && _venues.isEmpty) return const _VenueSkeletonList();
    if (_error != null && _venues.isEmpty) {
      return _StateMessage(
        icon: Icons.location_off_outlined,
        title: _error!,
        action: 'Tekrar Dene',
        onTap: () => _load(forceRefresh: true),
        secondary: NearbyVenueService.instance.hasSelectedCity
            ? 'Başka Şehir Seç'
            : 'Şehir Seç',
        onSecondary: _chooseCity,
      );
    }
    final items = _visible;
    if (items.isEmpty) {
      return _StateMessage(
        icon: Icons.storefront_outlined,
        title: _searchController.text.trim().isNotEmpty
            ? 'Aramana uygun mekan bulunamadı.'
            : '${NearbyVenueService.instance.selectedCityName ?? 'Bu bölgede'} kayıtlı ${widget.category.label.toLowerCase()} bulunamadı.',
        action: 'Yenile',
        onTap: () => _load(forceRefresh: true),
        secondary: 'Şehir Değiştir',
        onSecondary: _chooseCity,
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 110),
        itemCount: items.length + (items.length <= 6 ? 0 : 1 + ((items.length - 7) ~/ 10)),
        itemBuilder: (_, index) {
          final isAd = index >= 6 && (index - 6) % 11 == 0;
          if (isAd) return const SponsoredNativeAd();
          final adsBefore = index < 6 ? 0 : 1 + ((index - 6) ~/ 11);
          return _venueCard(items[index - adsBefore]);
        },
      ),
    );
  }

  String _openingLabel(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value == '24/7') return '24 saat açık';
    return 'Çalışma saati mevcut';
  }

  Widget _venueCard(NearbyVenue venue) {
    final rating = _ratings[_key(venue)] ?? VenueRatingSummary.empty;
    final routeId = 'venue:${venue.category.name}:${venue.id}';
    final selected = RouteSelectionService.instance.contains(routeId);
    final distance = _distanceLabel(venue);
    final opening = _openingLabel(venue.openingHours);
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: () => _profile(venue),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: venue.imageUrl.trim().isNotEmpty
                      ? Image.network(
                          venue.imageUrl.trim(),
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, __, ___) => _venuePlaceholder(),
                        )
                      : _venuePlaceholder(),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      children: [
                        _MetaPill(label: venue.category.label, color: AppColors.cyan),
                        if (rating.count > 0)
                          _MetaPill(
                            label: '★ ${rating.average.toStringAsFixed(1)} · ${rating.count}',
                            color: Colors.amber,
                          ),
                        if (distance.isNotEmpty)
                          _MetaPill(label: distance, color: Colors.white70),
                        if (opening.isNotEmpty)
                          _MetaPill(label: opening, color: Colors.greenAccent),
                      ],
                    ),
                    if (venue.address.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        venue.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                      ),
                    ],
                    if (venue.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        venue.description.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.25),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    tooltip: selected ? 'Rotadan çıkar' : 'Rotaya ekle',
                    onPressed: () => _toggleRoute(venue),
                    icon: Icon(
                      selected ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: selected ? AppColors.cyan : Colors.white54,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Mesaj olarak gönder',
                    onPressed: () => shareCardToChat(
                      context,
                      sharedType: 'venue',
                      sharedId: '${venue.latitude},${venue.longitude}',
                      title: venue.name,
                    ),
                    icon: const Icon(Icons.send_outlined, color: Colors.white54),
                  ),
                  IconButton(
                    tooltip: 'Yol tarifi',
                    onPressed: () => _directions(venue),
                    icon: const Icon(Icons.directions_outlined, color: Colors.white54),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _venuePlaceholder() => ColoredBox(
    color: AppColors.surfaceStrong,
    child: Center(child: Icon(_icon, color: AppColors.cyan, size: 30)),
  );

  IconData get _icon => switch (widget.category) {
    NearbyVenueCategory.cafe => Icons.local_cafe_outlined,
    NearbyVenueCategory.hotel => Icons.hotel_outlined,
    NearbyVenueCategory.dining => Icons.restaurant_outlined,
  };
}

class _MetaPill extends StatelessWidget {
  final String label;
  final Color color;
  const _MetaPill({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: .20)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800),
    ),
  );
}

class _VenueSkeletonList extends StatelessWidget {
  const _VenueSkeletonList();

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(14, 2, 14, 110),
    itemCount: 4,
    itemBuilder: (_, __) => Container(
      height: 104,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.surfaceStrong,
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 13, width: 170, color: AppColors.surfaceStrong),
                const SizedBox(height: 10),
                Container(height: 10, width: 120, color: AppColors.surfaceStrong),
                const SizedBox(height: 8),
                Container(height: 10, width: 200, color: AppColors.surfaceStrong),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(99),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? AppColors.surfaceStrong : AppColors.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: selected ? AppColors.cyan.withValues(alpha: .55) : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          color: selected ? Colors.white : Colors.white60,
        ),
      ),
    ),
  );
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String action;
  final VoidCallback onTap;
  final String secondary;
  final VoidCallback onSecondary;
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.action,
    required this.onTap,
    required this.secondary,
    required this.onSecondary,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 46, color: Colors.white30),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(action),
          ),
          TextButton(onPressed: onSecondary, child: Text(secondary)),
        ],
      ),
    ),
  );
}

class _VenueMapScreen extends StatelessWidget {
  final NearbyVenueCategory category;
  final List<NearbyVenue> venues;
  final Position? userPosition;
  const _VenueMapScreen({
    required this.category,
    required this.venues,
    required this.userPosition,
  });

  @override
  Widget build(BuildContext context) {
    final center = venues.isNotEmpty
        ? LatLng(venues.first.latitude, venues.first.longitude)
        : LatLng(userPosition?.latitude ?? 39, userPosition?.longitude ?? 35);
    final markers = venues
        .map(
          (v) => Marker(
            markerId: MarkerId('${v.category.name}:${v.id}'),
            position: LatLng(v.latitude, v.longitude),
            infoWindow: InfoWindow(title: v.name, snippet: v.address),
          ),
        )
        .toSet();
    return Scaffold(
      appBar: AppBar(title: Text('${category.label} Haritası')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: center, zoom: 11.5),
        markers: markers,
        myLocationEnabled: userPosition != null,
        myLocationButtonEnabled: userPosition != null,
        zoomGesturesEnabled: true,
        scrollGesturesEnabled: true,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
      ),
    );
  }
}
