import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  GoogleMapController? _mapController;
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
      await _fitAll();
    } catch (_) {
      // The selected route still works without current location.
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};
    for (var i = 0; i < widget.places.length; i++) {
      final place = widget.places[i];
      markers.add(
        Marker(
          markerId: MarkerId('selected_route_${place.id}'),
          position: LatLng(place.latitude, place.longitude),
          infoWindow: InfoWindow(
            title: '${i + 1}. ${place.name}',
            snippet: place.category,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            i == widget.places.length - 1
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueViolet,
          ),
        ),
      );
    }
    final position = _position;
    if (position != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('selected_route_origin'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: const InfoWindow(title: 'Konumum'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> get _polylines {
    final points = <LatLng>[];
    final position = _position;
    if (position != null) {
      points.add(LatLng(position.latitude, position.longitude));
    }
    points.addAll(
      widget.places.map((place) => LatLng(place.latitude, place.longitude)),
    );
    if (points.length < 2) return const <Polyline>{};
    return {
      Polyline(
        polylineId: const PolylineId('selected_route_line'),
        points: points,
        width: 5,
        color: const Color(0xFF42F5E9),
      ),
    };
  }

  Future<void> _fitAll() async {
    final controller = _mapController;
    if (controller == null || widget.places.isEmpty) return;

    final lats = <double>[
      ...widget.places.map((place) => place.latitude),
      if (_position != null) _position!.latitude,
    ];
    final lngs = <double>[
      ...widget.places.map((place) => place.longitude),
      if (_position != null) _position!.longitude,
    ];

    if (lats.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lats.first, lngs.first), 14),
      );
      return;
    }

    final southWest = LatLng(lats.reduce(math.min), lngs.reduce(math.min));
    final northEast = LatLng(lats.reduce(math.max), lngs.reduce(math.max));
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: southWest, northeast: northEast),
        64,
      ),
    );
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
    final first = widget.places.first;
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
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(first.latitude, first.longitude),
                zoom: 12,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: _position != null,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: (controller) async {
                _mapController = controller;
                await Future<void>.delayed(const Duration(milliseconds: 120));
                await _fitAll();
              },
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
                      'Seçilen ${widget.places.length} mekan uygulama içindeki haritada gösteriliyor.',
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
