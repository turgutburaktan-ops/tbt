import 'package:flutter/material.dart';

import '../models/photo_spot.dart';
import '../models/nearby_venue.dart';
import '../services/nearby_venue_service.dart';
import '../services/spot_repository.dart';
import '../services/user_facing_error.dart';

class RouteStopPicker extends StatefulWidget {
  const RouteStopPicker({
    super.key,
    required this.city,
    required this.stops,
    this.multiple = false,
    this.loadItems,
  });
  final String city;
  final List<PhotoSpot> stops;
  final bool multiple;
  final Future<List<PhotoSpot>> Function(int category)? loadItems;
  @override
  State<RouteStopPicker> createState() => _RouteStopPickerState();
}

class _RouteStopPickerState extends State<RouteStopPicker> {
  final _selected = <String, PhotoSpot>{};
  int _category = 0;
  String _query = '';
  late Future<List<PhotoSpot>> _items = _load();

  String _fold(String value) => value
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  Future<List<PhotoSpot>> _load() async {
    if (widget.loadItems != null) return widget.loadItems!(_category);
    if (_category == 0) {
      final spots = await SpotRepository.instance.loadSpots();
      return spots
          .where(
            (spot) =>
                widget.city.isEmpty || _fold(spot.city) == _fold(widget.city),
          )
          .toList();
    }
    final category = NearbyVenueCategory.values[_category - 1];
    final anchor = widget.stops.isEmpty ? null : widget.stops.last;
    final city = anchor == null
        ? await NearbyVenueService.instance.findCity(widget.city)
        : null;
    if (anchor == null && city == null) {
      throw Exception('Mekânları bulmak için önce bir gezilecek yer ekle.');
    }
    final venues = await NearbyVenueService.instance.nearby(
      category: category,
      latitude: anchor?.latitude ?? city!.latitude,
      longitude: anchor?.longitude ?? city!.longitude,
      useSelectedCity: false,
    );
    return venues
        .map(
          (v) => PhotoSpot(
            id: 'venue:${v.category.name}:${v.id}',
            name: v.name,
            city: widget.city,
            latitude: v.latitude,
            longitude: v.longitude,
            rating: 0,
            bestTime: v.openingHours,
            angle: '',
            imageUrl: v.imageUrl,
            category: v.category.label,
            description: v.description,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .8,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        14,
        14,
        MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        children: [
          const Text(
            'Rotaya yer veya mekân ekle',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(
              hintText: 'İsimle ara',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final item in [
                (0, 'Gezilecek Yerler'),
                (1, 'Lezzet'),
                (2, 'Kafeler'),
                (3, 'Oteller'),
              ])
                ChoiceChip(
                  label: Text(item.$2),
                  selected: _category == item.$1,
                  onSelected: (_) => setState(() {
                    _category = item.$1;
                    _items = _load();
                  }),
                ),
            ],
          ),
          Expanded(
            child: FutureBuilder<List<PhotoSpot>>(
              future: _items,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError)
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userFacingError(snapshot.error!),
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: () => setState(() => _items = _load()),
                          child: const Text('Tekrar dene'),
                        ),
                      ],
                    ),
                  );
                final items = (snapshot.data ?? [])
                    .where((s) => _fold(s.name).contains(_fold(_query)))
                    .toList();
                if (items.isEmpty)
                  return const Center(
                    child: Text('Aramana uygun yer bulunamadı.'),
                  );
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final spot = items[index];
                    final existing = widget.stops.any((s) => s.id == spot.id);
                    final selected = existing || _selected.containsKey(spot.id);
                    return ListTile(
                      title: Text(spot.name),
                      subtitle: Text(
                        existing ? 'Rotada zaten var' : spot.category,
                      ),
                      trailing: Icon(
                        selected
                            ? Icons.check_circle
                            : widget.multiple
                            ? Icons.radio_button_unchecked
                            : Icons.add,
                      ),
                      selected: _selected.containsKey(spot.id),
                      onTap: existing
                          ? null
                          : () {
                              if (!widget.multiple) {
                                Navigator.pop(context, spot);
                                return;
                              }
                              if (_selected.containsKey(spot.id)) {
                                setState(() => _selected.remove(spot.id));
                                return;
                              }
                              if (widget.stops.length + _selected.length >=
                                  12) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Rotaya en fazla 12 durak ekleyebilirsin.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              setState(() => _selected[spot.id] = spot);
                            },
                    );
                  },
                );
              },
            ),
          ),
          if (widget.multiple)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () =>
                              Navigator.pop(context, _selected.values.toList()),
                    child: Text(
                      _selected.isEmpty
                          ? 'Eklemek istediğin yerleri seç'
                          : 'Seçilenleri ekle (${_selected.length})',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
