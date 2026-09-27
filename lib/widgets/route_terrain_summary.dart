import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/route_itinerary_service.dart';
import '../services/route_terrain_service.dart';
import '../theme/app_theme.dart';

class RouteTerrainSummary extends StatefulWidget {
  const RouteTerrainSummary({
    super.key,
    required this.route,
    required this.mode,
    this.manual = false,
    this.service,
  });
  final RouteItinerary? route;
  final String mode;
  final bool manual;
  final RouteTerrainService? service;
  @override
  State<RouteTerrainSummary> createState() => _RouteTerrainSummaryState();
}

class _RouteTerrainSummaryState extends State<RouteTerrainSummary> {
  Future<RouteTerrain?>? _future;
  void _load() {
    _future = widget.route == null || !RouteTerrainService.supports(widget.mode)
        ? null
        : (widget.service ?? RouteTerrainService.instance).load(
            widget.route!.points,
            widget.mode,
          );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RouteTerrainSummary old) {
    super.didUpdateWidget(old);
    if (old.route != widget.route ||
        old.mode != widget.mode ||
        old.service != widget.service)
      _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!RouteTerrainService.supports(widget.mode) || widget.route == null)
      return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: FutureBuilder<RouteTerrain?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Text('Yükselti ve zorluk hesaplanıyor…');
          }
          final terrain = snapshot.data;
          if (terrain == null)
            return TextButton.icon(
              onPressed: () => setState(_load),
              icon: const Icon(Icons.refresh),
              label: const Text(
                'Yükselti alınamadı · Zorluk hesaplanamadı · Yeniden dene',
              ),
            );
          final gain = terrain.gainLoss;
          final low = terrain.samples.map((s) => s.elevation).reduce(math.min);
          final high = terrain.samples.map((s) => s.elevation).reduce(math.max);
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Yükselti',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.terrain_outlined, size: 18),
                      label: Text(
                        'Tahmini zorluk: ${terrain.difficulty(widget.mode)}',
                      ),
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        useSafeArea: true,
                        showDragHandle: true,
                        builder: (_) => Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            '${terrain.reason(widget.mode)}${widget.manual ? '\nElle çizilmiş güzergâhın yol uygunluğu doğrulanmadı.' : ''}',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '↗ ${gain.$1.round()} m çıkış   ↘ ${gain.$2.round()} m iniş',
                ),
                const SizedBox(height: 12),
                Text('${high.round()} m', style: const TextStyle(fontSize: 11)),
                Semantics(
                  label:
                      'Yükselti grafiği. En düşük ${low.round()}, en yüksek ${high.round()} metre.',
                  child: SizedBox(
                    height: 90,
                    child: CustomPaint(painter: _ElevationPainter(terrain)),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '0 km · ${low.round()}–${high.round()} m',
                      style: const TextStyle(fontSize: 11),
                    ),
                    Text(
                      '${(terrain.meters / 1000).toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Yaklaşık değerler · Yükselti: SRTM / Open Topo Data',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ElevationPainter extends CustomPainter {
  _ElevationPainter(this.terrain);
  final RouteTerrain terrain;
  @override
  void paint(Canvas canvas, Size size) {
    final values = terrain.samples;
    final low = values.map((s) => s.elevation).reduce(math.min);
    final high = values.map((s) => s.elevation).reduce(math.max);
    final range = math.max(10.0, high - low);
    final line = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values[i].meters / terrain.meters * size.width;
      final y =
          size.height -
          5 -
          (values[i].elevation - low) / range * (size.height - 10);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = AppColors.cyan.withValues(alpha: .15),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.cyan
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_ElevationPainter old) => old.terrain != terrain;
}
