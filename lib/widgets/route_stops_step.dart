import 'spot_image.dart';
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
    required this.onRemove,
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
  final ValueChanged<PhotoSpot> onAdd, onRemove;
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
  final _search = TextEditingController();
  final _categories = <int>{0};
  final _items = <int, List<PhotoSpot>>{};
  final _loading = <int>{};
  final _errors = <int, String>{};
  String _query = '';
  bool _showStops = false;
  bool _showMap = false;
  LatLng? _center;
  @override
  void initState() {
    super.initState();
    _load(0);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _selected(PhotoSpot spot) => widget.stops.any((s) => s.id == spot.id);

  void _toggle(PhotoSpot spot) {
    if (widget.busy) return;
    _selected(spot) ? widget.onRemove(spot) : widget.onAdd(spot);
  }

  Future<void> _locate() async {
    try {
      final area = await NearbyVenueService.instance.findCity(widget.city);
      if (mounted && area != null) {
        setState(() => _center = LatLng(area.latitude, area.longitude));
      }
    } catch (_) {
      // The map remains usable with existing stops when city lookup is offline.
    }
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
    final selected = _selected(spot);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (context) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  spot.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text('${spot.city} · ${spot.category}'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _toggle(spot);
                  },
                  icon: Icon(
                    selected ? Icons.remove_circle_outline : Icons.add,
                  ),
                  label: Text(selected ? 'Rotadan kaldır' : 'Rotaya ekle'),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final places =
        [for (final c in _categories) ...?_items[c]]
            .where(
              (s) => foldPlaceText(
                '${s.name} ${s.category}',
              ).contains(foldPlaceText(_query)),
            )
            .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Yer ara'),
                icon: Icon(Icons.search),
              ),
              ButtonSegment(
                value: true,
                label: Text('Haritadan seç'),
                icon: Icon(Icons.map_outlined),
              ),
            ],
            selected: {_showMap},
            onSelectionChanged: (v) {
              FocusScope.of(context).unfocus();
              setState(() => _showMap = v.first);
              if (_showMap && _center == null) unawaited(_locate());
            },
          ),
        ),
        if (!_showStops) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Mekân veya yer ara',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _query.isEmpty
                        ? null
                        : IconButton(
                          tooltip: 'Aramayı temizle',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final item in const [
                  (0, 'Gezi'),
                  (1, 'Lezzet'),
                  (2, 'Kafeler'),
                  (3, 'Oteller'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(item.$2),
                      selected: _categories.contains(item.$1),
                      onSelected:
                          widget.busy
                              ? null
                              : (selected) {
                                setState(() {
                                  selected
                                      ? _categories.add(item.$1)
                                      : _categories.remove(item.$1);
                                });
                                if (selected && !_items.containsKey(item.$1)) {
                                  unawaited(_load(item.$1));
                                }
                              },
                    ),
                  ),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _showStops
                      ? 'Sürükleyerek sırala, × ile kaldır.'
                      : '${places.length} yer · Eklemek için dokun',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!_showStops && _categories.any(_loading.contains))
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child:
              _showMap
                  ? Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Text(
                          'Bir yere dokunarak ekle veya kaldır. Boş bir noktaya dokunarak yeni durak ekle.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: RouteEditorMap(
              city: widget.city,
                          stops: widget.stops,
                          itinerary: widget.itinerary,
                          center: _center,
                          interactive: true,
                          candidates: _showStops ? widget.stops : places,
                          onPlaceTap: widget.busy ? null : _selectPlace,
                          onMapTap: widget.busy ? null : widget.onMapTap,
                        ),
                      ),
                    ],
                  )
                  : _list(places),
        ),
      ],
    );
  }

  Widget _tab(String label, bool selectedTab) => TextButton(
    onPressed: () {
      FocusScope.of(context).unfocus();
      setState(() {
        _showStops = selectedTab;
        _showMap = false;
      });
    },
    style: TextButton.styleFrom(
      foregroundColor:
          _showStops == selectedTab ? AppColors.cyan : AppColors.textMuted,
      backgroundColor: _showStops == selectedTab ? AppColors.surface : null,
    ),
    child: Text(label),
  );

  Widget _list(List<PhotoSpot> places) => CustomScrollView(
    key: ValueKey(_showStops),
    slivers: [
      SliverToBoxAdapter(
        child: Column(
          children: [
            if (_showStops && widget.stops.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Henüz durak eklemedin. Yer ekle bölümünden başlayabilirsin.',
                ),
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
                padding: EdgeInsets.all(16),
                child: Text(
                  'Yer bulunamadı. Aramanı değiştir veya Harita üzerinden durak ekle.',
                ),
              ),
            if (!_showStops)
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
            final selected = _selected(spot);
            return ListTile(
              key: ValueKey('place-${spot.id}'),
              selected: selected,
              selectedTileColor: AppColors.surface,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: SpotImage(spot: spot, width: 56, height: 56),
                ),
              ),
              title: Text(
                spot.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(spot.category),
              trailing:
                  selected
                      ? TextButton.icon(
                        onPressed: widget.busy ? null : () => _toggle(spot),
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        label: const Text('Kaldır'),
                      )
                      : IconButton(
                        tooltip: 'Rotaya ekle',
                        onPressed: widget.busy ? null : () => _toggle(spot),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
              onTap: widget.busy ? null : () => _toggle(spot),
            );
          },
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
    ],
  );
}
