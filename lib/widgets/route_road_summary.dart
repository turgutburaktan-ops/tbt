import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/route_itinerary_service.dart';

class RouteRoadSummary extends StatefulWidget {
  final List<Map<String, dynamic>> stops;
  final String transport;
  const RouteRoadSummary({
    super.key,
    required this.stops,
    required this.transport,
  });
  @override
  State<RouteRoadSummary> createState() => _RouteRoadSummaryState();
}

class _RouteRoadSummaryState extends State<RouteRoadSummary> {
  late Future<RouteItinerary?> _result;
  String get _key =>
      '${widget.transport}:${widget.stops.map((s) => '${s['latitude']},${s['longitude']}').join(';')}';
  late String _previous;
  void _load() {
    _previous = _key;
    final points = widget.stops
        .where((s) => s['latitude'] is num && s['longitude'] is num)
        .map(
          (s) => LatLng(
            (s['latitude'] as num).toDouble(),
            (s['longitude'] as num).toDouble(),
          ),
        )
        .toList();
    _result = points.length != widget.stops.length
        ? Future.value(null)
        : RouteItineraryService.instance.calculate(points, widget.transport);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RouteRoadSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_previous != _key) _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<RouteItinerary?>(
    future: _result,
    builder: (_, s) {
      if (widget.stops.length < 2)
        return const Text('Yol mesafesi için en az iki durak gerekli.');
      if (s.connectionState != ConnectionState.done)
        return const Text('Yol mesafesi hesaplanıyor…');
      if (s.data == null)
        return TextButton(
          onPressed: () => setState(_load),
          child: const Text('Uygun güzergâh bulunamadı. Yeniden dene'),
        );
      final r = s.data!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${(r.meters / 1000).toStringAsFixed(1)} km · ${(r.seconds / 60).ceil()} dk yol · ${widget.transport}',
          ),
          ExpansionTile(
            title: const Text('Duraklar arası mesafeler'),
            children: [
              for (var i = 0; i < r.legs.length; i++)
                ListTile(
                  title: Text(
                    '${widget.stops[i]['name']} → ${widget.stops[i + 1]['name']}',
                  ),
                  subtitle: Text(r.legs[i].label),
                ),
            ],
          ),
          const Text(
            'Yol verisi: © OpenStreetMap · FOSSGIS. Süre trafik ve molalara göre değişebilir.',
          ),
        ],
      );
    },
  );
}
