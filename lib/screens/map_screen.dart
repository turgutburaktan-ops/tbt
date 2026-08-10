import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/photo_spot.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;

  PhotoSpot? _selectedSpot;

  bool _locationPermissionGranted = false;
  bool _gettingLocation = false;
  Position? _currentPosition;

  static const LatLng _defaultLocation = LatLng(
    38.9637,
    35.2433,
  );

  @override
  void initState() {
    super.initState();
    _prepareLocation();
  }

  Set<Marker> get _markers {
    return demoSpots.map((spot) {
      return Marker(
        markerId: MarkerId(spot.id.toString()),
        position: LatLng(
          spot.latitude,
          spot.longitude,
        ),
        infoWindow: InfoWindow(
          title: spot.name,
          snippet: '${spot.city} • ⭐ ${spot.rating}',
        ),
        onTap: () {
          setState(() {
            _selectedSpot = spot;
          });

          _moveToSpot(spot);
        },
      );
    }).toSet();
  }

  Future<void> _prepareLocation() async {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (!mounted) return;

      _showLocationMessage(
        'Konum servisi kapalı. Konumunu görmek için GPS\'i aç.',
        actionText: 'Ayarlar',
        onAction: Geolocator.openLocationSettings,
      );
      return;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (!mounted) return;

      _showLocationMessage(
        'Konum izni verilmedi. Haritada konumunu gösteremiyorum.',
      );
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;

      _showLocationMessage(
        'Konum izni kalıcı olarak kapatılmış. Uygulama ayarlarından izin verebilirsin.',
        actionText: 'Ayarlar',
        onAction: Geolocator.openAppSettings,
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _locationPermissionGranted = true;
    });

    await _goToMyLocation(showErrors: false);
  }

  Future<void> _goToMyLocation({
    bool showErrors = true,
  }) async {
    if (_gettingLocation) return;

    if (mounted) {
      setState(() {
        _gettingLocation = true;
      });
    }

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        _showLocationMessage(
          'Konum servisi kapalı. GPS\'i açıp tekrar dene.',
          actionText: 'Ayarlar',
          onAction: Geolocator.openLocationSettings,
        );
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        setState(() {
          _locationPermissionGranted = false;
        });

        if (showErrors) {
          _showLocationMessage(
            'Konum izni verilmedi.',
          );
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          _locationPermissionGranted = false;
        });

        _showLocationMessage(
          'Konum izni kalıcı olarak kapalı.',
          actionText: 'Ayarlar',
          onAction: Geolocator.openAppSettings,
        );
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
            target: LatLng(
              position.latitude,
              position.longitude,
            ),
            zoom: 16,
          ),
        ),
      );
    } catch (error) {
      if (!mounted || !showErrors) return;

      _showLocationMessage(
        'Konum alınamadı. Biraz sonra tekrar dene.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _gettingLocation = false;
        });
      }
    }
  }

  void _showLocationMessage(
    String message, {
    String? actionText,
    Future<bool> Function()? onAction,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionText != null && onAction != null
            ? SnackBarAction(
                label: actionText,
                onPressed: () {
                  onAction();
                },
              )
            : null,
      ),
    );
  }

  Future<void> _moveToSpot(PhotoSpot spot) async {
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            spot.latitude,
            spot.longitude,
          ),
          zoom: 15,
        ),
      ),
    );
  }

  void _showAllSpots() {
    if (demoSpots.isEmpty) return;

    final first = demoSpots.first;

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            first.latitude,
            first.longitude,
          ),
          zoom: 5,
        ),
      ),
    );

    setState(() {
      _selectedSpot = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomOffset =
        _selectedSpot == null ? 24.0 : 180.0;

    return SafeArea(
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _defaultLocation,
              zoom: 5,
            ),
            markers: _markers,
            myLocationEnabled:
                _locationPermissionGranted,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            onMapCreated: (controller) async {
              _mapController = controller;

              if (_currentPosition != null) {
                await controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      zoom: 16,
                    ),
                  ),
                );
              }
            },
          ),

          // ÜST BAŞLIK
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF11151C)
                    .withOpacity(.94),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.map_outlined,
                    color: Color(0xFFFFC107),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Çekim Noktaları',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // BENİM KONUMUM
          Positioned(
            right: 16,
            bottom: bottomOffset + 68,
            child: FloatingActionButton(
              heroTag: 'myLocation',
              backgroundColor:
                  const Color(0xFF11151C),
              foregroundColor:
                  const Color(0xFFFFC107),
              onPressed: _gettingLocation
                  ? null
                  : () {
                      _goToMyLocation();
                    },
              child: _gettingLocation
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFFFFC107),
                      ),
                    )
                  : const Icon(
                      Icons.my_location_rounded,
                    ),
            ),
          ),

          // TÜMÜNÜ GÖSTER
          Positioned(
            right: 16,
            bottom: bottomOffset,
            child: FloatingActionButton(
              heroTag: 'allSpots',
              backgroundColor:
                  const Color(0xFF11151C),
              foregroundColor:
                  const Color(0xFFFFC107),
              onPressed: _showAllSpots,
              child: const Icon(
                Icons.fit_screen,
              ),
            ),
          ),

          // SEÇİLİ NOKTA
          if (_selectedSpot != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _SpotCard(
                spot: _selectedSpot!,
                onClose: () {
                  setState(() {
                    _selectedSpot = null;
                  });
                },
                onOpen: () {
                  // Detay ekranını sonraki aşamada bağlayacağız.
                },
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                spot.imageUrl,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return Container(
                    width: 90,
                    height: 90,
                    color: const Color(0xFF222831),
                    child: const Icon(
                      Icons.photo,
                      color: Colors.white38,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
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
                    style: const TextStyle(
                      color: Colors.white54,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    '⭐ ${spot.rating}  •  📸 ${spot.bestTime}',
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '📐 ${spot.angle}',
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

            Column(
              children: [
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white54,
                  ),
                ),
                IconButton(
                  onPressed: onOpen,
                  icon: const Icon(
                    Icons.chevron_right,
                    color: Color(0xFFFFC107),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
