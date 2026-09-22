import '../services/route_geometry.dart';
import '../services/route_draft_store.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/route_itinerary_service.dart';
import '../theme/app_theme.dart';

class RouteMapPreview extends StatefulWidget {
  const RouteMapPreview({
    super.key,
    required this.stops,
    required this.transport,
    required this.onOpen,
    this.dayPlan = const {},
    this.origin = const {},
    this.height = 170,
    this.interactive = false,
  });
  final List<Map<String, dynamic>> stops;
  final String transport;
  final double height;
  final bool interactive;
  final Map<String, dynamic> dayPlan, origin;
  final VoidCallback onOpen;
  @override
  State<RouteMapPreview> createState() => _RouteMapPreviewState();
}

class _RouteMapPreviewState extends State<RouteMapPreview> {
  late Future<RouteItinerary?> _route;
  bool _showMap = false;
  Timer? _mapDelay;
  @override
  void dispose() {
    _mapDelay?.cancel();
    super.dispose();
  }

  List<LatLng> get _points =>
      widget.stops
          .where((p) => p['latitude'] is num && p['longitude'] is num)
          .map(
            (p) => LatLng(
              (p['latitude'] as num).toDouble(),
              (p['longitude'] as num).toDouble(),
            ),
          )
          .toList();
  void _load() {
    final origin =
        widget.origin['latitude'] is num && widget.origin['longitude'] is num
            ? LatLng(
              (widget.origin['latitude'] as num).toDouble(),
              (widget.origin['longitude'] as num).toDouble(),
            )
            : null;
    final spots =
        widget.stops
            .where((p) => p['latitude'] is num && p['longitude'] is num)
            .map(
              (p) => RouteDraftStore.decodeSpot({
                ...p,
                'id': (p['id'] ?? '').toString(),
                'name': (p['name'] ?? 'Durak').toString(),
                'city': (p['city'] ?? '').toString(),
              }),
            )
            .toList();
    final points = RouteGeometry.waypoints(
      spots,
      origin: origin,
      roundTrip: widget.dayPlan['roundTrip'] == true,
    );
    final valid =
        widget.dayPlan['signature'] ==
        RouteGeometry.signature(
          spots,
          widget.transport,
          origin: origin,
          roundTrip: widget.dayPlan['roundTrip'] == true,
        );
    final saved = valid ? RouteGeometry.decode(widget.dayPlan) : null;
    _route =
        saved != null
            ? Future.value(saved)
            : widget.dayPlan['manual'] == true
            ? Future.value(RouteGeometry.manual(points))
            : RouteItineraryService.instance.calculate(
              points,
              widget.transport,
            );
  }

  @override
  void initState() {
    super.initState();
    _load();
    _mapDelay = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _showMap = true);
    });
  }

  @override
  void didUpdateWidget(RouteMapPreview old) {
    super.didUpdateWidget(old);
    if (old.transport != widget.transport ||
        old.stops.toString() != widget.stops.toString() ||
        old.dayPlan.toString() != widget.dayPlan.toString() ||
        old.origin.toString() != widget.origin.toString())
      _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<RouteItinerary?>(
    future: _route,
    builder: (_, s) {
      final points = _points;
      if (points.isEmpty) return const SizedBox.shrink();
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            SizedBox(
              height: widget.height,
              child:
                  !_showMap
                      ? const ColoredBox(
                        color: AppColors.surfaceAlt,
                        child: Center(child: Text('Harita hazırlanıyor…')),
                      )
                      : GoogleMap(
                        liteModeEnabled: !widget.interactive,
                        key: ValueKey(points.toString()),
                        initialCameraPosition: CameraPosition(
                          target: points.first,
                          zoom: 11,
                        ),
                        style:
                            '[{"elementType":"geometry","stylers":[{"color":"#17212b"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#bac8d4"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#17212b"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#0c151f"}]}]',
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                        mapToolbarEnabled: false,
                        scrollGesturesEnabled: widget.interactive,
                        zoomGesturesEnabled: widget.interactive,
                        rotateGesturesEnabled: widget.interactive,
                        tiltGesturesEnabled: widget.interactive,
                        onTap: (_) => widget.onOpen(),
                        onMapCreated: (c) async {
                          if (points.length > 1) {
                            final fitPoints = [...points, ...?s.data?.points];
                            final lat =
                                fitPoints.map((p) => p.latitude).toList()
                                  ..sort();
                            final lng =
                                fitPoints.map((p) => p.longitude).toList()
                                  ..sort();
                            if (lat.first != lat.last ||
                                lng.first != lng.last) {
                              try {
                                await c.moveCamera(
                                  CameraUpdate.newLatLngBounds(
                                    LatLngBounds(
                                      southwest: LatLng(lat.first, lng.first),
                                      northeast: LatLng(lat.last, lng.last),
                                    ),
                                    30,
                                  ),
                                );
                              } catch (_) {}
                            }
                          }
                        },
                        markers: {
                          for (var i = 0; i < points.length; i++)
                            Marker(
                              markerId: MarkerId('$i'),
                              position: points[i],
                              infoWindow: InfoWindow(
                                title: '${i + 1}. ${widget.stops[i]['name']}',
                              ),
                            ),
                        },
                        polylines: {
                          if (s.data != null)
                            Polyline(
                              polylineId: const PolylineId('route'),
                              points: s.data!.points,
                              color: AppColors.cyan,
                              width: 4,
                            ),
                        },
                      ),
            ),
            Container(
              color: const Color(0xFF12151C),
              padding: const EdgeInsets.all(10),
              width: double.infinity,
              child: Text(
                s.connectionState != ConnectionState.done
                    ? 'Güzergâh hesaplanıyor…'
                    : s.data == null
                    ? 'Yol bilgisi alınamadı · Haritayı aç'
                    : '${(s.data!.meters / 1000).toStringAsFixed(1)} km · ${widget.dayPlan['manual'] == true ? 'Elle çizilmiş · Doğrulanmamış' : '${(s.data!.seconds / 60).ceil()} dk yol'}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    },
  );
}
