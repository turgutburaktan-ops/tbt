import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../data/turkey_selection_data.dart';
import '../models/nearby_venue.dart';
import '../models/photo_spot.dart';
import '../models/route_place.dart';
import '../services/location_service.dart';
import '../services/nearby_venue_service.dart';
import '../services/route_selection_service.dart';
import '../services/spot_browsing.dart';
import '../services/spot_repository.dart';
import '../services/venue_rating_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_share_sheet.dart';
import '../widgets/route_selection_button.dart';
import '../widgets/spot_image.dart';
import '../widgets/sponsored_native_ad.dart';
import '../widgets/venue_quality_badge.dart';
import 'business_profile_screen.dart';
import 'spot_detail_screen.dart';
import 'spot_suggestion_screen.dart';

/// List and map intentionally share one state and the existing route basket.
class PlacesHubScreen extends StatefulWidget {
  const PlacesHubScreen({super.key, this.source = const PlacesDataSource()});

  final PlacesDataSource source;

  @override
  State<PlacesHubScreen> createState() => _PlacesHubScreenState();
}

class _PlacesHubScreenState extends State<PlacesHubScreen> {
  static const _labels = ['Gezi', 'Lezzet', 'Kafeler', 'Oteller'];
  static const _icons = [
    Icons.landscape_outlined,
    Icons.restaurant_outlined,
    Icons.local_cafe_outlined,
    Icons.hotel_outlined,
  ];
  final _search = TextEditingController();
  final _filters = <int>{0};
  final _venues = <int, List<NearbyVenue>>{};
  final _ratings = <String, VenueRatingSummary>{};
  final _loading = <int>{};
  final _errors = <int>{};
  List<PhotoSpot> _spots = [];
  String? _city;
  Position? _position;
  LatLng _center = const LatLng(39, 35);
  bool _map = false, _nearest = false, _locating = true;
  int _generation = 0;
  String? _selectedId;
  CameraPosition? _camera;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _generation++;
    _search.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final generation = _generation;
    final saved = widget.source.selectedCity;
    if (saved != null) {
      await _selectCity(saved);
    } else {
      final position = await LocationService.getCurrentPosition();
      if (!mounted || generation != _generation) return;
      _position = position;
      if (position != null) {
        _center = LatLng(position.latitude, position.longitude);
        try {
          final response = await http
              .get(
                Uri.https('nominatim.openstreetmap.org', '/reverse', {
                  'lat': '${position.latitude}',
                  'lon': '${position.longitude}',
                  'format': 'jsonv2',
                }),
                headers: {'User-Agent': 'TBT-mobile/0.1 (city places)'},
              )
              .timeout(const Duration(seconds: 5));
          if (!mounted || generation != _generation) return;
          if (response.statusCode == 200) {
            final address =
                (jsonDecode(response.body) as Map)['address'] as Map?;
            for (final key in ['province', 'state', 'city']) {
              final value = foldPlaceText('${address?[key] ?? ''}');
              for (final city in turkeyCities) {
                if (foldPlaceText(city) == value) _city = city;
              }
              if (_city != null) break;
            }
          }
        } catch (_) {
          /* Manual city selection remains available. */
        }
      }
      if (!mounted || generation != _generation) return;
      if (_city != null) {
        await _selectCity(_city!);
      } else if (position != null) {
        await _reload();
      }
    }
    if (mounted) setState(() => _locating = false);
  }

  Future<void> _chooseCity() async {
    final city = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _CityPicker(),
    );
    if (city != null && mounted) await _selectCity(city);
  }

  Future<void> _selectCity(String city) async {
    final generation = ++_generation;
    setState(() {
      _locating = true;
      _loading.clear();
    });
    final area = await NearbyVenueService.instance.findCity(city);
    if (!mounted || generation != _generation) return;
    if (area == null) {
      setState(() => _locating = false);
      _notice(
        'Şehir bilgisi alınamadı. İnternet bağlantını kontrol edip tekrar dene.',
      );
      return;
    }
    NearbyVenueService.instance.selectCity(
      name: area.name,
      latitude: area.latitude,
      longitude: area.longitude,
      south: area.south,
      west: area.west,
      north: area.north,
      east: area.east,
    );
    setState(() {
      _city = area.name;
      _center = LatLng(area.latitude, area.longitude);
      _camera = null;
      _selectedId = null;
      _venues.clear();
      _locating = false;
    });
    await _reload();
  }

  Future<void> _reload() async {
    if (_city == null && _position == null) return;
    final generation = ++_generation;
    setState(() {
      _loading.clear();
      _loading.add(0);
      _errors.clear();
    });
    await Future.wait([
      () async {
        try {
          final spots = await widget.source.spots();
          if (mounted && generation == _generation)
            setState(() => _spots = spots);
        } catch (_) {
          if (mounted && generation == _generation)
            setState(() => _errors.add(0));
        } finally {
          if (mounted && generation == _generation)
            setState(() => _loading.remove(0));
        }
      }(),
      for (final index in _filters.where((i) => i > 0))
        _loadVenues(index, generation),
    ]);
  }

  Future<void> _loadVenues(int index, int generation) async {
    setState(() {
      _loading.add(index);
      _errors.remove(index);
    });
    void update(List<NearbyVenue> venues) {
      if (!mounted || generation != _generation) return;
      setState(() => _venues[index] = venues);
    }

    try {
      final venues = await widget.source.venues(
        category: NearbyVenueCategory.values[index - 1],
        latitude: _center.latitude,
        longitude: _center.longitude,
        onUpdate: update,
      );
      update(venues);
      // Ratings arrive independently, never blocking places or the map.
      unawaited(_loadRatings(venues, generation));
    } on VenueLoadException catch (error) {
      if (error.venues.isNotEmpty) update(error.venues);
      if (mounted && generation == _generation) {
        setState(() => _errors.add(index));
      }
    } catch (_) {
      if (mounted && generation == _generation)
        setState(() => _errors.add(index));
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading.remove(index));
    }
  }

  Future<void> _loadRatings(List<NearbyVenue> venues, int generation) async {
    for (var offset = 0; offset < venues.length; offset += 8) {
      if (!mounted || generation != _generation) return;
      await Future.wait(
        venues.skip(offset).take(8).map((venue) async {
          try {
            final rating = await widget.source.rating(
              venue.category.name,
              venue.id,
            );
            if (mounted && generation == _generation)
              setState(() => _ratings[_venueId(venue)] = rating);
          } catch (_) {
            /* No rating is preferable to an invented zero score. */
          }
        }),
      );
    }
  }

  String _venueId(NearbyVenue venue) =>
      'venue:${venue.category.name}:${venue.id}';

  List<_Place> get _visible {
    final query = foldPlaceText(_search.text);
    final result = <_Place>[
      if (_filters.contains(0))
        for (final spot in browseCitySpots(
          _spots,
          city: _city,
          query: _search.text,
        ))
          _Place('spot:${spot.id}', 0, spot),
      for (final index in _filters.where((i) => i != 0))
        for (final venue in _venues[index] ?? <NearbyVenue>[])
          if (foldPlaceText(
            '${venue.name} ${venue.address} ${venue.description}',
          ).contains(query))
            _Place(
              _venueId(venue),
              index,
              PhotoSpot(
                id: _venueId(venue),
                name: venue.name,
                city: _city ?? '',
                latitude: venue.latitude,
                longitude: venue.longitude,
                rating: _ratings[_venueId(venue)]?.average ?? 0,
                bestTime: venue.openingHours,
                angle: '',
                imageUrl: venue.imageUrl,
                category: venue.category.label,
                description: venue.description,
                tags: const ['FirestoreDoğrulanmış'],
              ),
              venue: venue,
            ),
    ];
    result.sort((a, b) {
      if (_nearest && _position != null) {
        final order = _distance(a).compareTo(_distance(b));
        if (order != 0) return order;
      }
      final rating = b.spot.rating.compareTo(a.spot.rating);
      return rating != 0 ? rating : a.spot.name.compareTo(b.spot.name);
    });
    return result;
  }

  double _distance(_Place place) => Geolocator.distanceBetween(
    _position!.latitude,
    _position!.longitude,
    place.spot.latitude,
    place.spot.longitude,
  );
  String _distanceLabel(_Place place) {
    if (_position == null) return '';
    final meters = _distance(place);
    return meters < 1000
        ? '${meters.round()} m'
        : '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _sortNearest() async {
    if (_position == null) {
      final position = await LocationService.getCurrentPosition();
      if (!mounted) return;
      if (position == null) {
        _notice('En yakın sıralaması için konum iznini aç.');
        return;
      }
      _position = position;
    }
    setState(() => _nearest = true);
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _toggle(_Place place) {
    final service = RouteSelectionService.instance;
    if (!service.contains(place.id) && service.selected.value.length >= 12) {
      _notice('Bir rotaya en fazla 12 durak ekleyebilirsin.');
      return;
    }
    service.toggle(
      RoutePlace(
        id: place.id,
        spot: place.spot,
        name: place.spot.name,
        category: _labels[place.category],
        latitude: place.spot.latitude,
        longitude: place.spot.longitude,
      ),
    );
  }

  void _details(_Place place) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => place.venue == null
          ? SpotDetailScreen(spot: place.spot)
          : BusinessProfileScreen(
              venue: place.venue!,
              distance: _distanceLabel(place),
              rating: _ratings[place.id] ?? VenueRatingSummary.empty,
            ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final places = _visible;
    final busy = _locating || _filters.any(_loading.contains);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          if (!keyboardOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Mekânlar',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      setState(() => _map = !_map);
                    },
                    icon: Icon(
                      _map ? Icons.view_list_outlined : Icons.map_outlined,
                      size: 18,
                    ),
                    label: Text(_map ? 'Liste' : 'Harita'),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == 3 ? 0 : 6),
                      child: _category(i),
                    ),
                  ),
              ],
            ),
          ),
          if (!keyboardOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_city_outlined,
                    size: 20,
                    color: AppColors.cyan,
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: _chooseCity,
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                      ),
                      child: Text(
                        _city ?? 'Şehir seç',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _chooseCity,
                    tooltip: 'Şehri değiştir',
                    icon: const Icon(Icons.expand_more),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SpotSuggestionScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                    label: const Text('Yer öner'),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() => _selectedId = null),
              decoration: InputDecoration(
                hintText: 'Mekân veya yer ara',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Aramayı temizle',
                        onPressed: () => setState(() {
                          _search.clear();
                          _selectedId = null;
                        }),
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _nearest = false),
                  child: Text(
                    'Popüler',
                    style: TextStyle(
                      color: !_nearest ? AppColors.cyan : Colors.white60,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _sortNearest,
                  child: Text(
                    'En yakın',
                    style: TextStyle(
                      color: _nearest ? AppColors.cyan : Colors.white60,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  busy && places.isEmpty
                      ? 'Yükleniyor…'
                      : _filters.any(_errors.contains) && places.isEmpty
                      ? 'Yüklenemedi'
                      : '${places.length} yer',
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
          if (busy)
            const LinearProgressIndicator(minHeight: 2, color: AppColors.cyan),
          if (_filters.any(_errors.contains))
            Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    places.isEmpty
                        ? 'Yerler yüklenemedi.'
                        : 'Liste tamamen güncellenemedi.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _reload,
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
          Expanded(
            child: _map
                ? _mapView(places)
                : RefreshIndicator(
                    onRefresh: _reload,
                    child: places.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(
                                  busy
                                      ? 'Yerler yükleniyor…'
                                      : _filters.any(_errors.contains)
                                      ? 'Mekân bilgileri şu anda alınamıyor. Bağlantını kontrol edip tekrar dene.'
                                      : _city == null
                                      ? 'Gezi yerlerini görmek için şehir seç.'
                                      : 'Bu filtrelerde yer bulunamadı. Aramayı veya kategorileri değiştir.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            key: const PageStorageKey('places-list'),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: places.length,
                            itemBuilder: (context, index) => Column(
                              children: [
                                _card(places[index]),
                                if ((index + 1) % 8 == 0)
                                  const SponsoredNativeAd(),
                              ],
                            ),
                          ),
                  ),
          ),
          if (!keyboardOpen) const RouteSelectionButton(),
        ],
      ),
    );
  }

  Widget _category(int index) {
    final selected = _filters.contains(index);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() {
            if (_map) {
              if (!_filters.remove(index)) _filters.add(index);
            } else {
              _filters.clear();
              _filters.add(index);
            }
            _selectedId = null;
          });
          if (_filters.contains(index) &&
              index > 0 &&
              !_venues.containsKey(index) &&
              !_loading.contains(index)) {
            unawaited(_loadVenues(index, _generation));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected ? null : AppColors.surface,
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF173952), Color(0xFF342052)],
                  )
                : null,
            border: Border.all(
              color: selected ? AppColors.violet : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              Icon(
                _icons[index],
                size: 20,
                color: selected ? AppColors.cyan : Colors.white60,
              ),
              const SizedBox(height: 5),
              Text(
                _labels[index],
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(_Place place) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: InkWell(
      onTap: () => _details(place),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SpotImage(
                    spot: place.spot,
                    width: 88,
                    height: 94,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.spot.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${place.spot.city} · ${place.spot.category}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 12,
                        children: [
                          if (place.spot.rating > 0)
                            Text(
                              '★ ${place.spot.rating.toStringAsFixed(1)}',
                              style: const TextStyle(color: AppColors.cyan),
                            ),
                          if (_position != null)
                            Text(
                              _distanceLabel(place),
                              style: const TextStyle(
                                color: AppColors.cyan,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      if (place.venue?.openingHours.isNotEmpty == true)
                        const Text(
                          'Çalışma saati mevcut',
                          style: TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (place.venue != null)
              VenueQualityBadge(
                venueKey: VenueRatingService.instance.venueKey(
                  place.venue!.category.name,
                  place.venue!.id,
                ),
              ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Mesaj olarak gönder',
                  icon: const Icon(Icons.send_outlined, size: 19),
                  onPressed: () => shareCardToChat(
                    context,
                    sharedType: place.venue == null ? 'spot' : 'venue',
                    sharedId: '${place.spot.latitude},${place.spot.longitude}',
                    title: place.spot.name,
                    imageUrl: place.spot.imageUrl,
                  ),
                ),
                const Spacer(),
                ValueListenableBuilder<Map<String, RoutePlace>>(
                  valueListenable: RouteSelectionService.instance.selected,
                  builder: (context, selected, _) {
                    final added = selected.containsKey(place.id);
                    return TextButton.icon(
                      onPressed: () => _toggle(place),
                      icon: Icon(
                        added ? Icons.check_circle : Icons.add_circle_outline,
                        size: 19,
                      ),
                      label: Text(added ? 'Rotaya eklendi' : 'Rotaya ekle'),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _mapView(List<_Place> places) {
    final selected = places.where((p) => p.id == _selectedId).firstOrNull;
    return Stack(
      children: [
        GoogleMap(
          key: ValueKey(_city),
          style: '[{"elementType":"geometry","stylers":[{"color":"#141b29"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#aab8cf"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#141b29"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#303a51"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#091326"}]}]',
          initialCameraPosition:
              _camera ??
              CameraPosition(target: _center, zoom: _city == null ? 6 : 12),
          onCameraMove: (camera) => _camera = camera,
          myLocationEnabled: _position != null,
          myLocationButtonEnabled: _position != null,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          padding: EdgeInsets.only(bottom: selected == null ? 0 : 210),
          onTap: (_) => setState(() => _selectedId = null),
          markers: {
            for (final place in places)
              Marker(
                markerId: MarkerId(place.id),
                position: LatLng(place.spot.latitude, place.spot.longitude),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  [
                    BitmapDescriptor.hueCyan,
                    BitmapDescriptor.hueViolet,
                    BitmapDescriptor.hueAzure,
                    BitmapDescriptor.hueBlue,
                  ][place.category],
                ),
                onTap: () => setState(() => _selectedId = place.id),
              ),
          },
        ),
        if (_filters.isEmpty)
          const Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Haritada görmek istediğin kategorileri seç.'),
              ),
            ),
          ),
        if (selected != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(child: _card(selected)),
            ),
          ),
      ],
    );
  }
}

class _Place {
  final String id;
  final int category;
  final PhotoSpot spot;
  final NearbyVenue? venue;
  const _Place(this.id, this.category, this.spot, {this.venue});
}

class _CityPicker extends StatefulWidget {
  const _CityPicker();
  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final cities = turkeyCities
        .where((city) => foldPlaceText(city).contains(foldPlaceText(_query)))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Şehir seç',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Şehir ara',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: cities.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(cities[index]),
                  onTap: () => Navigator.pop(context, cities[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared data boundary for live catalog access and isolated interface checks.
class PlacesDataSource {
  const PlacesDataSource();
  String? get selectedCity => NearbyVenueService.instance.selectedCityName;
  Future<List<PhotoSpot>> spots() => SpotRepository.instance.discover();
  Future<List<NearbyVenue>> venues({
    required NearbyVenueCategory category,
    required double latitude,
    required double longitude,
    void Function(List<NearbyVenue>)? onUpdate,
  }) => NearbyVenueService.instance.nearby(
    category: category,
    latitude: latitude,
    longitude: longitude,
    onUpdate: onUpdate,
    reportIncomplete: true,
  );
  Future<VenueRatingSummary> rating(String category, String id) =>
      VenueRatingService.instance.summary(category, id);
}
