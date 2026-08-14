import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/photo_spot.dart';
import '../services/spot_repository.dart';
import '../widgets/spot_image.dart';

enum RouteTravelMode { driving, walking, bicycling }

extension RouteTravelModeX on RouteTravelMode {
  String get label => switch (this) {
        RouteTravelMode.driving => 'Araç',
        RouteTravelMode.walking => 'Yürüyüş',
        RouteTravelMode.bicycling => 'Bisiklet',
      };

  IconData get icon => switch (this) {
        RouteTravelMode.driving => Icons.directions_car_outlined,
        RouteTravelMode.walking => Icons.directions_walk_rounded,
        RouteTravelMode.bicycling => Icons.directions_bike_rounded,
      };

  String get googleValue => switch (this) {
        RouteTravelMode.driving => 'driving',
        RouteTravelMode.walking => 'walking',
        RouteTravelMode.bicycling => 'bicycling',
      };
}

class RoutePlannerScreen extends StatefulWidget {
  final PhotoSpot? initialSpot;

  const RoutePlannerScreen({super.key, this.initialSpot});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  static const _background = Color(0xFF090A0C);
  static const _surface = Color(0xFF121416);
  static const _surfaceAlt = Color(0xFF1A1D20);
  static const _border = Color(0xFF2A2E33);
  static const _accent = Color(0xFFB7BCC2);

  GoogleMapController? _mapController;
  List<PhotoSpot> _allSpots = const [];
  final List<PhotoSpot> _stops = [];
  Position? _currentPosition;
  bool _loading = true;
  bool _gettingLocation = false;
  bool _useCurrentLocation = true;
  RouteTravelMode _travelMode = RouteTravelMode.driving;

  @override
  void initState() {
    super.initState();
    if (widget.initialSpot != null) {
      _stops.add(widget.initialSpot!);
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final spots = await SpotRepository.instance.loadSpots();
      if (!mounted) return;
      setState(() {
        _allSpots = spots;
        _loading = false;
      });
      await _readCurrentLocation(requestIfNeeded: false);
      await _fitRoute();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _readCurrentLocation({required bool requestIfNeeded}) async {
    if (_gettingLocation) return;
    setState(() => _gettingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (requestIfNeeded) _message('Konum servisi kapalı.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestIfNeeded) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (requestIfNeeded) {
          _message('Başlangıç için konum izni gerekli.');
        }
        if (mounted) setState(() => _useCurrentLocation = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _useCurrentLocation = true;
        _allSpots = _sortedFromCurrentPosition(_allSpots, position);
        _stops
          ..sort((a, b) => _distanceFromPosition(position, a)
              .compareTo(_distanceFromPosition(position, b)));
      });
    } catch (_) {
      if (requestIfNeeded) _message('Konum alınamadı.');
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  double _distanceFromPosition(Position position, PhotoSpot spot) =>
      Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        spot.latitude,
        spot.longitude,
      );

  List<PhotoSpot> _sortedFromCurrentPosition(
    Iterable<PhotoSpot> spots,
    Position position,
  ) {
    final sorted = spots.toList();
    sorted.sort((a, b) => _distanceFromPosition(position, a)
        .compareTo(_distanceFromPosition(position, b)));
    return sorted;
  }

  double? _distanceToMeKm(PhotoSpot spot) {
    final current = _currentPosition;
    if (current == null) return null;
    return _distanceFromPosition(current, spot) / 1000;
  }

  List<PhotoSpot> get _nearbyMapSpots {
    final selectedIds = _stops.map((spot) => spot.id).toSet();
    final candidates =
        _allSpots.where((spot) => !selectedIds.contains(spot.id)).toList();
    final current = _currentPosition;
    if (current != null) {
      candidates.sort((a, b) => _distanceFromPosition(current, a)
          .compareTo(_distanceFromPosition(current, b)));
    }
    return candidates.take(60).toList();
  }

  Future<void> _addSpotFromMap(PhotoSpot spot) async {
    if (_stops.any((item) => item.id == spot.id)) return;
    setState(() {
      _stops.add(spot);
      final current = _currentPosition;
      if (current != null) {
        _stops.sort((a, b) => _distanceFromPosition(current, a)
            .compareTo(_distanceFromPosition(current, b)));
      }
    });
    await Future<void>.delayed(const Duration(milliseconds: 70));
    await _fitRoute();
    _message('${spot.name} rotaya eklendi.');
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};
    final current = _currentPosition;
    if (_useCurrentLocation && current != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('route_origin'),
          position: LatLng(current.latitude, current.longitude),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Başlangıç • Konumum'),
        ),
      );
    }
    for (final spot in _nearbyMapSpots) {
      final km = _distanceToMeKm(spot);
      markers.add(
        Marker(
          markerId: MarkerId('nearby_${spot.id}'),
          position: LatLng(spot.latitude, spot.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet,
          ),
          infoWindow: InfoWindow(
            title: spot.name,
            snippet: km == null
                ? '${spot.city} • Rotaya eklemek için pine dokun'
                : '${spot.city} • ${km < 10 ? km.toStringAsFixed(1) : km.toStringAsFixed(0)} km • Dokun ve rotaya ekle',
          ),
          onTap: () => _addSpotFromMap(spot),
        ),
      );
    }

    for (var i = 0; i < _stops.length; i++) {
      final spot = _stops[i];
      markers.add(
        Marker(
          markerId: MarkerId('route_${spot.id}'),
          position: LatLng(spot.latitude, spot.longitude),
          infoWindow: InfoWindow(
            title: '${i + 1}. ${spot.name}',
            snippet: '${spot.city} • ${spot.bestTime}',
          ),
        ),
      );
    }
    return markers;
  }

  List<LatLng> get _routePoints {
    final points = <LatLng>[];
    final current = _currentPosition;
    if (_useCurrentLocation && current != null) {
      points.add(LatLng(current.latitude, current.longitude));
    }
    points.addAll(_stops.map((s) => LatLng(s.latitude, s.longitude)));
    return points;
  }

  Set<Polyline> get _polylines {
    final points = _routePoints;
    if (points.length < 2) return const <Polyline>{};
    return {
      Polyline(
        polylineId: const PolylineId('photo_route_preview'),
        points: points,
        width: 4,
        color: _accent,
        geodesic: true,
      ),
    };
  }

  double get _distanceKm {
    final points = _routePoints;
    if (points.length < 2) return 0;
    var meters = 0.0;
    for (var i = 1; i < points.length; i++) {
      meters += Geolocator.distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return meters / 1000;
  }

  Future<void> _fitRoute() async {
    final controller = _mapController;
    var points = _routePoints;
    if (controller == null) return;
    if (points.isEmpty && _currentPosition != null) {
      final current = _currentPosition!;
      points = [
        LatLng(current.latitude, current.longitude),
        ..._nearbyMapSpots.take(12).map(
              (spot) => LatLng(spot.latitude, spot.longitude),
            ),
      ];
    }
    if (points.isEmpty) return;
    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 14),
      );
      return;
    }

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    if ((maxLat - minLat).abs() < 0.0001) {
      minLat -= 0.002;
      maxLat += 0.002;
    }
    if ((maxLng - minLng).abs() < 0.0001) {
      minLng -= 0.002;
      maxLng += 0.002;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        46,
      ),
    );
  }

  Future<void> _pickSpot() async {
    if (_loading) return;
    final queryController = TextEditingController();
    var query = '';
    final selected = await showModalBottomSheet<PhotoSpot>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: _surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final key = _normalize(query);
          final excluded = _stops.map((s) => s.id).toSet();
          var matches = _allSpots.where((spot) {
            if (excluded.contains(spot.id)) return false;
            if (key.isEmpty) return true;
            final haystack = _normalize(
              '${spot.name} ${spot.city} ${spot.category} ${spot.tags.join(' ')}',
            );
            return haystack.contains(key);
          }).toList();
          final current = _currentPosition;
          if (current != null) {
            matches = _sortedFromCurrentPosition(matches, current);
          }
          matches = matches.take(80).toList();

          return FractionallySizedBox(
            heightFactor: .88,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Rotaya nokta ekle',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: queryController,
                    autofocus: true,
                    onChanged: (value) => setSheetState(() => query = value),
                    decoration: const InputDecoration(
                      hintText: 'Nokta, şehir veya kategori ara',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: matches.isEmpty
                      ? const Center(
                          child: Text(
                            'Eşleşen çekim noktası bulunamadı.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                          itemCount: matches.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: Colors.white10),
                          itemBuilder: (context, index) {
                            final spot = matches[index];
                            return ListTile(
                              leading: SpotImage(
                                spot: spot,
                                width: 52,
                                height: 52,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              title: Text(
                                spot.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Builder(
                                builder: (_) {
                                  final km = _distanceToMeKm(spot);
                                  final distanceLabel = km == null
                                      ? ''
                                      : ' • ${km < 10 ? km.toStringAsFixed(1) : km.toStringAsFixed(0)} km';
                                  return Text(
                                    '${spot.city} • ${spot.category}$distanceLabel • ★ ${spot.rating}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                              trailing: const Icon(Icons.add_circle_outline),
                              onTap: () => Navigator.pop(sheetContext, spot),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
    queryController.dispose();
    if (selected == null || !mounted) return;
    setState(() {
      _stops.add(selected);
      final current = _currentPosition;
      if (current != null) {
        _stops.sort((a, b) => _distanceFromPosition(current, a)
            .compareTo(_distanceFromPosition(current, b)));
      }
    });
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await _fitRoute();
  }

  Future<void> _optimizeOrder() async {
    if (_stops.length < 3) {
      _message('Akıllı sıralama için en az 3 çekim noktası ekle.');
      return;
    }

    var remaining = List<PhotoSpot>.from(_stops);
    final ordered = <PhotoSpot>[];
    double currentLat;
    double currentLng;
    final current = _currentPosition;
    if (_useCurrentLocation && current != null) {
      currentLat = current.latitude;
      currentLng = current.longitude;
    } else {
      final first = remaining.removeAt(0);
      ordered.add(first);
      currentLat = first.latitude;
      currentLng = first.longitude;
    }

    while (remaining.isNotEmpty) {
      remaining.sort((a, b) {
        final da = Geolocator.distanceBetween(
          currentLat,
          currentLng,
          a.latitude,
          a.longitude,
        );
        final db = Geolocator.distanceBetween(
          currentLat,
          currentLng,
          b.latitude,
          b.longitude,
        );
        return da.compareTo(db);
      });
      final next = remaining.removeAt(0);
      ordered.add(next);
      currentLat = next.latitude;
      currentLng = next.longitude;
    }

    setState(() {
      _stops
        ..clear()
        ..addAll(ordered);
    });
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await _fitRoute();
    _message('Rota yakınlığa göre yeniden sıralandı.');
  }

  Future<void> _openInGoogleMaps() async {
    if (_stops.isEmpty) {
      _message('Önce rotaya en az bir çekim noktası ekle.');
      return;
    }

    final destination = _stops.last;
    final params = <String, String>{
      'api': '1',
      'destination': '${destination.latitude},${destination.longitude}',
      'travelmode': _travelMode.googleValue,
    };

    final current = _currentPosition;
    List<PhotoSpot> waypointSpots;
    if (_useCurrentLocation && current != null) {
      params['origin'] = '${current.latitude},${current.longitude}';
      waypointSpots = _stops.length > 1
          ? _stops.sublist(0, _stops.length - 1)
          : const <PhotoSpot>[];
    } else if (_stops.length > 1) {
      final origin = _stops.first;
      params['origin'] = '${origin.latitude},${origin.longitude}';
      waypointSpots = _stops.length > 2
          ? _stops.sublist(1, _stops.length - 1)
          : const <PhotoSpot>[];
    } else {
      waypointSpots = const <PhotoSpot>[];
    }

    if (waypointSpots.isNotEmpty) {
      params['waypoints'] =
          waypointSpots.map((s) => '${s.latitude},${s.longitude}').join('|');
    }

    final uri = Uri.https('www.google.com', '/maps/dir/', params);
    var launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) launched = await launchUrl(uri);
    if (!launched) _message('Google Maps açılamadı.');
  }

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) {
    final distance = _distanceKm;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: Colors.white,
        title: const Text('Rota Oluştur'),
        actions: [
          IconButton(
            tooltip: 'Rotayı haritaya sığdır',
            onPressed: _fitRoute,
            icon: const Icon(Icons.fit_screen_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 255,
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(38.9637, 35.2433),
                zoom: 5,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: _currentPosition != null,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              onMapCreated: (controller) async {
                _mapController = controller;
                await Future<void>.delayed(const Duration(milliseconds: 120));
                await _fitRoute();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryItem(
                          value: '${_stops.length}',
                          label: 'çekim noktası',
                        ),
                      ),
                      Container(width: 1, height: 34, color: _border),
                      Expanded(
                        child: _SummaryItem(
                          value: distance < 10
                              ? '${distance.toStringAsFixed(1)} km'
                              : '${distance.toStringAsFixed(0)} km',
                          label: 'kuş uçuşu',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<RouteTravelMode>(
                    showSelectedIcon: false,
                    segments: RouteTravelMode.values
                        .map(
                          (mode) => ButtonSegment(
                            value: mode,
                            icon: Icon(mode.icon, size: 18),
                            label: Text(mode.label),
                          ),
                        )
                        .toList(),
                    selected: {_travelMode},
                    onSelectionChanged: (value) =>
                        setState(() => _travelMode = value.first),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _useCurrentLocation && _currentPosition != null
                              ? 'Başlangıç: Konumum'
                              : 'Başlangıç: İlk çekim noktası',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _gettingLocation
                            ? null
                            : () async {
                                if (_useCurrentLocation &&
                                    _currentPosition != null) {
                                  setState(() => _useCurrentLocation = false);
                                  await _fitRoute();
                                } else {
                                  await _readCurrentLocation(
                                      requestIfNeeded: true);
                                  await _fitRoute();
                                }
                              },
                        icon: _gettingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location_rounded, size: 18),
                        label: Text(
                          _useCurrentLocation && _currentPosition != null
                              ? 'Kapat'
                              : 'Konumum',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Duraklar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickSpot,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nokta ekle'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _stops.isEmpty
                    ? _EmptyRoute(onAdd: _pickSpot)
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        itemCount: _stops.length,
                        onReorder: (oldIndex, newIndex) async {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final spot = _stops.removeAt(oldIndex);
                            _stops.insert(newIndex, spot);
                          });
                          await Future<void>.delayed(
                              const Duration(milliseconds: 60));
                          await _fitRoute();
                        },
                        itemBuilder: (context, index) {
                          final spot = _stops[index];
                          return Container(
                            key: ValueKey(spot.id),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: _border),
                            ),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.fromLTRB(10, 4, 4, 4),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: _surfaceAlt,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              title: Text(
                                spot.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Builder(
                                builder: (_) {
                                  final km = _distanceToMeKm(spot);
                                  final distanceLabel = km == null
                                      ? ''
                                      : ' • ${km < 10 ? km.toStringAsFixed(1) : km.toStringAsFixed(0)} km';
                                  return Text(
                                    '${spot.city}$distanceLabel • ${spot.bestTime}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(color: Colors.white54),
                                  );
                                },
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Kaldır',
                                    onPressed: () async {
                                      setState(() => _stops.removeAt(index));
                                      await Future<void>.delayed(
                                          const Duration(milliseconds: 60));
                                      await _fitRoute();
                                    },
                                    icon: const Icon(Icons.close_rounded,
                                        color: Colors.white54),
                                  ),
                                  const Icon(Icons.drag_handle_rounded,
                                      color: Colors.white38),
                                  const SizedBox(width: 6),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _stops.length < 3 ? null : _optimizeOrder,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Akıllı sırala'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: _stops.isEmpty ? null : _openInGoogleMaps,
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Google Maps'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String value;
  final String label;

  const _SummaryItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      );
}

class _EmptyRoute extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyRoute({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.route_outlined, size: 56, color: Colors.white24),
              const SizedBox(height: 12),
              const Text(
                'Rotan henüz boş',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              ),
              const SizedBox(height: 6),
              const Text(
                'Gün içinde çekmek istediğin noktaları ekle, sırala ve tek dokunuşla Google Maps’te aç.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, height: 1.4),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('İlk noktayı ekle'),
              ),
            ],
          ),
        ),
      );
}
