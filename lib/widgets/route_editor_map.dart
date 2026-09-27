import 'place_marker_card.dart';
import '../services/nearby_venue_service.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/photo_spot.dart';
import '../services/route_itinerary_service.dart';
import '../services/route_map_candidates.dart';
import '../theme/app_theme.dart';

/// A real map: road geometry is drawn only when the routing service returns it.
class RouteEditorMap extends StatefulWidget {
  const RouteEditorMap({
    super.key,
    required this.stops,
    this.itinerary,
    this.interactive = false,
    this.center,
    this.city = '',
    this.padding = EdgeInsets.zero,
    this.candidates = const [],
    this.onPlaceTap,
    this.onMapTap,
  });
  final List<PhotoSpot> stops;
  final RouteItinerary? itinerary;
  final bool interactive;
  final LatLng? center;
  final String city;
  final EdgeInsets padding;
  final List<PhotoSpot> candidates;
  final ValueChanged<PhotoSpot>? onPlaceTap;
  final ValueChanged<LatLng>? onMapTap;
  @override
  State<RouteEditorMap> createState() => _RouteEditorMapState();
}

class _RouteEditorMapState extends State<RouteEditorMap> {
  GoogleMapController? _controller;
  MapType _mapType = MapType.normal;
  LatLng? _cityCenter;
  int _cityRequest = 0;
  LatLng? get _center => _cityCenter ?? widget.center;

  Future<void> _resolveCity({bool focus = false}) async {
    final request = ++_cityRequest;
    final city = widget.city.trim();
    if (city.isEmpty) return;
    final area = await NearbyVenueService.instance.findCity(city);
    if (!mounted || request != _cityRequest || area == null) return;
    setState(() => _cityCenter = LatLng(area.latitude, area.longitude));
    // Resolve the selected city before fitting an empty editor.
    if (focus || _points.isEmpty) await _focusCity();
  }

  Future<void> _focusCity() async {
    if (_center == null || _controller == null) return;
    try {
      await _controller!.moveCamera(CameraUpdate.newLatLngZoom(_center!, 12));
    } catch (_) { /* The platform view may have detached. */ }
  }

  final _icons = <int, BitmapDescriptor>{};
  int _iconGeneration = 0;
  int _cardGeneration = 0;
  final _cardIcons = <String, BitmapDescriptor>{};
  String _cardSignature = '';
  LatLngBounds? _visibleBounds;
  LatLng? _cameraTarget;
  List<PhotoSpot> get _visibleCandidates {
    final center = _cameraTarget ?? _center ?? const LatLng(39, 35);
    return routeMapCandidates(
      widget.candidates,
      latitude: center.latitude,
      longitude: center.longitude,
      south: _visibleBounds?.southwest.latitude,
      north: _visibleBounds?.northeast.latitude,
      west: _visibleBounds?.southwest.longitude,
      east: _visibleBounds?.northeast.longitude,
    );
  }

  Future<void> _refreshVisibleCards() async {
    try {
      final bounds = await _controller?.getVisibleRegion();
      if (!mounted || bounds == null) return;
      setState(() => _visibleBounds = bounds);
      await _makeCards();
    } catch (_) {
      /* The map may detach during a camera update. */
    }
  }

  Future<void> _makeCards() async {
    final candidates = _visibleCandidates;
    final keys = candidates.map(PlaceMarkerCard.cacheKey).toSet();
    final signature = keys.join('\u0001');
    if (signature == _cardSignature) return;
    _cardSignature = signature;
    final generation = ++_cardGeneration;
    _cardIcons.removeWhere((key, _) => !keys.contains(key));
    var rendered = 0;
    for (final spot in candidates) {
      if (!mounted || generation != _cardGeneration) return;
      final key = PlaceMarkerCard.cacheKey(spot);
      if (_cardIcons.containsKey(key)) continue;
      try {
        final icon = await PlaceMarkerCard.render(spot);
        if (!mounted || generation != _cardGeneration) return;
        _cardIcons[key] = icon;
      } catch (_) {
        /* Keep a tappable marker if bitmap rendering fails. */
      }
      if (++rendered % 12 == 0 && mounted) {
        setState(() {});
        await Future<void>.delayed(Duration.zero);
      }
    }
    if (mounted && generation == _cardGeneration) setState(() {});
  }

  String _lastFit = '';
  String get _fitKey =>
      '${widget.center}:${_points.join(';')}:${widget.itinerary?.meters}';
  List<LatLng> get _points =>
      widget.stops.map((s) => LatLng(s.latitude, s.longitude)).toList();

  @override
  void initState() {
    super.initState();
    _makeIcons();
    _makeCards();
    _resolveCity();
  }

  @override
  void didUpdateWidget(RouteEditorMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _makeCards();
    if (widget.stops.length > _icons.length) _makeIcons();
    if (oldWidget.city != widget.city) {
      _cityCenter = null;
      _cameraTarget = null;
      _visibleBounds = null;
      _resolveCity(focus: true);
    }
    if (oldWidget.center != widget.center && _points.isEmpty) _focusCity();
    // Interactive editors preserve the viewport while points are added/removed.
    if (widget.interactive) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _fitKey != _lastFit) _fit();
    });
  }

  Future<void> _makeIcons() async {
    final generation = ++_iconGeneration;
    final icons = <int, BitmapDescriptor>{};
    for (var i = 0; i < widget.stops.length; i++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawCircle(
        const Offset(36, 36),
        32,
        Paint()..color = AppColors.cyan,
      );
      canvas.drawCircle(
        const Offset(36, 36),
        32,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      final text = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(36 - text.width / 2, 36 - text.height / 2));
      final picture = recorder.endRecording();
      final image = await picture.toImage(72, 72);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      if (bytes != null)
        icons[i] = BitmapDescriptor.bytes(
          bytes.buffer.asUint8List(),
          width: 36,
          height: 36,
        );
    }
    if (mounted && generation == _iconGeneration)
      setState(() {
        _icons.addAll(icons);
      });
  }

  Future<void> _fit() async {
    final controller = _controller;
    if (controller == null) return;
    _lastFit = _fitKey;
    if (_points.isEmpty) {
      if (_center != null) {
        try {
          await controller.moveCamera(
            CameraUpdate.newLatLngZoom(_center!, 12),
          );
        } catch (_) {}
      }
      return;
    }
    final points = [..._points, ...?widget.itinerary?.points];
    final lat = points.map((p) => p.latitude).toList()..sort();
    final lng = points.map((p) => p.longitude).toList()..sort();
    try {
      if (lat.last - lat.first < .0001 && lng.last - lng.first < .0001) {
        await controller.moveCamera(
          CameraUpdate.newLatLngZoom(points.first, 15),
        );
      } else {
        await controller.moveCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(lat.first, lng.first),
              northeast: LatLng(lat.last, lng.last),
            ),
            42,
          ),
        );
      }
    } catch (_) {
      /* A map can detach while a camera update is in flight. */
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [GoogleMap(
    initialCameraPosition: CameraPosition(
      target:
          _points.isEmpty
              ? (_center ?? const LatLng(39, 35))
              : _points.first,
      zoom: _points.isEmpty && _center == null ? 5.5 : 13,
    ),
    mapType: _mapType,
    // Explicit light styling keeps the map readable in the app's dark theme.
    style: _mapType == MapType.normal ? '[]' : null,
    padding: widget.padding,
    zoomControlsEnabled: false,
    myLocationButtonEnabled: false,
    mapToolbarEnabled: false,
    scrollGesturesEnabled: widget.interactive,
    zoomGesturesEnabled: widget.interactive,
    rotateGesturesEnabled: widget.interactive,
    tiltGesturesEnabled: false,
    onTap: widget.onMapTap,
    onCameraMove: (position) => _cameraTarget = position.target,
    onCameraIdle: _refreshVisibleCards,
    onMapCreated: (controller) {
      _controller = controller;
      _fit();
    },
    markers: {
      for (final spot in _visibleCandidates.where(
        (s) => !widget.stops.any((p) => p.id == s.id),
      ))
        Marker(
          markerId: MarkerId('candidate:${spot.id}'),
          position: LatLng(spot.latitude, spot.longitude),
          icon:
              _cardIcons[PlaceMarkerCard.cacheKey(spot)] ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          anchor: const Offset(.5, 1),
          onTap: () => widget.onPlaceTap?.call(spot),
        ),
      for (var i = 0; i < widget.stops.length; i++)
        Marker(
          markerId: MarkerId(widget.stops[i].id),
          onTap:
              widget.onPlaceTap == null
                  ? null
                  : () => widget.onPlaceTap!(widget.stops[i]),
          zIndex: 10,
          position: _points[i],
          icon:
              _icons[i] ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: const Offset(.5, .5),
          infoWindow: InfoWindow(title: '${i + 1}. ${widget.stops[i].name}'),
        ),
    },
    polylines: {
      if (widget.itinerary != null)
        Polyline(
          polylineId: const PolylineId('itinerary'),
          points: widget.itinerary!.points,
          color: AppColors.cyan,
          width: 5,
        ),
    },
  ),
    Positioned(
      left: 8, top: 8,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FilledButton.tonalIcon(
          onPressed: () => setState(() => _mapType =
              _mapType == MapType.normal ? MapType.hybrid : MapType.normal),
          icon: const Icon(Icons.layers_outlined, size: 18),
          label: Text(_mapType == MapType.normal ? 'Uydu' : 'Harita'),
        ),
        if (widget.interactive && _points.isNotEmpty)
          FilledButton.tonalIcon(
            onPressed: _fit,
            icon: const Icon(Icons.fit_screen, size: 18),
            label: const Text('Rotayı göster'),
          ),
      ]),
    ),
  ]);
}
