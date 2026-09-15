import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/photo_spot.dart';
import '../services/nearby_venue_service.dart';
import '../services/route_itinerary_service.dart';
import '../services/route_stop_catalog.dart';
import '../services/spot_browsing.dart';
import '../services/user_facing_error.dart';
import '../theme/app_theme.dart';
import 'route_editor_map.dart';

class RouteStopsStep extends StatefulWidget {
  const RouteStopsStep({
    super.key,
    required this.city,
    required this.stops,
    required this.onAdd,
    required this.onMapTap,
    required this.onReorder,
    required this.stopBuilder,
    required this.onSuggest,
    required this.onSort,
    required this.onSearch,
    this.itinerary,
    this.busy = false,
    this.loadItems,
  });
  final String city;
  final List<PhotoSpot> stops;
  final ValueChanged<PhotoSpot> onAdd;
  final ValueChanged<LatLng> onMapTap;
  final void Function(int, int) onReorder;
  final Widget Function(int) stopBuilder;
  final VoidCallback onSuggest, onSort, onSearch;
  final RouteItinerary? itinerary;
  final bool busy;
  final Future<List<PhotoSpot>> Function(int)? loadItems;
  @override
  State<RouteStopsStep> createState() => _RouteStopsStepState();
}

class _RouteStopsStepState extends State<RouteStopsStep> {
  final _sheet = DraggableScrollableController();
  final _categories = <int>{0};
  final _items = <int, List<PhotoSpot>>{};
  final _loading = <int>{};
  final _errors = <int, String>{};
  String _query = '';
  bool _showStops = false;
  LatLng? _center;
  @override
  void initState() {
    super.initState();
    _load(0);
    _locate();
  }

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  void _showSelected() {
    setState(() => _showStops = true);
    if (_sheet.isAttached)
      unawaited(
        _sheet.animateTo(
          .7,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
  }

  Future<void> _locate() async {
    final area = await NearbyVenueService.instance.findCity(widget.city);
    if (mounted && area != null)
      setState(() => _center = LatLng(area.latitude, area.longitude));
  }

  Future<void> _load(int category) async {
    if (_loading.contains(category)) return;
    setState(() {
      _loading.add(category);
      _errors.remove(category);
    });
    try {
      final items =
          await (widget.loadItems?.call(category) ??
              loadRouteStopCatalog(widget.city, category));
      if (mounted) setState(() => _items[category] = items);
    } catch (e) {
      if (mounted) setState(() => _errors[category] = userFacingError(e));
    } finally {
      if (mounted) setState(() => _loading.remove(category));
    }
  }

  Future<void> _selectPlace(PhotoSpot spot) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              spot.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Text('${spot.city} · ${spot.category}'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onAdd(spot);
              },
              icon: const Icon(Icons.add),
              label: const Text('Rotaya ekle'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final places = [for (final c in _categories) ...?_items[c]]
        .where(
          (s) =>
              foldPlaceText('${s.name} ${s.category}')
                  .contains(foldPlaceText(_query)),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Mekân veya yer ara',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() {
              _query = v;
              _showStops = false;
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final item in const [
                (0, 'Gezi'),
                (1, 'Lezzet'),
                (2, 'Kafeler'),
                (3, 'Oteller'),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: FilterChip(
                      showCheckmark: false,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      label: Text(
                        item.$2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: _categories.contains(item.$1),
                      onSelected: widget.busy
                          ? null
                          : (selected) {
                              setState(() {
                                selected
                                    ? _categories.add(item.$1)
                                    : _categories.remove(item.$1);
                                _showStops = false;
                              });
                              if (selected && !_items.containsKey(item.$1))
                                unawaited(_load(item.$1));
                            },
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_categories.any(_loading.contains))
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // On short screens/with the keyboard, keep the searchable list usable.
              final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
              if (keyboard || constraints.maxHeight < 240)
                return _list(null, places);
              return Stack(
                children: [
                  Positioned.fill(
                    child: RouteEditorMap(
                      stops: widget.stops,
                      itinerary: widget.itinerary,
                      center: _center,
                      padding: EdgeInsets.only(
                        bottom: constraints.maxHeight * .38,
                      ),
                      interactive: true,
                      candidates: places,
                      onPlaceTap: widget.busy ? null : _selectPlace,
                      onMapTap: widget.busy ? null : widget.onMapTap,
                    ),
                  ),
                  DraggableScrollableSheet(
                    controller: _sheet,
                    initialChildSize: .38,
                    minChildSize: .22,
                    maxChildSize: .88,
                    builder: (context, controller) => Material(
                      color: AppColors.surface,
                      elevation: 8,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _list(controller, places),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _list(
    ScrollController? controller,
    List<PhotoSpot> places,
  ) => CustomScrollView(
    controller: controller,
    slivers: [
      SliverToBoxAdapter(
        child: Column(
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(() => _showStops = false),
                    child: Text(
                      'Yerler (${places.length})',
                      style: TextStyle(
                        color: !_showStops
                            ? AppColors.cyan
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: _showSelected,
                    child: Text(
                      'Duraklarım (${widget.stops.length})',
                      style: TextStyle(
                        color: _showStops
                            ? AppColors.cyan
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: widget.busy ? null : widget.onSuggest,
                  child: const Text('Bana rota öner'),
                ),
                TextButton.icon(
                  onPressed: widget.busy || widget.stops.length < 3
                      ? null
                      : widget.onSort,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Akıllı sırala'),
                ),
                TextButton(
                  onPressed: widget.busy ? null : widget.onSearch,
                  child: const Text('Çoklu seçim'),
                ),
              ],
            ),
            if (_showStops && widget.stops.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Haritadan veya yerler listesinden durak ekle.'),
              ),
            if (!_showStops && _categories.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Görmek istediğin kategorileri seç.'),
              ),
            if (!_showStops &&
                places.isEmpty &&
                _categories.isNotEmpty &&
                !_categories.any(_loading.contains))
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Bu aramada yer bulunamadı. Haritaya dokunarak da durak ekleyebilirsin.',
                ),
              ),
            for (final category in _categories.where(_errors.containsKey))
              ListTile(
                title: Text(
                  _errors[category]!,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: TextButton(
                  onPressed: () => _load(category),
                  child: const Text('Tekrar dene'),
                ),
              ),
          ],
        ),
      ),
      if (_showStops)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverReorderableList(
            itemCount: widget.stops.length,
            onReorder: widget.onReorder,
            itemBuilder: (_, i) => widget.stopBuilder(i),
          ),
        )
      else
        SliverList.builder(
          itemCount: places.length,
          itemBuilder: (context, index) {
            final spot = places[index];
            final selected = widget.stops.any((s) => s.id == spot.id);
            return ListTile(
              title: Text(
                spot.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(spot.category),
              trailing: Icon(
                selected ? Icons.check_circle : Icons.add_circle_outline,
                color: selected ? AppColors.cyan : AppColors.textMuted,
              ),
              onTap: selected || widget.busy ? null : () => widget.onAdd(spot),
            );
          },
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
    ],
  );
}
