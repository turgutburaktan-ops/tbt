import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/photo_spot.dart';
import '../services/route_itinerary_service.dart';
import '../theme/app_theme.dart';

/// A real map: road geometry is drawn only when the routing service returns it.
class RouteEditorMap extends StatefulWidget {
  const RouteEditorMap({
    super.key,
    required this.stops,
    this.itinerary,
    this.interactive = false,
    this.center,
    this.candidates = const [],
    this.onPlaceTap,
    this.onMapTap,
  });
  final List<PhotoSpot> stops;
  final RouteItinerary? itinerary;
  final bool interactive;
  final LatLng? center;
  final List<PhotoSpot> candidates;
  final ValueChanged<PhotoSpot>? onPlaceTap;
  final ValueChanged<LatLng>? onMapTap;
  @override
  State<RouteEditorMap> createState() => _RouteEditorMapState();
}

class _RouteEditorMapState extends State<RouteEditorMap> {
  GoogleMapController? _controller;
  final _icons = <int, BitmapDescriptor>{};
  int _iconGeneration = 0;
  String _lastFit = '';
  String get _fitKey =>
      '${widget.center}:${_points.join(';')}:${widget.itinerary?.meters}';
  List<LatLng> get _points =>
      widget.stops.map((s) => LatLng(s.latitude, s.longitude)).toList();

  @override
  void initState() {
    super.initState();
    _makeIcons();
  }

  @override
  void didUpdateWidget(RouteEditorMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stops.length > _icons.length) _makeIcons();
    // Parent lists are mutable; fit from current coordinates after every update.
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
        Paint()..color = AppColors.blue,
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
      if (widget.center != null) {
        try {
          await controller.moveCamera(
            CameraUpdate.newLatLngZoom(widget.center!, 12),
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
  Widget build(BuildContext context) => GoogleMap(
    initialCameraPosition: CameraPosition(
      target: _points.isEmpty
          ? (widget.center ?? const LatLng(39, 35))
          : _points.first,
      zoom: 13,
    ),
    style: '[{"elementType":"geometry","stylers":[{"color":"#171c24"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#aab4c2"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#171c24"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#303b4a"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#0c1723"}]},{"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]}]',
    zoomControlsEnabled: false,
    myLocationButtonEnabled: false,
    mapToolbarEnabled: false,
    scrollGesturesEnabled: widget.interactive,
    zoomGesturesEnabled: widget.interactive,
    rotateGesturesEnabled: widget.interactive,
    tiltGesturesEnabled: false,
    onTap: widget.onMapTap,
    onMapCreated: (controller) {
      _controller = controller;
      _fit();
    },
    markers: {
      for (final spot in widget.candidates.where(
        (s) => !widget.stops.any((p) => p.id == s.id),
      ))
        Marker(
          markerId: MarkerId('candidate:${spot.id}'),
          position: LatLng(spot.latitude, spot.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet,
          ),
          onTap: () => widget.onPlaceTap?.call(spot),
        ),
      for (var i = 0; i < widget.stops.length; i++)
        Marker(
          markerId: MarkerId(widget.stops[i].id),
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
          color: AppColors.blue,
          width: 5,
        ),
    },
  );
}
