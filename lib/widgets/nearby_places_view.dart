import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/nearby_venue.dart';
import '../services/location_service.dart';
import '../services/nearby_venue_service.dart';

class NearbyPlacesView extends StatefulWidget {
  final NearbyVenueCategory category;

  const NearbyPlacesView({
    super.key,
    required this.category,
  });

  @override
  State<NearbyPlacesView> createState() => _NearbyPlacesViewState();
}

class _NearbyPlacesViewState extends State<NearbyPlacesView> {
  static const _cyan = Color(0xFF42F5E9);
  static const _violet = Color(0xFF8B5CF6);
  static const _panel = Color(0xFF101218);
  static const _border = Color(0xFF292D38);

  final _searchController = TextEditingController();
  Position? _position;
  List<NearbyVenue> _venues = const [];
  final Set<String> _selectedIds = <String>{};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
      if (position == null) {
        throw const _LocationUnavailable();
      }
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
    setState(() {
      if (!_selectedIds.add(venue.id)) _selectedIds.remove(venue.id);
    });
  }

  Future<void> _openSelectedRoute() async {
    var selected = _venues
        .where((venue) => _selectedIds.contains(venue.id))
        .toList();
    if (selected.isEmpty) return;
    if (selected.length > 10) {
      selected = selected.take(10).toList();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Maps sınırı nedeniyle en yakın 10 mekan açıldı.'),
        ),
      );
    }
    final destination = selected.last;
    final params = <String, String>{
      'api': '1',
      'destination': '${destination.latitude},${destination.longitude}',
      'travelmode': 'driving',
    };
    final position = _position;
    if (position != null) {
      params['origin'] = '${position.latitude},${position.longitude}';
    }
    if (selected.length > 1) {
      params['waypoints'] = selected
          .take(selected.length - 1)
          .map((venue) => '${venue.latitude},${venue.longitude}')
          .join('|');
    }
    final uri = Uri.https('www.google.com', '/maps/dir/', params);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Maps açılamadı.')),
      );
    }
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
      return const Center(child: CircularProgressIndicator(color: _cyan));
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
      color: _cyan,
      onRefresh: () => _load(forceRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 22),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '${widget.category.label} içinde ara',
                    prefixIcon: const Icon(Icons.search_rounded, size: 21),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded, size: 19),
                          ),
                    filled: true,
                    fillColor: _panel,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Haritada göster',
                onPressed: _venues.isEmpty ? null : _openMap,
                icon: const Icon(Icons.map_outlined),
              ),
            ],
          ),
          if (_selectedIds.isNotEmpty) ...[
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openSelectedRoute,
                icon: const Icon(Icons.route_rounded),
                label: Text('Rotaya Git (${_selectedIds.length})'),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(3, 12, 3, 8),
            child: Text(
              '${venues.length} mekan • yakından uzağa',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          if (venues.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 56),
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
                selected: _selectedIds.contains(venue.id),
                onSelected: () => _toggleSelection(venue),
              ),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse('https://www.openstreetmap.org/copyright'),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text(
              'Mekan verisi © OpenStreetMap katkıda bulunanlar',
              style: TextStyle(color: Colors.white38, fontSize: 11),
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
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF101218),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF292D38)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF42F5E9).withValues(alpha: .22),
                    const Color(0xFF8B5CF6).withValues(alpha: .22),
                  ],
                ),
              ),
              child: Icon(_icon, color: const Color(0xFF42F5E9)),
            ),
                const SizedBox(width: 12),
                Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    venue.address.isEmpty ? 'Adres bilgisi yok' : venue.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                  ),
                  if (venue.openingHours.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      venue.openingHours,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                    ),
                  ],
                ],
              ),
            ),
                const SizedBox(width: 6),
                Column(
              children: [
                Text(
                  distance,
                  style: const TextStyle(
                    color: Color(0xFF42F5E9),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  tooltip: 'Yol tarifi',
                  onPressed: onDirections,
                  icon: const Icon(Icons.directions_rounded, size: 22),
                ),
              ],
                ),
              ],
            ),
            const Divider(height: 12, color: Colors.white10),
            InkWell(
              onTap: onSelected,
              borderRadius: BorderRadius.circular(10),
              child: Row(
                children: [
                  Checkbox(
                    value: selected,
                    onChanged: (_) => onSelected(),
                    activeColor: const Color(0xFF42F5E9),
                    checkColor: Colors.black,
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(
                    selected ? 'Rotaya eklendi' : 'Rotaya ekle',
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF42F5E9)
                          : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
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
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: Colors.white38),
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
