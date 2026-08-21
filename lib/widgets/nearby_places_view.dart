import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/nearby_venue.dart';
import '../models/route_place.dart';
import '../services/location_service.dart';
import '../services/nearby_venue_service.dart';
import '../services/route_selection_service.dart';
import '../theme/app_theme.dart';
import 'route_selection_button.dart';

class NearbyPlacesView extends StatefulWidget {
  final NearbyVenueCategory category;

  const NearbyPlacesView({super.key, required this.category});

  @override
  State<NearbyPlacesView> createState() => _NearbyPlacesViewState();
}

class _NearbyPlacesViewState extends State<NearbyPlacesView> {
  final _searchController = TextEditingController();
  Position? _position;
  List<NearbyVenue> _venues = const [];
  final Set<String> _selectedIds = <String>{};
  bool _loading = true;
  String? _error;

  String _routeId(NearbyVenue venue) =>
      'venue:${venue.category.name}:${venue.id}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant NearbyPlacesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) {
      _searchController.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final position = await LocationService.getCurrentPosition();
      if (position == null) throw const _LocationUnavailable();
      final venues = await NearbyVenueService.instance.nearby(
        category: widget.category,
        latitude: position.latitude,
        longitude: position.longitude,
        forceRefresh: forceRefresh,
      );
      venues.sort(
        (a, b) => _distance(position, a).compareTo(_distance(position, b)),
      );
      if (!mounted) return;
      setState(() {
        _position = position;
        _venues = venues;
        _selectedIds
          ..clear()
          ..addAll(
            venues
                .where((venue) =>
                    RouteSelectionService.instance.contains(_routeId(venue)))
                .map(_routeId),
          );
        _loading = false;
      });
    } on _LocationUnavailable {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Yakındaki mekanlar için konumu ve konum iznini aç.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Mekanlar şu anda yüklenemedi. Bağlantını kontrol edip tekrar dene.';
      });
    }
  }

  double _distance(Position position, NearbyVenue venue) =>
      Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        venue.latitude,
        venue.longitude,
      );

  String _distanceLabel(NearbyVenue venue) {
    final position = _position;
    if (position == null) return '';
    final meters = _distance(position, venue);
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }

  List<NearbyVenue> get _visibleVenues {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _venues;
    return _venues.where((venue) {
      return '${venue.name} ${venue.address}'.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openDirections(NearbyVenue venue) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${venue.latitude},${venue.longitude}',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harita uygulaması açılamadı.')),
      );
    }
  }

  void _toggleSelection(NearbyVenue venue) {
    final id = _routeId(venue);
    RouteSelectionService.instance.toggle(
      RoutePlace(
        id: id,
        name: venue.name,
        category: venue.category.label,
        latitude: venue.latitude,
        longitude: venue.longitude,
      ),
    );
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  void _openMap() {
    final position = _position;
    if (position == null || _venues.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _NearbyVenueMapScreen(
          category: widget.category,
          position: position,
          venues: _venues,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _MessageState(
        icon: Icons.location_off_outlined,
        message: _error!,
        actionLabel: 'Tekrar Dene',
        onAction: _load,
      );
    }

    final venues = _visibleVenues;
    return RefreshIndicator(
      color: AppColors.cyan,
      onRefresh: () => _load(forceRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '${widget.category.label} içinde ara',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              IconButton(
                tooltip: 'Haritada göster',
                onPressed: _venues.isEmpty ? null : _openMap,
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  backgroundColor: AppColors.surfaceAlt,
                  side: const BorderSide(color: AppColors.border),
                ),
                icon: const Icon(Icons.map_outlined, size: 20),
              ),
            ],
          ),
          const RouteSelectionButton(
            padding: EdgeInsets.fromLTRB(0, 8, 0, 0),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 10, 2, 7),
            child: Text(
              '${venues.length} mekan  •  yakından uzağa',
              style: const TextStyle(color: const Color(0x75FFFFFF), fontSize: 11.5),
            ),
          ),
          if (venues.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: _MessageState(
                icon: Icons.place_outlined,
                message: 'Bu bölgede eşleşen mekan bulunamadı.',
              ),
            )
          else
            ...venues.map(
              (venue) => _VenueCard(
                venue: venue,
                distance: _distanceLabel(venue),
                onDirections: () => _openDirections(venue),
                selected: _selectedIds.contains(_routeId(venue)),
                onSelected: () => _toggleSelection(venue),
              ),
            ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse('https://www.openstreetmap.org/copyright'),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text(
              'Mekan verisi © OpenStreetMap katkıda bulunanlar',
              style: TextStyle(color: const Color(0x52FFFFFF), fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _VenueCard extends StatelessWidget {
  final NearbyVenue venue;
  final String distance;
  final VoidCallback onDirections;
  final bool selected;
  final VoidCallback onSelected;

  const _VenueCard({
    required this.venue,
    required this.distance,
    required this.onDirections,
    required this.selected,
    required this.onSelected,
  });

  IconData get _icon => switch (venue.category) {
        NearbyVenueCategory.dining => Icons.restaurant_rounded,
        NearbyVenueCategory.cafe => Icons.local_cafe_rounded,
        NearbyVenueCategory.hotel => Icons.hotel_rounded,
      };

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? AppColors.cyan.withValues(alpha: .40) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceStrong,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, size: 21, color: AppColors.cyan),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          venue.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        distance,
                        style: const TextStyle(
                          color: AppColors.cyan,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    venue.address.isEmpty
                        ? venue.category.label
                        : '${venue.category.label}  •  ${venue.address}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: const Color(0x75FFFFFF),
                      fontSize: 11,
                    ),
                  ),
                  if (venue.openingHours.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      venue.openingHours,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: const Color(0x52FFFFFF),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: selected ? 'Rotadan çıkar' : 'Rotaya ekle',
                  onPressed: onSelected,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(38, 38),
                    backgroundColor: selected
                        ? AppColors.cyan
                        : AppColors.surfaceStrong,
                    foregroundColor: selected
                        ? const Color(0xFF041311)
                        : Colors.white70,
                  ),
                  icon: Icon(
                    selected ? Icons.check_rounded : Icons.add_rounded,
                    size: 20,
                  ),
                ),
                IconButton(
                  tooltip: 'Yol tarifi',
                  onPressed: onDirections,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(38, 38),
                    foregroundColor: const Color(0x75FFFFFF),
                  ),
                  icon: const Icon(Icons.directions_rounded, size: 19),
                ),
              ],
            ),
          ],
        ),
      );
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(icon, size: 26, color: Colors.white38),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, height: 1.4),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 14),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      );
}

class _NearbyVenueMapScreen extends StatelessWidget {
  final NearbyVenueCategory category;
  final Position position;
  final List<NearbyVenue> venues;

  const _NearbyVenueMapScreen({
    required this.category,
    required this.position,
    required this.venues,
  });

  @override
  Widget build(BuildContext context) {
    final markers = venues
        .map(
          (venue) => Marker(
            markerId: MarkerId('venue-${venue.id}'),
            position: LatLng(venue.latitude, venue.longitude),
            infoWindow: InfoWindow(
              title: venue.name,
              snippet: venue.address.isEmpty ? category.label : venue.address,
            ),
          ),
        )
        .toSet();
    return Scaffold(
      appBar: AppBar(title: Text('${category.label} Haritası')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 13,
        ),
        markers: markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        mapToolbarEnabled: true,
      ),
    );
  }
}

class _LocationUnavailable implements Exception {
  const _LocationUnavailable();
}
