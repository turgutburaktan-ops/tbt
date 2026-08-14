import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/photo_spot.dart';
import '../models/social_event.dart';
import '../services/social_event_service.dart';
import '../services/spot_repository.dart';
import '../widgets/spot_image.dart';
import 'social_events_screen.dart';
import 'spot_detail_screen.dart';

enum _MapContentFilter { all, spots, events }

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  PhotoSpot? _selectedSpot;
  SocialEvent? _selectedEvent;
  List<PhotoSpot> _spots = List<PhotoSpot>.from(demoSpots);
  List<SocialEvent> _events = const [];
  bool _loadingSpots = true;
  bool _locationPermissionGranted = false;
  bool _gettingLocation = false;
  Position? _currentPosition;
  _MapContentFilter _filter = _MapContentFilter.all;

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
    if (_filter != _MapContentFilter.events) {
      for (final spot in _spots) {
        markers.add(Marker(
          markerId: MarkerId('spot_${spot.id}'),
          position: LatLng(spot.latitude, spot.longitude),
          infoWindow: InfoWindow(title: spot.name, snippet: '${spot.city} • ⭐ ${spot.rating}'),
          onTap: () {
            setState(() {
              _selectedSpot = spot;
              _selectedEvent = null;
            });
            _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(spot.latitude, spot.longitude), 15));
          },
        ));
      }
    }

    if (_filter != _MapContentFilter.spots) {
      final now = DateTime.now();
      for (final event in _events.where((e) => e.status == 'open' && e.startsAt.isAfter(now))) {
        final position = _eventPosition(event);
        if (position == null) continue;
        markers.add(Marker(
          markerId: MarkerId('event_${event.id}'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          infoWindow: InfoWindow(
            title: '🎟️ ${event.title}',
            snippet: '${event.typeLabel} • ${_eventDate(event.startsAt)}',
          ),
          onTap: () {
            setState(() {
              _selectedEvent = event;
              _selectedSpot = null;
            });
            _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
          },
        ));
      }
    }
    return markers;
  }

  String _eventDate(DateTime date) {
    final d = date.toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _prepareLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
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
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (showErrors && mounted) _message('Konum izni gerekli.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (!mounted) return;
      setState(() {
        _locationPermissionGranted = true;
        _currentPosition = position;
        _selectedSpot = null;
        _selectedEvent = null;
      });
      await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 15));
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

  void _showAll() {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_defaultLocation, 5));
    setState(() {
      _selectedSpot = null;
      _selectedEvent = null;
    });
  }

  void _openSpot(PhotoSpot spot) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)));
  }

  void _openEvents() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: SafeArea(child: SocialEventsScreen()))));
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedSpot != null || _selectedEvent != null;
    final bottomOffset = hasSelection ? 184.0 : 24.0;

    return StreamBuilder<List<SocialEvent>>(
      stream: SocialEventService.instance.watchUpcoming(limit: 120),
      builder: (context, eventSnapshot) {
        _events = eventSnapshot.data ?? _events;
        return SafeArea(
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(target: _defaultLocation, zoom: 5),
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
                    await controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 15));
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
                      decoration: BoxDecoration(color: const Color(0xFF11151C).withOpacity(.95), borderRadius: BorderRadius.circular(18)),
                      child: Row(children: [
                        const Icon(Icons.explore_outlined, color: Color(0xFFFFC107)),
                        const SizedBox(width: 9),
                        const Expanded(child: Text('Noktalar ve Etkinlikler', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                        if (_loadingSpots)
                          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFC107)))
                        else
                          Text('${_spots.length} + ${_events.where((e) => _eventPosition(e) != null && e.startsAt.isAfter(DateTime.now())).length}', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w700)),
                        IconButton(onPressed: () { setState(() => _loadingSpots = true); _loadSpots(); }, icon: const Icon(Icons.refresh, color: Colors.white70)),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: const Color(0xFF11151C).withOpacity(.95), borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        _FilterButton(label: 'Tümü', selected: _filter == _MapContentFilter.all, onTap: () => setState(() => _filter = _MapContentFilter.all)),
                        _FilterButton(label: 'Çekim Noktaları', selected: _filter == _MapContentFilter.spots, onTap: () => setState(() { _filter = _MapContentFilter.spots; _selectedEvent = null; })),
                        _FilterButton(label: 'Etkinlikler', selected: _filter == _MapContentFilter.events, onTap: () => setState(() { _filter = _MapContentFilter.events; _selectedSpot = null; })),
                      ]),
                    ),
                  ],
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
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFFFC107)))
                      : const Icon(Icons.my_location_rounded),
                ),
              ),
              Positioned(
                right: 16,
                bottom: bottomOffset,
                child: FloatingActionButton(
                  heroTag: 'allMapContent',
                  backgroundColor: const Color(0xFF11151C),
                  foregroundColor: const Color(0xFFFFC107),
                  onPressed: _showAll,
                  child: const Icon(Icons.fit_screen),
                ),
              ),
              if (_selectedSpot != null)
                Positioned(left: 16, right: 16, bottom: 16, child: _SpotCard(spot: _selectedSpot!, onClose: () => setState(() => _selectedSpot = null), onOpen: () => _openSpot(_selectedSpot!))),
              if (_selectedEvent != null)
                Positioned(left: 16, right: 16, bottom: 16, child: _EventCard(event: _selectedEvent!, dateLabel: _eventDate(_selectedEvent!.startsAt), onClose: () => setState(() => _selectedEvent = null), onOpen: _openEvents)),
            ],
          ),
        );
      },
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterButton({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
            decoration: BoxDecoration(color: selected ? const Color(0xFFFFC107) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
            child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? Colors.black : Colors.white70)),
          ),
        ),
      );
}

class _EventCard extends StatelessWidget {
  final SocialEvent event;
  final String dateLabel;
  final VoidCallback onClose;
  final VoidCallback onOpen;
  const _EventCard({required this.event, required this.dateLabel, required this.onClose, required this.onOpen});
  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF161226),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const CircleAvatar(radius: 30, backgroundColor: Color(0x334B2A8A), child: Icon(Icons.confirmation_number_outlined, color: Color(0xFFB794F6), size: 28)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('${event.typeLabel} • $dateLabel', style: const TextStyle(color: Color(0xFFB794F6), fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 5),
                Text(event.locationLabel.isNotEmpty ? event.locationLabel : event.city, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60)),
                const SizedBox(height: 5),
                Text('${event.participantCount}/${event.capacity} katılımcı • ${event.isPaid ? '${event.ticketPrice.toStringAsFixed(0)} ${event.currency}' : 'Ücretsiz'}', style: const TextStyle(fontSize: 12)),
              ])),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close, color: Colors.white54)),
              const Icon(Icons.chevron_right, color: Color(0xFFB794F6)),
            ]),
          ),
        ),
      );
}

class _SpotCard extends StatelessWidget {
  final PhotoSpot spot;
  final VoidCallback onClose;
  final VoidCallback onOpen;
  const _SpotCard({required this.spot, required this.onClose, required this.onOpen});
  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF11151C),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              SpotImage(spot: spot, width: 88, height: 88, borderRadius: BorderRadius.circular(12)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(spot.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(spot.city, style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 6),
                Text('⭐ ${spot.rating} • ${spot.category}'),
                const SizedBox(height: 6),
                Text(spot.bestTime, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFFFC107), fontSize: 12)),
              ])),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close, color: Colors.white54)),
              const Icon(Icons.chevron_right, color: Color(0xFFFFC107)),
            ]),
          ),
        ),
      );
}
