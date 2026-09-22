import '../widgets/route_terrain_summary.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/photo_spot.dart';
import '../services/route_geometry.dart';
import '../services/route_draft_store.dart';
import '../services/route_itinerary_service.dart';
import '../theme/app_theme.dart';
import '../widgets/route_editor_map.dart';
import '../widgets/route_design/route_design.dart';

class RoutePathResult {
  const RoutePathResult(this.stops, this.manual, this.roundTrip);
  final List<PhotoSpot> stops;
  final bool manual, roundTrip;
}

class RoutePathEditorScreen extends StatefulWidget {
  const RoutePathEditorScreen({
    super.key,
    required this.stops,
    required this.city,
    required this.mode,
    this.origin,
    this.manual = false,
    this.roundTrip = false,
  });
  final List<PhotoSpot> stops;
  final String city, mode;
  final LatLng? origin;
  final bool manual, roundTrip;
  @override
  State<RoutePathEditorScreen> createState() => _RoutePathEditorScreenState();
}

class _RoutePathEditorScreenState extends State<RoutePathEditorScreen> {
  late List<PhotoSpot> _stops = [...widget.stops];
  late bool _manual = widget.manual, _round = widget.roundTrip;
  final _history = <List<PhotoSpot>>[];
  RouteItinerary? _route;
  bool _loading = false;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _calculate();
  }

  Future<void> _calculate() async {
    final request = ++_request;
    final points = RouteGeometry.waypoints(
      _stops,
      origin: widget.origin,
      roundTrip: _round,
    );
    setState(() {
      _loading = !_manual && points.length > 1;
      _route = null;
    });
    final route =
        points.length < 2
            ? null
            : _manual
            ? RouteGeometry.manual(points)
            : await RouteItineraryService.instance.calculate(
              points,
              widget.mode,
            );
    if (mounted && request == _request)
      setState(() {
        _route = route;
        _loading = false;
      });
  }

  void _add(LatLng point) {
    if (_stops.length >= 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('En fazla 12 durak veya geçiş noktası ekleyebilirsin.'),
        ),
      );
      return;
    }
    _history.add([..._stops]);
    setState(
      () => _stops.add(
        PhotoSpot(
          id: 'map:${DateTime.now().microsecondsSinceEpoch}',
          name: 'Geçiş noktası ${_stops.length + 1}',
          city: widget.city,
          latitude: point.latitude,
          longitude: point.longitude,
          rating: 0,
          bestTime: '',
          angle: '',
          imageUrl: '',
          category: 'Geçiş noktası',
        ),
      ),
    );
    _calculate();
  }

  Future<void> _edit(PhotoSpot stop) async {
    final controller = TextEditingController(text: stop.name);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (c) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.viewInsetsOf(c).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Noktanın adı'),
                ),
                RouteAction(
                  label: 'Adı kaydet',
                  onPressed: () => Navigator.pop(c, 'rename'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(c, 'remove'),
                  child: const Text('Rotadan kaldır'),
                ),
              ],
            ),
          ),
    );
    final name = controller.text.trim();
    controller.dispose();
    if (!mounted || result == null) return;
    _history.add([..._stops]);
    setState(() {
      if (result == 'remove') {
        _stops.removeWhere((s) => s.id == stop.id);
      } else if (name.isNotEmpty) {
        final i = _stops.indexWhere((s) => s.id == stop.id);
        if (i >= 0)
          _stops[i] = RouteDraftStore.decodeSpot({
            ...RouteDraftStore.encodeSpot(stop),
            'name': name,
          });
      }
    });
    _calculate();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Güzergâh oluştur')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(RouteModePicker.icon(widget.mode), color: AppColors.cyan),
              const SizedBox(width: 8),
              Text(widget.mode),
              const Spacer(),
              TextButton.icon(
                onPressed:
                    _history.isEmpty
                        ? null
                        : () {
                          setState(() => _stops = _history.removeLast());
                          _calculate();
                        },
                icon: const Icon(Icons.undo),
                label: const Text('Geri al'),
              ),
            ],
          ),
        ),
        Expanded(
          child: RouteEditorMap(
              city: widget.city,
            stops: _stops,
            itinerary: _route,
            center: widget.origin,
            interactive: true,
            onMapTap: _add,
            onPlaceTap: _edit,
          ),
        ),
        SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .42,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Yolunu belirle',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    'Geçmek istediğin noktalara dokun.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Yola bağla'),
                        icon: Icon(Icons.route),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Elle çiz'),
                        icon: Icon(Icons.edit_outlined),
                      ),
                    ],
                    selected: {_manual},
                    onSelectionChanged: (v) {
                      setState(() => _manual = v.first);
                      _calculate();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Başladığım yere dön'),
                    value: _round,
                    onChanged: (v) {
                      setState(() => _round = v);
                      _calculate();
                    },
                  ),
                  if (_manual)
                    const Text(
                      'Elle çizilen bölümün yol uygunluğu doğrulanmaz. Süre hesaplanmaz.',
                      style: TextStyle(color: AppColors.warning, fontSize: 12),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      _loading
                          ? 'Güzergâh hesaplanıyor…'
                          : _route == null
                          ? 'En az iki nokta seç. Yol bulunamazsa noktaları değiştir.'
                          : '${(_route!.meters / 1000).toStringAsFixed(1)} km${_manual ? ' · Elle çizilmiş' : ' · ${(_route!.seconds / 60).ceil()} dk'}',
                    ),
                  ),
                  RouteTerrainSummary(route: _route, mode: widget.mode, manual: _manual),
                  RouteAction(
                    label: 'Güzergâhı kullan',
                    onPressed:
                        _loading || _route == null
                            ? null
                            : () => Navigator.pop(
                              context,
                              RoutePathResult(_stops, _manual, _round),
                            ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
