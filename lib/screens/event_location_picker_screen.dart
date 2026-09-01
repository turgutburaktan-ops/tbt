import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/spot_repository.dart';

class EventLocationSelection {
  final double latitude;
  final double longitude;
  final String label;

  const EventLocationSelection({
    required this.latitude,
    required this.longitude,
    required this.label,
  });
}

class EventLocationPickerScreen extends StatefulWidget {
  final String city;
  final String addressLabel;
  final double? initialLatitude;
  final double? initialLongitude;
  final String title;
  final String instruction;

  const EventLocationPickerScreen({
    super.key,
    required this.city,
    required this.addressLabel,
    this.initialLatitude,
    this.initialLongitude,
    this.title = 'Etkinlik Konumunu Seç',
    this.instruction =
        'Haritada tam noktaya dokun. Pini sürükleyerek düzeltebilirsin.',
  });

  @override
  State<EventLocationPickerScreen> createState() =>
      _EventLocationPickerScreenState();
}

class _EventLocationPickerScreenState extends State<EventLocationPickerScreen> {
  static const LatLng _turkeyCenter = LatLng(38.9637, 35.2433);
  GoogleMapController? _controller;
  LatLng? _selected;
  LatLng _initialTarget = _turkeyCenter;
  bool _loadingCity = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selected = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _initialTarget = _selected!;
      _loadingCity = false;
    } else {
      _resolveCityCenter();
    }
  }

  Future<void> _resolveCityCenter() async {
    try {
      final city = widget.city.trim().toLowerCase();
      if (city.isNotEmpty) {
        final spots = await SpotRepository.instance.loadSpots();
        final matches = spots
            .where((spot) => spot.city.trim().toLowerCase() == city)
            .toList();
        if (matches.isNotEmpty) {
          _initialTarget = LatLng(
            matches.first.latitude,
            matches.first.longitude,
          );
        } else if (city == 'elazığ' || city == 'elazig') {
          _initialTarget = const LatLng(38.6743, 39.2232);
        }
      }
    } catch (_) {
      // Türkiye merkeziyle devam et.
    } finally {
      if (mounted) {
        setState(() => _loadingCity = false);
        _controller?.animateCamera(
          CameraUpdate.newLatLngZoom(_initialTarget, 12),
        );
      }
    }
  }

  void _select(LatLng point) {
    setState(() => _selected = point);
  }

  @override
  Widget build(BuildContext context) {
    final cityLabel = widget.city.trim().isEmpty
        ? 'Türkiye'
        : '${widget.city.trim()}, Türkiye';
    final address = widget.addressLabel.trim();
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: _selected == null
                ? null
                : () => Navigator.pop(
                    context,
                    EventLocationSelection(
                      latitude: _selected!.latitude,
                      longitude: _selected!.longitude,
                      label: address.isEmpty ? cityLabel : address,
                    ),
                  ),
            child: const Text('Kaydet'),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialTarget,
              zoom: 6,
            ),
            onMapCreated: (controller) {
              _controller = controller;
              if (!_loadingCity) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(_initialTarget, 12),
                );
              }
            },
            onTap: _select,
            markers: _selected == null
                ? const <Marker>{}
                : {
                    Marker(
                      markerId: const MarkerId('event_location'),
                      position: _selected!,
                      draggable: true,
                      onDragEnd: _select,
                    ),
                  },
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
          ),
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF121416).withOpacity(.96),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF2A2E33)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_city_outlined,
                        color: Color(0xFFD7DADF),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cityLabel,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      address,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    widget.instruction,
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          if (_loadingCity)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
