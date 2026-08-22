import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/route_place.dart';
import '../services/route_selection_service.dart';

class SelectedRouteMapScreen extends StatefulWidget {
  final List<RoutePlace> places;

  const SelectedRouteMapScreen({
    super.key,
    required this.places,
  });

  @override
  State<SelectedRouteMapScreen> createState() => _SelectedRouteMapScreenState();
}

class _SelectedRouteMapScreenState extends State<SelectedRouteMapScreen> {
  final MapController _mapController = MapController();
  Position? _position;
  bool _gettingLocation = false;

  @override
  void initState() {
    super.initState();
    _readLocation();
  }

  Future<void> _readLocation() async {
    if (_gettingLocation) return;
    setState(() => _gettingLocation = true);
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
      );
      if (!mounted) return;
      setState(() => _position = position);
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll());
    } catch (_) {
      // The selected route still works without current location.
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  List<LatLng> get _routePoints {
    final points = <LatLng>[];
    final position = _position;
    if (position != null) {
      points.add(LatLng(position.latitude, position.longitude));
    }
    points.addAll(
      widget.places.map((place) => LatLng(place.latitude, place.longitude)),
    );
    return points;
  }

  LatLng _centerOf(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(39.0, 35.0);
    final lat = points.map((p) => p.latitude).reduce((a, b) => a + b) /
        points.length;
    final lng = points.map((p) => p.longitude).reduce((a, b) => a + b) /
        points.length;
    return LatLng(lat, lng);
  }

  double _zoomFor(List<LatLng> points) {
    if (points.length <= 1) return 14;
    final minLat = points.map((p) => p.latitude).reduce(math.min);
    final maxLat = points.map((p) => p.latitude).reduce(math.max);
    final minLng = points.map((p) => p.longitude).reduce(math.min);
    final maxLng = points.map((p) => p.longitude).reduce(math.max);
    final span = math.max(maxLat - minLat, maxLng - minLng).abs();
    if (span < .01) return 14;
    if (span < .03) return 12.8;
    if (span < .08) return 11.5;
    if (span < .2) return 10;
    if (span < .5) return 8.7;
    if (span < 1.2) return 7.5;
    return 6.2;
  }

  void _fitAll() {
    final points = _routePoints;
    if (points.isEmpty) return;
    _mapController.move(_centerOf(points), _zoomFor(points));
  }

  List<Marker> get _markers {
    final markers = <Marker>[];
    for (var i = 0; i < widget.places.length; i++) {
      final place = widget.places[i];
      markers.add(
        Marker(
          point: LatLng(place.latitude, place.longitude),
          width: 48,
          height: 48,
          child: Tooltip(
            message: '${i + 1}. ${place.name} • ${place.category}',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == widget.places.length - 1
                    ? const Color(0xFF42F5E9)
                    : const Color(0xFF8B5CF6),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 8),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      );
    }
    final position = _position;
    if (position != null) {
      markers.add(
        Marker(
          point: LatLng(position.latitude, position.longitude),
          width: 34,
          height: 34,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2196F3),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 6),
              ],
            ),
            child: const Icon(Icons.my_location_rounded,
                size: 17, color: Colors.white),
          ),
        ),
      );
    }
    return markers;
  }

  Future<void> _openGoogleMaps() async {
    final opened = await RouteSelectionService.instance.openSelectedRoute();
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Google Maps açılamadı.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = _routePoints;
    final initialCenter = _centerOf(points);
    final initialZoom = _zoomFor(points);

    return Scaffold(
      appBar: AppBar(
        title: Text('Rotam (${widget.places.length})'),
        actions: [
          IconButton(
            tooltip: 'Rotayı ekrana sığdır',
            onPressed: _fitAll,
            icon: const Icon(Icons.fit_screen_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: initialZoom,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.tbt',
                  maxZoom: 19,
                ),
                if (points.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        strokeWidth: 5,
                        color: const Color(0xFF42F5E9),
                      ),
                    ],
                  ),
                MarkerLayer(markers: _markers),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _position == null
                          ? 'Seçilen ${widget.places.length} mekan uygulama içindeki haritada gösteriliyor.'
                          : 'Konumun ve seçilen ${widget.places.length} mekan aynı rota üzerinde gösteriliyor.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _openGoogleMaps,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Google Maps'),
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
