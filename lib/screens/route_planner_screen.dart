import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/route_itinerary_service.dart';
import '../services/travel_plan_service.dart';
import 'route_sharing_screen.dart';
import 'event_location_picker_screen.dart';
import '../widgets/tbt_dialog.dart';

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
  final List<List<PhotoSpot>> alternatives;
  final String? routeId;
  final String initialTitle;
  final String city;
  final int durationHours;
  final String budget;
  final List<String> interests;
  final bool inviteFriends;
  final PhotoSpot? initialSpot;
  final List<PhotoSpot> initialSpots;
  final bool initialUseCurrentLocation;
  final String initialTransport;

  const RoutePlannerScreen({
    super.key,
    this.routeId,
    this.initialTitle = '',
    this.alternatives = const [],
    this.city = '',
    this.durationHours = 3,
    this.budget = 'Orta',
    this.interests = const [],
    this.inviteFriends = false,
    this.initialSpot,
    this.initialSpots = const <PhotoSpot>[],
    this.initialUseCurrentLocation = true,
    this.initialTransport = 'Araç',
  });

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  static const _background = Color(0xFF090A0C);
  static const _surface = Color(0xFF121416);
  static const _surfaceAlt = Color(0xFF1A1D20);
  static const _border = Color(0xFF2A2E33);
  static const _accent = Color(0xFFB7BCC2);

  RouteItinerary? _road;
  bool _routing = false, _saving = false;
  int _routeGeneration = 0;
  String? _savedId;
  GoogleMapController? _mapController;
  List<PhotoSpot> _allSpots = const [];
  final List<PhotoSpot> _stops = [];
  Position? _currentPosition;
  LatLng? _fixedOrigin;
  bool _loading = true;
  bool _gettingLocation = false;
  bool _useCurrentLocation = true;
  RouteTravelMode _travelMode = RouteTravelMode.driving;
  final TextEditingController _routeNameController = TextEditingController();
  final TextEditingController _routeNoteController = TextEditingController();
  bool _detailsExpanded = false;

  @override
  void dispose() {
    _routeNameController.dispose();
    _routeNoteController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _savedId = widget.routeId;
    _routeNameController.text = widget.initialTitle;
    _useCurrentLocation = widget.initialUseCurrentLocation;
    _travelMode = RouteTravelMode.values.firstWhere(
      (v) => v.label == widget.initialTransport,
      orElse: () => RouteTravelMode.driving,
    );
    final initialIds = <String>{};
    for (final spot in widget.initialSpots) {
      if (spot.id == 'route_origin') {
        _fixedOrigin = LatLng(spot.latitude, spot.longitude);
        continue;
      }
      if (initialIds.add(spot.id)) _stops.add(spot);
    }
    if (widget.initialSpot != null) {
      final spot = widget.initialSpot!;
      if (initialIds.add(spot.id)) _stops.add(spot);
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
      if (widget.initialUseCurrentLocation)
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _fixedOrigin = null;
        _currentPosition = position;
        _useCurrentLocation = true;
        _allSpots = _sortedFromCurrentPosition(_allSpots, position);
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
    sorted.sort(
      (a, b) => _distanceFromPosition(
        position,
        a,
      ).compareTo(_distanceFromPosition(position, b)),
    );
    return sorted;
  }

  double? _distanceToMeKm(PhotoSpot spot) => null;

  List<PhotoSpot> get _nearbyMapSpots {
    final selectedIds = _stops.map((spot) => spot.id).toSet();
    final candidates = _allSpots
        .where((spot) => !selectedIds.contains(spot.id))
        .toList();
    final current = _currentPosition;
    if (current != null) {
      candidates.sort(
        (a, b) => _distanceFromPosition(
          current,
          a,
        ).compareTo(_distanceFromPosition(current, b)),
      );
    }
    return candidates.take(60).toList();
  }

  Future<void> _addSpotFromMap(PhotoSpot spot) async {
    if (_stops.any((item) => item.id == spot.id)) return;
    if (_stops.length >= 12) {
      _message('En fazla 12 durak ekleyebilirsin.');
      return;
    }
    setState(() {
      _stops.add(spot);
    });
    await Future<void>.delayed(const Duration(milliseconds: 70));
    await _fitRoute();
    _message('${spot.name} rotaya eklendi.');
  }

  Future<void> _addCustomStop(LatLng point) async {
    if (_stops.length >= 12) {
      _message('En fazla 12 durak ekleyebilirsin.');
      return;
    }
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    XFile? photo;
    final name = await showTbtDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => TbtDialog(
          title: const Text('Haritadan durak ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Durak adı'),
                ),
                TextField(
                  controller: descriptionController,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama (isteğe bağlı)',
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      final picked = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1600,
                        imageQuality: 85,
                      );
                      if (picked != null && dialogContext.mounted)
                        setDialog(() => photo = picked);
                    } catch (_) {
                      _message('Fotoğraf seçilemedi.');
                    }
                  },
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    photo == null
                        ? 'Fotoğraf ekle (isteğe bağlı)'
                        : 'Fotoğraf seçildi',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.pop(dialogContext, nameController.text.trim());
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
    final description = descriptionController.text.trim();
    descriptionController.dispose();
    nameController.dispose();
    if (name == null || !mounted) return;
    String imageUrl = '';
    if (photo != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _message('Fotoğraf eklemek için giriş yapmalısın.');
        return;
      }
      try {
        final bytes = await photo!.readAsBytes();
        final ref = FirebaseStorage.instance.ref(
          'users/$uid/route_stops/${DateTime.now().microsecondsSinceEpoch}.jpg',
        );
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        imageUrl = await ref.getDownloadURL();
      } catch (_) {
        _message('Fotoğraf yüklenemedi. Durağı yeniden eklemeyi dene.');
        return;
      }
      if (!mounted) return;
    }
    final stop = PhotoSpot(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      city: widget.city.isEmpty ? 'Haritadan seçildi' : widget.city,
      latitude: point.latitude,
      longitude: point.longitude,
      rating: 0,
      bestTime: 'Serbest zaman',
      angle: '',
      imageUrl: imageUrl,
      description: description,
      category: 'Özel durak',
      tags: const ['Özel durak'],
    );
    setState(() => _stops.add(stop));
    await _fitRoute();
    _message('$name rotaya eklendi.');
  }

  Future<void> _editStop(int index) async {
    final stop = _stops[index];
    final controller = TextEditingController(text: stop.name);
    final updatedName = await showTbtDialog<String>(
      context: context,
      builder: (dialogContext) => TbtDialog(
        title: const Text('Durağı düzenle'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Durak adı'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updatedName == null || updatedName.isEmpty || !mounted) return;
    setState(() {
      _stops[index] = PhotoSpot(
        id: stop.id,
        name: updatedName,
        city: stop.city,
        latitude: stop.latitude,
        longitude: stop.longitude,
        rating: stop.rating,
        bestTime: stop.bestTime,
        angle: stop.angle,
        imageUrl: stop.imageUrl,
        category: stop.category,
        description: stop.description,
        recommendedLens: stop.recommendedLens,
        difficulty: stop.difficulty,
        tags: stop.tags,
      );
    });
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Set<Marker> get _markers {
    final markers = <Marker>{
      if (_fixedOrigin != null)
        Marker(
          markerId: const MarkerId('saved_origin'),
          position: _fixedOrigin!,
          infoWindow: const InfoWindow(title: 'Başlangıç'),
        ),
    };
    final current = _currentPosition;
    if (_useCurrentLocation && current != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('route_origin'),
          position: LatLng(current.latitude, current.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
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
    if (!_useCurrentLocation && _fixedOrigin != null) points.add(_fixedOrigin!);
    points.addAll(_stops.map((s) => LatLng(s.latitude, s.longitude)));
    return points;
  }

  Set<Polyline> get _polylines {
    final points = _road?.points ?? <LatLng>[];
    if (points.length < 2) return const <Polyline>{};
    return {
      Polyline(
        polylineId: const PolylineId('photo_route_preview'),
        points: points,
        width: 4,
        color: _accent,
        geodesic: false,
      ),
    };
  }

  Future<void> _refreshRoad() async {
    if (!mounted) return;
    final generation = ++_routeGeneration;
    final points = _routePoints;
    setState(() {
      _road = null;
      _routing = points.length >= 2;
    });
    if (points.length < 2) return;
    final result = await RouteItineraryService.instance.calculate(
      points,
      _travelMode.label,
    );
    if (!mounted || generation != _routeGeneration) return;
    setState(() {
      _road = result;
      _routing = false;
    });
  }

  String _legLabel(int index) {
    final legIndex =
        index -
        ((_useCurrentLocation && _currentPosition != null) ||
                _fixedOrigin != null
            ? 0
            : 1);
    if (legIndex < 0) return 'Başlangıç';
    if (_routing) return 'Yol hesaplanıyor…';
    if (_road == null || legIndex >= _road!.legs.length)
      return 'Uygun güzergâh bulunamadı';
    return _road!.legs[legIndex].label;
  }

  Future<void> _chooseStop() async {
    final choice = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: _surface,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Yer ara'),
              onTap: () => Navigator.pop(c, 0),
            ),
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined),
              title: const Text('Haritadan seç'),
              onTap: () => Navigator.pop(c, 1),
            ),
            ListTile(
              leading: const Icon(Icons.my_location),
              title: const Text('Mevcut konumumu ekle'),
              onTap: () => Navigator.pop(c, 2),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 0) {
      await _pickSpot();
      return;
    }
    if (choice == 1) {
      final p = await Navigator.push<EventLocationSelection>(
        context,
        MaterialPageRoute(
          builder: (_) => EventLocationPickerScreen(
            city: widget.city,
            addressLabel: 'Yeni durak',
            title: 'Durak ekle',
            instruction: 'Eklemek istediğin noktayı haritadan seç.',
          ),
        ),
      );
      if (p != null && mounted)
        await _addCustomStop(LatLng(p.latitude, p.longitude));
    }
    if (choice == 2) {
      await _readCurrentLocation(requestIfNeeded: true);
      if (_currentPosition != null && mounted)
        await _addCustomStop(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        );
    }
  }

  Future<void> _saveRoute() async {
    if (_saving || _stops.isEmpty) return;
    if (_routeNameController.text.trim().isEmpty) {
      _message('Rotana bir ad ver.');
      return;
    }
    setState(() => _saving = true);
    try {
      final details = _stops
          .map(
            (s) => <String, dynamic>{
              'id': s.id,
              'name': s.name,
              'city': s.city,
              'latitude': s.latitude,
              'longitude': s.longitude,
              'category': s.category,
              'description': s.description,
              'imageUrl': s.imageUrl,
            },
          )
          .toList();
      if (_savedId == null) {
        _savedId = await TravelPlanService.instance.create(
          title: _routeNameController.text.trim(),
          city: widget.city.isEmpty ? _stops.first.city : widget.city,
          durationHours: widget.durationHours,
          budget: widget.budget,
          transport: _travelMode.label,
          interests: widget.interests,
          spots: _stops,
          stopDetails: details,
        );
      } else {
        await TravelPlanService.instance.updateStops(_savedId!, details);
        await TravelPlanService.instance.updateTitle(
          _savedId!,
          _routeNameController.text.trim(),
        );
      }
      await TravelPlanService.instance.updateRoutePreferences(
        _savedId!,
        _travelMode.label,
        _routeNoteController.text.trim(),
        origin: _useCurrentLocation && _currentPosition != null
            ? {
                'latitude': _currentPosition!.latitude,
                'longitude': _currentPosition!.longitude,
              }
            : _fixedOrigin == null
            ? null
            : {
                'latitude': _fixedOrigin!.latitude,
                'longitude': _fixedOrigin!.longitude,
              },
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RouteSharingScreen(
            routeId: _savedId!,
            title: _routeNameController.text.trim(),
            inviteFriends: widget.inviteFriends,
          ),
        ),
      );
      _message('Rota, Rotalarım bölümüne kaydedildi.');
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _fitRoute() async {
    await _refreshRoad();
    if (!mounted) return;
    final controller = _mapController;
    var points = _routePoints;
    if (controller == null) return;
    if (points.isEmpty && _currentPosition != null) {
      final current = _currentPosition!;
      points = [
        LatLng(current.latitude, current.longitude),
        ..._nearbyMapSpots
            .take(12)
            .map((spot) => LatLng(spot.latitude, spot.longitude)),
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
    var category = 'Tümü';
    final selected = await showModalBottomSheet<PhotoSpot>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: _surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final key = _normalize(query);
          final excluded = _stops.map((s) => s.id).toSet();
          final categories = <String>[
            'Tümü',
            ..._allSpots.map((s) => s.category),
          ].toSet().take(16).toList();
          var matches = _allSpots.where((spot) {
            if (excluded.contains(spot.id)) return false;
            if (category != 'Tümü' && spot.category != category) return false;
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
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) => ChoiceChip(
                      label: Text(categories[index]),
                      selected: category == categories[index],
                      onSelected: (_) =>
                          setSheetState(() => category = categories[index]),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
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
    // Keep the controller alive until the bottom-sheet dismissal animation has
    // fully detached its inherited dependencies. Disposing synchronously here
    // could trigger framework `_dependents.isEmpty` assertions on Android.
    Future<void>.delayed(
      const Duration(milliseconds: 500),
      queryController.dispose,
    );
    if (selected == null || !mounted) return;
    if (_stops.length >= 12) {
      _message('En fazla 12 durak ekleyebilirsin.');
      return;
    }
    setState(() => _stops.add(selected));
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
    } else if (_fixedOrigin != null) {
      params['origin'] = '${_fixedOrigin!.latitude},${_fixedOrigin!.longitude}';
      waypointSpots = _stops.sublist(0, _stops.length - 1);
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
      params['waypoints'] = waypointSpots
          .map((s) => '${s.latitude},${s.longitude}')
          .join('|');
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
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: Colors.white,
        title: const Text('Rota Oluştur'),
        actions: [
          IconButton(
            tooltip: 'Rotayı paylaş',
            onPressed: _stops.isEmpty || _saving ? null : _saveRoute,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            tooltip: 'Rotayı haritaya sığdır',
            onPressed: _fitRoute,
            icon: const Icon(Icons.fit_screen_rounded),
          ),
        ],
      ),
      body: ListView(
        children: [
          if (widget.alternatives.isNotEmpty)
            ExpansionTile(
              title: const Text('Alternatif rotalar'),
              children: [
                for (final alternative in widget.alternatives)
                  ListTile(
                    title: Text(alternative.map((s) => s.name).join(' → ')),
                    onTap: () {
                      setState(() {
                        _stops
                          ..clear()
                          ..addAll(alternative);
                      });
                      _fitRoute();
                    },
                  ),
              ],
            ),
          Container(
            height: MediaQuery.sizeOf(context).height < 720 ? 180 : 220,
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(38.6810, 39.2264),
                zoom: 11,
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
              onLongPress: _addCustomStop,
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
                  TextField(
                    controller: _routeNameController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Rota adı',
                      hintText: 'Örn. Harput hafta sonu rotası',
                      prefixIcon: Icon(Icons.edit_road_rounded),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryItem(
                          value: '${_stops.length}',
                          label: 'durak',
                        ),
                      ),
                      Container(width: 1, height: 34, color: _border),
                      Expanded(
                        child: _SummaryItem(
                          value: _routing
                              ? 'Hesaplanıyor…'
                              : _road == null
                              ? '—'
                              : '${(_road!.meters / 1000).toStringAsFixed(1)} km',
                          label: _road == null
                              ? 'Yol mesafesi'
                              : '${(_road!.seconds / 60).ceil()} dk yol',
                        ),
                      ),
                    ],
                  ),
                  if (!_routing && _road == null && _routePoints.length >= 2)
                    TextButton(
                      onPressed: _refreshRoad,
                      child: const Text(
                        'Uygun güzergâh bulunamadı. Yeniden dene',
                      ),
                    ),
                  if (_road != null &&
                      _road!.seconds + _stops.length * 45 * 60 >
                          widget.durationHours * 3600)
                    const Text(
                      'Yol ve duraklarda geçirilecek süre, ayırdığın süreyi aşabilir. Durak sayısını azaltabilirsin.',
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
                    onSelectionChanged: (value) {
                      setState(() => _travelMode = value.first);
                      _refreshRoad();
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _useCurrentLocation && _currentPosition != null
                              ? 'Başlangıç: Konumum'
                              : _fixedOrigin != null
                              ? 'Başlangıç: Kaydedilen konum'
                              : 'Başlangıç: İlk durak',
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
                                    requestIfNeeded: true,
                                  );
                                  await _fitRoute();
                                }
                              },
                        icon: _gettingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () =>
                        setState(() => _detailsExpanded = !_detailsExpanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.tune_rounded, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('Rota notu ve ayrıntılar'),
                          ),
                          Icon(
                            _detailsExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_detailsExpanded) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _routeNoteController,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 300,
                      decoration: const InputDecoration(
                        hintText: 'Saat, buluşma bilgisi veya rota notu ekle',
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'İpucu: Haritada boş bir yere uzun basarak özel durak ekleyebilirsin.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ],
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
                  onPressed: _chooseStop,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Durak ekle'),
                ),
              ],
            ),
          ),
          SizedBox(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _stops.isEmpty
                ? _EmptyRoute(onAdd: _chooseStop)
                : ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    itemCount: _stops.length,
                    onReorder: (oldIndex, newIndex) async {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final spot = _stops.removeAt(oldIndex);
                        _stops.insert(newIndex, spot);
                      });
                      await Future<void>.delayed(
                        const Duration(milliseconds: 60),
                      );
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
                          contentPadding: const EdgeInsets.fromLTRB(
                            10,
                            4,
                            4,
                            4,
                          ),
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
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Builder(
                            builder: (_) {
                              return Text(
                                '${spot.city} • ${_legLabel(index)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white54),
                              );
                            },
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Düzenle',
                                onPressed: () => _editStop(index),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Kaldır',
                                onPressed: () async {
                                  setState(() => _stops.removeAt(index));
                                  await Future<void>.delayed(
                                    const Duration(milliseconds: 60),
                                  );
                                  await _fitRoute();
                                },
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white54,
                                ),
                              ),
                              const Icon(
                                Icons.drag_handle_rounded,
                                color: Colors.white38,
                              ),
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
              child: Column(
                children: [
                  Row(
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
                  FilledButton(
                    onPressed: _stops.isEmpty || _saving ? null : _saveRoute,
                    child: Text(_saving ? 'Kaydediliyor…' : 'Kaydet ve paylaş'),
                  ),
                  TextButton(
                    onPressed: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/fixthemap'),
                    ),
                    child: const Text(
                      'Yol verisi: © OpenStreetMap · FOSSGIS · Haritayı düzelt',
                    ),
                  ),
                  if (_stops.length < 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _stops.isEmpty
                            ? 'Başlamak için ilk durağını ekle.'
                            : 'Akıllı sıralama için en az 3 durak ekle.',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
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
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    ],
  );
}

class _EmptyRoute extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyRoute({required this.onAdd});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Center(
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
              'Listeden nokta seçebilir veya haritada boş bir yere uzun basarak kendi durağını ekleyebilirsin.',
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
    ),
  );
}
