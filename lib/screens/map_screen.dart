import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/photo_spot.dart';
import '../models/nearby_venue.dart';
import '../models/social_event.dart';
import '../models/user_map_point.dart';
import '../services/activity_demand_service.dart';
import '../services/road_route_service.dart';
import '../services/nearby_venue_service.dart';
import '../services/social_event_service.dart';
import '../services/spot_repository.dart';
import '../services/user_map_point_service.dart';
import '../widgets/spot_image.dart';
import 'route_planner_screen.dart';
import 'social_events_screen.dart';
import 'spot_detail_screen.dart';

enum _MapContentFilter { all, spots, events, mine }

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  bool _mapDisposed = false;
  double _mapZoom = 5;
  PhotoSpot? _selectedSpot;
  SocialEvent? _selectedEvent;
  UserMapPoint? _selectedUserPoint;
  NearbyVenue? _selectedVenue;
  List<PhotoSpot> _spots = List<PhotoSpot>.from(demoSpots);
  List<SocialEvent> _events = const [];
  List<UserMapPoint> _userPoints = const [];
  List<NearbyVenue> _nearbyVenues = const [];
  final List<PhotoSpot> _routeSpots = [];
  bool _loadingSpots = true;
  bool _loadingNearbyVenues = false;
  bool _locationPermissionGranted = false;
  bool _gettingLocation = false;
  bool _loadingRoadRoute = false;
  Position? _currentPosition;
  RoadRouteResult? _roadRoute;
  _MapContentFilter _filter = _MapContentFilter.all;

  static const LatLng _defaultLocation = LatLng(38.6810, 39.2264);
  static const List<String> _pointCategories = <String>[
    'Kafe',
    'Yeme-İçme',
    'Otel',
    'Gezilecek Yer',
    'Diğer',
  ];

  @override
  void initState() {
    super.initState();
    _loadSpots();
    _prepareLocation();
  }

  @override
  void dispose() {
    _mapDisposed = true;
    // The GoogleMap widget owns the underlying platform view disposal. Drop our
    // reference immediately so late async route/location callbacks cannot use it.
    _mapController = null;
    super.dispose();
  }

  Future<void> _animateMap(CameraUpdate update) async {
    if (!mounted || _mapDisposed) return;
    final controller = _mapController;
    if (controller == null) return;
    try {
      await controller.animateCamera(update);
    } catch (_) {
      // Platform view may already be tearing down while a route is popped.
      if (identical(_mapController, controller)) _mapController = null;
    }
  }

  Future<void> _loadSpots() async {
    try {
      final loaded = await SpotRepository.instance.loadSpots();
      if (!mounted) return;
      setState(() {
        _spots = loaded.isEmpty ? List<PhotoSpot>.from(demoSpots) : loaded;
        _loadingSpots = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _spots = List<PhotoSpot>.from(demoSpots);
        _loadingSpots = false;
      });
    }
  }

  LatLng? _eventPosition(SocialEvent event) {
    if (event.latitude != null && event.longitude != null) {
      return LatLng(event.latitude!, event.longitude!);
    }
    final spotId = event.spotId;
    if (spotId != null && spotId.isNotEmpty) {
      for (final spot in _spots) {
        if (spot.id == spotId) return LatLng(spot.latitude, spot.longitude);
      }
    }
    final target = (event.spotName ?? event.locationLabel).trim().toLowerCase();
    if (target.isNotEmpty) {
      for (final spot in _spots) {
        final name = spot.name.trim().toLowerCase();
        if (name == target || name.contains(target) || target.contains(name)) {
          return LatLng(spot.latitude, spot.longitude);
        }
      }
    }
    return null;
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};

    if (_filter == _MapContentFilter.all ||
        _filter == _MapContentFilter.spots) {
      final candidates = _mapZoom < 7
          ? _spots.take(120)
          : _mapZoom < 9
          ? _spots.take(320)
          : _spots;
      final cellSize = _mapZoom < 7 ? 2.2 : _mapZoom < 9 ? .65 : _mapZoom < 11 ? .18 : .025;
      final grouped = <String, List<PhotoSpot>>{};
      for (final spot in candidates) {
        final key = '${(spot.latitude / cellSize).floor()}:${(spot.longitude / cellSize).floor()}';
        grouped.putIfAbsent(key, () => <PhotoSpot>[]).add(spot);
      }
      for (final group in grouped.values) {
        final spot = group.first;
        final inRoute = _routeSpots.any((item) => item.id == spot.id);
        markers.add(
          Marker(
            markerId: MarkerId('spot_${spot.id}'),
            position: LatLng(spot.latitude, spot.longitude),
            icon: inRoute
                ? BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  )
                : BitmapDescriptor.defaultMarker,
            infoWindow: InfoWindow(
              title: spot.name,
              snippet: group.length > 1
                  ? '${group.length} yakın nokta • Yakınlaştırarak keşfet'
                  : inRoute
                  ? '${spot.city} • Rotaya eklendi'
                  : '${spot.city} • ⭐ ${spot.rating}',
            ),
            onTap: () => _selectDestination(
              destination: LatLng(spot.latitude, spot.longitude),
              spot: spot,
            ),
          ),
        );
      }
      for (final venue in _nearbyVenues) {
        markers.add(
          Marker(
            markerId: MarkerId('venue_${venue.category.name}_${venue.id}'),
            position: LatLng(venue.latitude, venue.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              switch (venue.category) {
                NearbyVenueCategory.cafe => BitmapDescriptor.hueOrange,
                NearbyVenueCategory.dining => BitmapDescriptor.hueRose,
                NearbyVenueCategory.hotel => BitmapDescriptor.hueAzure,
              },
            ),
            infoWindow: InfoWindow(
              title: venue.name,
              snippet: venue.category.label,
            ),
            onTap: () => _selectDestination(
              destination: LatLng(venue.latitude, venue.longitude),
              venue: venue,
            ),
          ),
        );
      }
    }

    if (_filter == _MapContentFilter.all ||
        _filter == _MapContentFilter.events) {
      final now = DateTime.now();
      for (final event in _events.where(
        (e) => e.status == 'open' && e.startsAt.isAfter(now),
      )) {
        final position = _eventPosition(event);
        if (position == null) continue;
        markers.add(
          Marker(
            markerId: MarkerId('event_${event.id}'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueViolet,
            ),
            infoWindow: InfoWindow(
              title: '🎟️ ${event.title}',
              snippet: '${event.typeLabel} • ${_eventDate(event.startsAt)}',
            ),
            onTap: () =>
                _selectDestination(destination: position, event: event),
          ),
        );
      }
    }

    if (_filter == _MapContentFilter.all || _filter == _MapContentFilter.mine) {
      for (final point in _userPoints) {
        final routeId = 'user-${point.id}';
        final inRoute = _routeSpots.any((item) => item.id == routeId);
        markers.add(
          Marker(
            markerId: MarkerId('user_${point.id}'),
            position: LatLng(point.latitude, point.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              inRoute ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueAzure,
            ),
            infoWindow: InfoWindow(
              title: point.name,
              snippet: point.communitySuggested
                  ? '${point.category} • Topluluğa önerildi'
                  : '${point.category} • Özel noktan',
            ),
            onTap: () => _selectDestination(
              destination: LatLng(point.latitude, point.longitude),
              userPoint: point,
            ),
          ),
        );
      }
    }
    return markers;
  }

  Set<Polyline> get _polylines {
    final route = _roadRoute;
    if (route == null || route.points.length < 2) return const <Polyline>{};
    return {
      Polyline(
        polylineId: const PolylineId('selected_road_route'),
        points: route.points,
        color: const Color(0xFF62E6D2),
        width: 6,
        geodesic: false,
      ),
    };
  }

  String _eventDate(DateTime date) {
    final d = date.toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _prepareLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever)
      return;
    if (!mounted) return;
    setState(() => _locationPermissionGranted = true);
    await _goToMyLocation(showErrors: false);
  }

  Future<void> _goToMyLocation({bool showErrors = true}) async {
    if (_gettingLocation) return;
    if (mounted) setState(() => _gettingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (showErrors && mounted) _message('Konum servisi kapalı.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (showErrors && mounted) _message('Konum izni gerekli.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _locationPermissionGranted = true;
        _currentPosition = position;
        _selectedSpot = null;
        _selectedEvent = null;
        _selectedUserPoint = null;
        _selectedVenue = null;
        _roadRoute = null;
      });
      unawaited(_loadNearbyVenues(position));
      await _animateMap(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15,
        ),
      );
    } catch (_) {
      if (showErrors && mounted) _message('Konum alınamadı.');
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _selectDestination({
    required LatLng destination,
    PhotoSpot? spot,
    SocialEvent? event,
    UserMapPoint? userPoint,
    NearbyVenue? venue,
  }) async {
    if (!mounted || _mapDisposed) return;
    setState(() {
      _selectedSpot = spot;
      _selectedEvent = event;
      _selectedUserPoint = userPoint;
      _selectedVenue = venue;
      _roadRoute = null;
      _loadingRoadRoute = _currentPosition != null;
    });
    await _animateMap(CameraUpdate.newLatLngZoom(destination, 15));

    final current = _currentPosition;
    if (current == null) return;
    final route = await RoadRouteService.instance.drivingRoute([
      LatLng(current.latitude, current.longitude),
      destination,
    ]);
    if (!mounted) return;
    setState(() {
      _roadRoute = route;
      _loadingRoadRoute = false;
    });
    if (route != null && route.points.length > 1) {
      final bounds = _boundsFor(route.points);
      await _animateMap(CameraUpdate.newLatLngBounds(bounds, 54));
    }
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points.skip(1)) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  String _distanceText(double latitude, double longitude) {
    if (_loadingRoadRoute) return 'Yol mesafesi hesaplanıyor…';
    final route = _roadRoute;
    if (route != null) return '${route.distanceLabel} • ${route.durationLabel}';
    if (_currentPosition == null) return '';
    return 'Yol mesafesi alınamadı';
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  void _clearSelection() {
    if (!mounted || _mapDisposed) return;
    setState(() {
      _selectedSpot = null;
      _selectedEvent = null;
      _selectedUserPoint = null;
      _selectedVenue = null;
      _roadRoute = null;
      _loadingRoadRoute = false;
    });
  }

  Future<void> _loadNearbyVenues(Position position) async {
    if (_loadingNearbyVenues) return;
    if (mounted) setState(() => _loadingNearbyVenues = true);
    try {
      final groups = await Future.wait(
        NearbyVenueCategory.values.map(
          (category) => _loadVenueCategory(category, position),
        ),
      );
      if (!mounted) return;
      setState(() {
        _nearbyVenues = groups.expand((items) => items).toList(growable: false);
      });
    } catch (_) {
      if (mounted) _message('Yakındaki mekanların bir kısmı yüklenemedi.');
    } finally {
      if (mounted) setState(() => _loadingNearbyVenues = false);
    }
  }

  Future<List<NearbyVenue>> _loadVenueCategory(
    NearbyVenueCategory category,
    Position position,
  ) async {
    try {
      final venues = await NearbyVenueService.instance.nearby(
        category: category,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      venues.sort((a, b) {
        final aDistance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          a.latitude,
          a.longitude,
        );
        final bDistance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          b.latitude,
          b.longitude,
        );
        return aDistance.compareTo(bDistance);
      });
      return venues.take(20).toList(growable: false);
    } catch (_) {
      return const <NearbyVenue>[];
    }
  }

  void _showAll() {
    _animateMap(CameraUpdate.newLatLngZoom(_defaultLocation, 5));
    _clearSelection();
  }

  void _openSpot(PhotoSpot spot) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)),
    );
  }

  void _openRoutePlanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RoutePlannerScreen(initialSpots: List<PhotoSpot>.from(_routeSpots)),
      ),
    );
  }

  void _toggleRouteSpot(PhotoSpot spot) {
    final index = _routeSpots.indexWhere((item) => item.id == spot.id);
    setState(() {
      if (index >= 0) {
        _routeSpots.removeAt(index);
      } else {
        _routeSpots.add(spot);
      }
    });
    _message(
      index >= 0
          ? '${spot.name} rotadan çıkarıldı.'
          : '${spot.name} rotaya eklendi.',
    );
  }

  PhotoSpot _asRouteSpot(UserMapPoint point) => PhotoSpot(
    id: 'user-${point.id}',
    name: point.name,
    city: 'Kendi Noktan',
    latitude: point.latitude,
    longitude: point.longitude,
    rating: 0,
    bestTime: 'İstediğin zaman',
    angle: '',
    imageUrl: '',
    category: point.category,
    description: point.communitySuggested
        ? 'Topluluğa önerdiğin harita noktası.'
        : 'Yalnızca sana ait harita noktası.',
    tags: const ['Kullanıcı Noktası'],
  );

  void _toggleUserPointRoute(UserMapPoint point) {
    _toggleRouteSpot(_asRouteSpot(point));
  }

  PhotoSpot _asVenueRouteSpot(NearbyVenue venue) => PhotoSpot(
    id: 'venue:${venue.category.name}:${venue.id}',
    name: venue.name,
    city: venue.address,
    latitude: venue.latitude,
    longitude: venue.longitude,
    rating: 0,
    bestTime: venue.openingHours,
    angle: '',
    imageUrl: '',
    category: venue.category.label,
    description: venue.address,
    tags: [venue.category.label],
  );

  void _toggleVenueRoute(NearbyVenue venue) {
    _toggleRouteSpot(_asVenueRouteSpot(venue));
  }

  void _openEvents() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const Scaffold(body: SafeArea(child: SocialEventsScreen())),
      ),
    );
  }

  Future<void> _addPointAt(LatLng position) async {
    final nameController = TextEditingController();
    var category = _pointCategories.first;
    var communitySuggested = false;

    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF111417),
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            4,
            18,
            MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Haritaya nokta ekle',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Bu nokta önce sana özel kaydedilir. İstersen topluluğa da önerebilirsin.',
                style: TextStyle(color: Colors.white60, height: 1.35),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Nokta adı',
                  hintText: 'Örn. Gün batımı seyir noktası',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: _pointCategories
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setSheetState(() => category = value);
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Topluluğa öner'),
                subtitle: const Text(
                  'Onaylanana kadar yalnızca sen görürsün.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                value: communitySuggested,
                onChanged: (value) =>
                    setSheetState(() => communitySuggested = value),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: const Text('Noktayı Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldSave != true) {
      nameController.dispose();
      return;
    }
    try {
      await UserMapPointService.instance.addPoint(
        name: nameController.text,
        category: category,
        latitude: position.latitude,
        longitude: position.longitude,
        communitySuggested: communitySuggested,
      );
      if (!mounted) return;
      _message(
        communitySuggested
            ? 'Nokta kaydedildi ve topluluğa önerildi.'
            : 'Nokta sana özel kaydedildi.',
      );
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      nameController.dispose();
    }
  }

  Future<void> _deleteUserPoint(UserMapPoint point) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Noktayı sil?'),
        content: Text('${point.name} kendi haritandan kaldırılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    await UserMapPointService.instance.deleteMine(point.id);
    if (!mounted) return;
    _clearSelection();
    _message('Nokta silindi.');
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection =
        _selectedSpot != null ||
        _selectedEvent != null ||
        _selectedUserPoint != null ||
        _selectedVenue != null;
    final bottomOffset = hasSelection ? 204.0 : 24.0;

    return StreamBuilder<List<UserMapPoint>>(
      stream: UserMapPointService.instance.watchMine(),
      builder: (context, userPointSnapshot) {
        _userPoints = userPointSnapshot.data ?? _userPoints;
        return StreamBuilder<List<SocialEvent>>(
          stream: SocialEventService.instance.watchUpcoming(limit: 120),
          builder: (context, eventSnapshot) {
            _events = eventSnapshot.data ?? _events;
            return StreamBuilder<List<ActivityDemand>>(
              stream: ActivityDemandService.instance.watchActive(limit: 600),
              builder: (context, demandSnapshot) {
                final activeDemands = demandSnapshot.data ?? const <ActivityDemand>[];
                return SafeArea(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: _defaultLocation,
                      zoom: 10.5,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: _locationPermissionGranted,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: true,
                    onLongPress: _addPointAt,
                    onMapCreated: (controller) async {
                      if (!mounted || _mapDisposed) return;
                      _mapController = controller;
                      final position = _currentPosition;
                      if (position != null) {
                        await _animateMap(
                          CameraUpdate.newLatLngZoom(
                            LatLng(position.latitude, position.longitude),
                            15,
                          ),
                        );
                      }
                    },
                    onCameraMove: (position) {
                      if (!mounted || _mapDisposed) return;
                      if ((position.zoom - _mapZoom).abs() >= .75) {
                        setState(() => _mapZoom = position.zoom);
                      }
                    },
                  ),
                  Positioned(
                    top: 14,
                    left: 12,
                    right: 12,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1113)
                                .withValues(alpha: .95),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.explore_outlined,
                                color: Color(0xFFB7BCC2),
                              ),
                              const SizedBox(width: 9),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Harita',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      'Uzun basarak kendi noktanı ekle',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_loadingSpots || _loadingNearbyVenues)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFB7BCC2),
                                  ),
                                ),
                              IconButton(
                                tooltip: _routeSpots.isEmpty
                                    ? 'Rota oluştur'
                                    : 'Rotayı aç (${_routeSpots.length})',
                                onPressed: _openRoutePlanner,
                                icon: Badge(
                                  isLabelVisible: _routeSpots.isNotEmpty,
                                  label: Text('${_routeSpots.length}'),
                                  child: const Icon(
                                    Icons.route_rounded,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Nokta ekle',
                                onPressed: () async {
                                  final camera = await _mapController
                                      ?.getLatLng(
                                        ScreenCoordinate(
                                          x:
                                              MediaQuery.sizeOf(context)
                                                  .width ~/
                                              2,
                                          y:
                                              MediaQuery.sizeOf(context)
                                                  .height ~/
                                              2,
                                        ),
                                      );
                                  if (camera != null) await _addPointAt(camera);
                                },
                                icon: const Icon(
                                  Icons.add_location_alt_outlined,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: _MapLegend(),
                        ),
                        if (activeDemands.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Material(
                              color: const Color(0xFF0F1113).withValues(alpha: .95),
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: _openEvents,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.people_alt_outlined, size: 17, color: Color(0xFF62E6D2)),
                                      const SizedBox(width: 7),
                                      Text(
                                        '${activeDemands.length} topluluk sinyali',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text('• kişi konumu gösterilmez', style: TextStyle(fontSize: 10.5, color: Colors.white54)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1113)
                                .withValues(alpha: .95),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              _FilterButton(
                                label: 'Tümü',
                                selected: _filter == _MapContentFilter.all,
                                onTap: () => setState(
                                  () => _filter = _MapContentFilter.all,
                                ),
                              ),
                              _FilterButton(
                                label: 'Yerler',
                                selected: _filter == _MapContentFilter.spots,
                                onTap: () => setState(() {
                                  _filter = _MapContentFilter.spots;
                                  _selectedEvent = null;
                                  _selectedUserPoint = null;
                                }),
                              ),
                              _FilterButton(
                                label: 'Etkinlik',
                                selected: _filter == _MapContentFilter.events,
                                onTap: () => setState(() {
                                  _filter = _MapContentFilter.events;
                                  _selectedSpot = null;
                                  _selectedUserPoint = null;
                                  _selectedVenue = null;
                                }),
                              ),
                              _FilterButton(
                                label: 'Benim',
                                selected: _filter == _MapContentFilter.mine,
                                onTap: () => setState(() {
                                  _filter = _MapContentFilter.mine;
                                  _selectedSpot = null;
                                  _selectedEvent = null;
                                  _selectedVenue = null;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: bottomOffset + 68,
                    child: FloatingActionButton(
                      heroTag: 'myLocation',
                      backgroundColor: const Color(0xFF0F1113),
                      foregroundColor: const Color(0xFFB7BCC2),
                      onPressed: _gettingLocation ? null : _goToMyLocation,
                      child: _gettingLocation
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFFB7BCC2),
                              ),
                            )
                          : const Icon(Icons.my_location_rounded),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: bottomOffset,
                    child: FloatingActionButton(
                      heroTag: 'allMapContent',
                      backgroundColor: const Color(0xFF0F1113),
                      foregroundColor: const Color(0xFFB7BCC2),
                      onPressed: _showAll,
                      child: const Icon(Icons.fit_screen),
                    ),
                  ),
                  if (_selectedSpot != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _SpotCard(
                        spot: _selectedSpot!,
                        distanceLabel: _distanceText(
                          _selectedSpot!.latitude,
                          _selectedSpot!.longitude,
                        ),
                        inRoute: _routeSpots.any(
                          (item) => item.id == _selectedSpot!.id,
                        ),
                        onClose: _clearSelection,
                        onOpen: () => _openSpot(_selectedSpot!),
                        onToggleRoute: () => _toggleRouteSpot(_selectedSpot!),
                      ),
                    ),
                  if (_selectedEvent != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _EventCard(
                        event: _selectedEvent!,
                        dateLabel: _eventDate(_selectedEvent!.startsAt),
                        distanceLabel: () {
                          final p = _eventPosition(_selectedEvent!);
                          return p == null
                              ? ''
                              : _distanceText(p.latitude, p.longitude);
                        }(),
                        onClose: _clearSelection,
                        onOpen: _openEvents,
                      ),
                    ),
                  if (_selectedUserPoint != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _UserPointCard(
                        point: _selectedUserPoint!,
                        distanceLabel: _distanceText(
                          _selectedUserPoint!.latitude,
                          _selectedUserPoint!.longitude,
                        ),
                        inRoute: _routeSpots.any(
                          (item) => item.id == 'user-${_selectedUserPoint!.id}',
                        ),
                        onClose: _clearSelection,
                        onToggleRoute: () =>
                            _toggleUserPointRoute(_selectedUserPoint!),
                        onDelete: () => _deleteUserPoint(_selectedUserPoint!),
                      ),
                    ),
                  if (_selectedVenue != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _VenueCard(
                        venue: _selectedVenue!,
                        distanceLabel: _distanceText(
                          _selectedVenue!.latitude,
                          _selectedVenue!.longitude,
                        ),
                        inRoute: _routeSpots.any(
                          (item) =>
                              item.id ==
                              'venue:${_selectedVenue!.category.name}:${_selectedVenue!.id}',
                        ),
                        onClose: _clearSelection,
                        onToggleRoute: () => _toggleVenueRoute(_selectedVenue!),
                      ),
                    ),
                ],
              ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xE60F1113),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: Colors.white10),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendDot(Colors.red, 'Yer'),
        SizedBox(width: 9),
        _LegendDot(Colors.purple, 'Etkinlik'),
        SizedBox(width: 9),
        _LegendDot(Colors.lightBlue, 'Benim'),
      ],
    ),
  );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w700)),
    ],
  );
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFB7BCC2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.black : Colors.white70,
          ),
        ),
      ),
    ),
  );
}

class _EventCard extends StatelessWidget {
  final SocialEvent event;
  final String dateLabel;
  final String distanceLabel;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  const _EventCard({
    required this.event,
    required this.dateLabel,
    required this.distanceLabel,
    required this.onClose,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF161226),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Color(0x334B2A8A),
              child: Icon(
                Icons.confirmation_number_outlined,
                color: Color(0xFFB794F6),
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${event.typeLabel} • $dateLabel',
                    style: const TextStyle(
                      color: Color(0xFFB794F6),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  if (distanceLabel.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      distanceLabel,
                      style: const TextStyle(
                        color: Color(0xFF62E6D2),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    event.locationLabel.isNotEmpty
                        ? event.locationLabel
                        : event.city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, color: Colors.white54),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SpotCard extends StatelessWidget {
  final PhotoSpot spot;
  final String distanceLabel;
  final bool inRoute;
  final VoidCallback onClose;
  final VoidCallback onOpen;
  final VoidCallback onToggleRoute;

  const _SpotCard({
    required this.spot,
    required this.distanceLabel,
    required this.inRoute,
    required this.onClose,
    required this.onOpen,
    required this.onToggleRoute,
  });

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF0F1113),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                  Text(
                    spot.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    spot.city,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  if (distanceLabel.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      distanceLabel,
                      style: const TextStyle(
                        color: Color(0xFF62E6D2),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text('⭐ ${spot.rating} • ${spot.category}'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onToggleRoute,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(
                        inRoute
                            ? Icons.check_circle_rounded
                            : Icons.add_location_alt_outlined,
                        size: 19,
                      ),
                      label: Text(inRoute ? 'Rotada' : 'Rotaya Ekle'),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, color: Colors.white54),
            ),
          ],
        ),
      ),
    ),
  );
}

class _VenueCard extends StatelessWidget {
  final NearbyVenue venue;
  final String distanceLabel;
  final bool inRoute;
  final VoidCallback onClose;
  final VoidCallback onToggleRoute;

  const _VenueCard({
    required this.venue,
    required this.distanceLabel,
    required this.inRoute,
    required this.onClose,
    required this.onToggleRoute,
  });

  IconData get _icon => switch (venue.category) {
    NearbyVenueCategory.cafe => Icons.local_cafe_outlined,
    NearbyVenueCategory.dining => Icons.restaurant_outlined,
    NearbyVenueCategory.hotel => Icons.hotel_outlined,
  };

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF0F1113),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: const Color(0x2237E3D0),
            child: Icon(_icon, color: const Color(0xFF62E6D2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  venue.category.label,
                  style: const TextStyle(color: Colors.white60),
                ),
                if (venue.address.isNotEmpty)
                  Text(
                    venue.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                if (distanceLabel.isNotEmpty)
                  Text(
                    distanceLabel,
                    style: const TextStyle(
                      color: Color(0xFF62E6D2),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                TextButton.icon(
                  onPressed: onToggleRoute,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(
                    inRoute
                        ? Icons.check_circle_rounded
                        : Icons.add_location_alt_outlined,
                    size: 18,
                  ),
                  label: Text(inRoute ? 'Rotada' : 'Rotaya Ekle'),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
    ),
  );
}

class _UserPointCard extends StatelessWidget {
  final UserMapPoint point;
  final String distanceLabel;
  final bool inRoute;
  final VoidCallback onClose;
  final VoidCallback onToggleRoute;
  final VoidCallback onDelete;

  const _UserPointCard({
    required this.point,
    required this.distanceLabel,
    required this.inRoute,
    required this.onClose,
    required this.onToggleRoute,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF0D1719),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0x2237E3D0),
            child: Icon(
              Icons.person_pin_circle_outlined,
              color: Color(0xFF62E6D2),
              size: 29,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  point.category,
                  style: const TextStyle(color: Colors.white60),
                ),
                if (distanceLabel.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    distanceLabel,
                    style: const TextStyle(
                      color: Color(0xFF62E6D2),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  point.communitySuggested
                      ? 'Topluluk onayı bekliyor'
                      : 'Yalnızca sen görüyorsun',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onToggleRoute,
                      icon: Icon(
                        inRoute
                            ? Icons.check_circle_rounded
                            : Icons.add_road_rounded,
                        size: 18,
                      ),
                      label: Text(inRoute ? 'Rotada' : 'Rotaya Ekle'),
                    ),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      label: const Text(
                        'Sil',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
    ),
  );
}
