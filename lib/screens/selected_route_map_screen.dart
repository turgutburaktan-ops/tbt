import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/route_place.dart';
import '../services/route_selection_service.dart';
import '../theme/app_theme.dart';

class SelectedRouteMapScreen extends StatefulWidget {
  final List<RoutePlace> places;

  const SelectedRouteMapScreen({super.key, required this.places});

  @override
  State<SelectedRouteMapScreen> createState() => _SelectedRouteMapScreenState();
}

class _SelectedRouteMapScreenState extends State<SelectedRouteMapScreen> {
  GoogleMapController? _mapController;
  Position? _position;
  bool _gettingLocation = false;

  static const _defaultCenter = LatLng(39.0, 35.0);

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
          permission == LocationPermission.deniedForever)
        return;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      setState(() => _position = position);
      await _fitAll();
    } catch (_) {
      // Route preview still works without current location.
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
    points.addAll(widget.places.map((p) => LatLng(p.latitude, p.longitude)));
    return points;
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};
    for (var i = 0; i < widget.places.length; i++) {
      final place = widget.places[i];
      markers.add(
        Marker(
          markerId: MarkerId('route_${place.id}_$i'),
          position: LatLng(place.latitude, place.longitude),
          infoWindow: InfoWindow(
            title: '${i + 1}. ${place.name}',
            snippet: place.category,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            i == widget.places.length - 1
                ? BitmapDescriptor.hueAzure
                : BitmapDescriptor.hueViolet,
          ),
        ),
      );
    }
    final position = _position;
    if (position != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('my_location_route'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: const InfoWindow(title: 'Konumum'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> get _polylines {
    final points = _routePoints;
    if (points.length < 2) return const <Polyline>{};
    return {
      Polyline(
        polylineId: const PolylineId('selected_route_preview'),
        points: points,
        width: 5,
        color: AppColors.cyan,
        geodesic: true,
      ),
    };
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    if ((maxLat - minLat).abs() < .0005) {
      minLat -= .002;
      maxLat += .002;
    }
    if ((maxLng - minLng).abs() < .0005) {
      minLng -= .002;
      maxLng += .002;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<void> _fitAll() async {
    final controller = _mapController;
    final points = _routePoints;
    if (controller == null || points.isEmpty) return;
    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 14),
      );
      return;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(_boundsFor(points), 54),
    );
  }

  Future<void> _openGoogleMaps() async {
    final opened = await RouteSelectionService.instance.openSelectedRoute();
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Google Maps açılamadı.')));
  }

  @override
  Widget build(BuildContext context) {
    final points = _routePoints;
    final initial = points.isEmpty ? _defaultCenter : points.first;
    return Scaffold(
      backgroundColor: AppColors.background,
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
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: initial, zoom: 11),
              onMapCreated: (controller) async {
                _mapController = controller;
                await _fitAll();
              },
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: _position != null,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              compassEnabled: true,
              mapToolbarEnabled: false,
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
                          ? 'Seçilen ${widget.places.length} nokta Google Maps üzerinde gösteriliyor.'
                          : 'Konumun ve seçilen ${widget.places.length} nokta Google Maps üzerinde gösteriliyor.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _openGoogleMaps,
                    icon: const Icon(Icons.directions_rounded),
                    label: const Text('Rotaya Git'),
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
