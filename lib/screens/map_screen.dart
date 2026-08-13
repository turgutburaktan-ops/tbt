import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/photo_spot.dart';
import '../services/spot_repository.dart';
import 'spot_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  PhotoSpot? _selectedSpot;
  List<PhotoSpot> _spots = List<PhotoSpot>.from(demoSpots);
  bool _loadingSpots = true;
  bool _locationPermissionGranted = false;
  bool _gettingLocation = false;
  Position? _currentPosition;

  static const LatLng _defaultLocation = LatLng(38.9637, 35.2433);

  @override
  void initState() {
    super.initState();
    _loadSpots();
    _prepareLocation();
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

  Set<Marker> get _markers => _spots.map((spot) {
        return Marker(
          markerId: MarkerId(spot.id),
          position: LatLng(spot.latitude, spot.longitude),
          infoWindow: InfoWindow(
            title: spot.name,
            snippet: '${spot.city} • ⭐ ${spot.rating}',
          ),
          onTap: () {
            setState(() => _selectedSpot = spot);
            _moveToSpot(spot);
          },
        );
      }).toSet();

  Future<void> _prepareLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    if (!mounted) return;
    setState(() => _locationPermissionGranted = true);
    await _goToMyLocation(showErrors: false);
  }

  Future<void> _goToMyLocation({bool showErrors = true}) async {
    if (_gettingLocation) return;
    if (mounted) setState(() => _gettingLocation = true);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (showErrors && mounted) {
          _message('Konum servisi kapalı.');
        }
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
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;

      setState(() {
        _locationPermissionGranted = true;
        _currentPosition = position;
        _selectedSpot = null;
      });

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15,
          ),
        ),
      );
    } catch (_) {
      if (showErrors && mounted) _message('Konum alınamadı.');
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _moveToSpot(PhotoSpot spot) async {
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(spot.latitude, spot.longitude),
          zoom: 15,
        ),
      ),
    );
  }

  void _showAllSpots() {
    if (_spots.isEmpty) return;
    final first = _spots.first;
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(first.latitude, first.longitude),
          zoom: 5,
        ),
      ),
    );
    setState(() => _selectedSpot = null);
  }

  void _openSpot(PhotoSpot spot) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomOffset = _selectedSpot == null ? 24.0 : 184.0;

    return SafeArea(
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _defaultLocation,
              zoom: 5,
            ),
            markers: _markers,
            myLocationEnabled: _locationPermissionGranted,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            onMapCreated: (controller) async {
              _mapController = controller;
              final position = _currentPosition;
              if (position != null) {
                await controller.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(position.latitude, position.longitude),
                    15,
                  ),
                );
              }
            },
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF11151C).withOpacity(.94),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.map_outlined, color: Color(0xFFFFC107)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Çekim Noktaları',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_loadingSpots)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFFC107),
                      ),
                    )
                  else
                    Text(
                      '${_spots.length}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Yenile',
                    onPressed: () {
                      setState(() => _loadingSpots = true);
                      _loadSpots();
                    },
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: bottomOffset + 68,
            child: FloatingActionButton(
              heroTag: 'myLocation',
              backgroundColor: const Color(0xFF11151C),
              foregroundColor: const Color(0xFFFFC107),
              onPressed: _gettingLocation ? null : _goToMyLocation,
              child: _gettingLocation
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFFFFC107),
                      ),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            right: 16,
            bottom: bottomOffset,
            child: FloatingActionButton(
              heroTag: 'allSpots',
              backgroundColor: const Color(0xFF11151C),
              foregroundColor: const Color(0xFFFFC107),
              onPressed: _showAllSpots,
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
                onClose: () => setState(() => _selectedSpot = null),
                onOpen: () => _openSpot(_selectedSpot!),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpotCard extends StatelessWidget {
  final PhotoSpot spot;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  const _SpotCard({
    required this.spot,
    required this.onClose,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF11151C),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  spot.imageUrl,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 88,
                    height: 88,
                    color: const Color(0xFF222831),
                    child: const Icon(Icons.photo, color: Colors.white38),
                  ),
                ),
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
                    Text(spot.city, style: const TextStyle(color: Colors.white54)),
                    const SizedBox(height: 6),
                    Text('⭐ ${spot.rating} • ${spot.category}'),
                    const SizedBox(height: 6),
                    Text(
                      spot.bestTime,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFFFC107),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Kapat',
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFFFC107)),
            ],
          ),
        ),
      ),
    );
  }
}
