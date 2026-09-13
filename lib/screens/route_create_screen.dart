import 'package:flutter/material.dart';

import '../data/turkey_selection_data.dart';
import '../widgets/searchable_selection_field.dart';
import 'event_location_picker_screen.dart';

import '../models/photo_spot.dart';
import '../services/spot_repository.dart';
import '../services/travel_plan_service.dart';
import '../services/user_facing_error.dart';
import '../theme/app_theme.dart';
import '../widgets/route_stop_picker.dart';
import 'travel_plan_detail_screen.dart';
import 'routes_hub_screen.dart';

class RouteCreateScreen extends StatefulWidget {
  const RouteCreateScreen({super.key, this.initialStops = const []});
  final List<PhotoSpot> initialStops;
  @override
  State<RouteCreateScreen> createState() => _RouteCreateScreenState();
}

class _RouteCreateScreenState extends State<RouteCreateScreen> {
  final _city = TextEditingController();
  late final List<PhotoSpot> _stops = [...widget.initialStops];
  String _transport = 'Araç';
  String _visibility = 'private';
  bool _busy = false;
  DateTime? _startAt;
  EventLocationSelection? _meeting;
  final _meetingNote = TextEditingController();
  @override
  void initState() {
    super.initState();
    if (_stops.isNotEmpty) _city.text = _stops.first.city;
  }

  @override
  void dispose() {
    _city.dispose();
    _meetingNote.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startAt ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _startAt ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (!mounted || time == null) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!selected.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İleri bir tarih ve saat seç.')),
      );
      return;
    }
    setState(() => _startAt = selected);
  }

  Future<void> _pickMeeting() async {
    final spot = await showModalBottomSheet<PhotoSpot>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RouteStopPicker(city: _city.text.trim(), stops: const []),
    );
    if (!mounted || spot == null) return;
    setState(
      () => _meeting = EventLocationSelection(
        latitude: spot.latitude,
        longitude: spot.longitude,
        label: spot.name,
      ),
    );
  }

  Future<void> _meetingMap() async {
    FocusScope.of(context).unfocus();
    final point = await Navigator.push<EventLocationSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => EventLocationPickerScreen(
          city: _city.text.trim(),
          addressLabel: 'Buluşma noktası',
          initialLatitude: _meeting?.latitude,
          initialLongitude: _meeting?.longitude,
          title: 'Buluşma noktası seç',
        ),
      ),
    );
    if (mounted && point != null) setState(() => _meeting = point);
  }

  Future<void> _act(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final spot = await showModalBottomSheet<PhotoSpot>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RouteStopPicker(city: _city.text.trim(), stops: _stops),
    );
    if (spot != null && mounted)
      setState(() {
        if (!_stops.any((s) => s.id == spot.id)) _stops.add(spot);
        if (_city.text.trim().isEmpty) _city.text = spot.city;
      });
  }

  Future<void> _fromMap() async {
    FocusScope.of(context).unfocus();
    final point = await Navigator.push<EventLocationSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => EventLocationPickerScreen(
          city: _city.text.trim(),
          addressLabel: '',
          title: 'Haritadan durak seç',
          instruction: 'Eklemek istediğin noktaya dokun ve onayla.',
        ),
      ),
    );
    if (!mounted || point == null) return;
    final id =
        'map:${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}';
    if (_stops.any((s) => s.id == id)) return;
    setState(
      () => _stops.add(
        PhotoSpot(
          id: id,
          name: point.label.trim().isEmpty
              ? 'Haritadan seçilen durak'
              : point.label,
          city: _city.text.trim(),
          latitude: point.latitude,
          longitude: point.longitude,
          rating: 0,
          bestTime: '',
          angle: '',
          imageUrl: '',
          category: 'Konum',
          description: '',
        ),
      ),
    );
  }

  Future<void> _suggest() => _act(() async {
    if (_city.text.trim().isEmpty)
      throw Exception('Önce şehir veya bölge yaz.');
    final all = await SpotRepository.instance.search(
      _city.text.trim(),
      limit: 100,
    );
    if (all.isEmpty)
      throw Exception(
        'Burada önerilecek durak bulunamadı. Durak ekleyebilirsin.',
      );
    final sorted = all.toList()..sort((a, b) => b.rating.compareTo(a.rating));
    if (mounted)
      setState(() {
        for (final s in sorted.take(4)) {
          if (_stops.length < 12 && !_stops.any((p) => p.id == s.id))
            _stops.add(s);
        }
      });
  });
  Future<void> _save() => _act(() async {
    final city = _city.text.trim().isEmpty
        ? _stops.first.city
        : _city.text.trim();
    final id = await TravelPlanService.instance.create(
      title: '$city gezisi',
      city: city,
      durationHours: 3,
      budget: 'Orta',
      transport: _transport,
      interests: [],
      spots: _stops,
      visibility: _visibility,
      startAt: _startAt,
      meetingPoint: _meeting == null
          ? const {}
          : {
              'label': _meeting!.label,
              'latitude': _meeting!.latitude,
              'longitude': _meeting!.longitude,
              'note': _meetingNote.text.trim(),
            },
    );
    final plan = await TravelPlanService.instance.read(id, preferCache: true);
    if (mounted)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => TravelPlanDetailScreen(plan: plan)),
      );
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Rota oluştur')),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_stops.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Başlamak için bir durak ekle',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            FilledButton(
              onPressed: _busy || _stops.isEmpty ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              child: Text(_busy ? 'Hazırlanıyor…' : 'Rotayı oluştur'),
            ),
          ],
        ),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.initialStops.isEmpty ? 'Nereye gidiyoruz?' : 'Rotanı düzenle',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        SearchableSelectionField(
          controller: _city,
          options: turkeyCities,
          labelText: 'İl seç',
          hintText: 'Örn. Elazığ',
          prefixIcon: Icons.location_city_outlined,
          enabled: !_busy,
          onSelected: (_) => FocusScope.of(context).unfocus(),
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final mode in ['Araç', 'Yürüyüş', 'Bisiklet'])
              ButtonSegment(
                value: mode,
                label: Text(mode),
                icon: Icon(routeTransportIcon(mode), size: 18),
              ),
          ],
          selected: {_transport},
          onSelectionChanged: _busy
              ? null
              : (value) => setState(() => _transport = value.first),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Durakların',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : _suggest,
              child: const Text('Bana rota öner'),
            ),
          ],
        ),
        if (_stops.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Gezilecek yer veya mekân ekleyerek başla.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _stops.length,
          onReorder: (a, b) {
            if (_busy) return;
            setState(() {
              if (b > a) b--;
              _stops.insert(b, _stops.removeAt(a));
            });
          },
          itemBuilder: (_, i) => Card(
            key: ValueKey(_stops[i].id),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.surfaceStrong,
                foregroundColor: Colors.white,
                child: Text('${i + 1}'),
              ),
              title: Text(_stops[i].name),
              subtitle: Text(_stops[i].category),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Durağı kaldır',
                    onPressed: _busy
                        ? null
                        : () => setState(() => _stops.removeAt(i)),
                    icon: const Icon(Icons.close),
                  ),
                  ReorderableDragStartListener(
                    index: i,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_handle),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final actions = [
              OutlinedButton.icon(
                onPressed: _busy || _stops.length >= 12 ? null : _add,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Yer ara'),
              ),
              OutlinedButton.icon(
                onPressed: _busy || _stops.length >= 12 ? null : _fromMap,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Haritadan seç'),
              ),
            ];
            if (constraints.maxWidth < 340 ||
                MediaQuery.textScalerOf(context).scale(14) > 18)
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [actions[0], const SizedBox(height: 8), actions[1]],
              );
            return Row(
              children: [
                Expanded(child: actions[0]),
                const SizedBox(width: 8),
                Expanded(child: actions[1]),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'Kimler katılabilir?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in const [
              ('private', 'Davetliler'),
              ('followers', 'Takipçilerim'),
              ('public', 'Herkes'),
            ])
              ChoiceChip(
                label: Text(option.$2),
                selected: _visibility == option.$1,
                onSelected: _busy
                    ? null
                    : (_) => setState(() => _visibility = option.$1),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _visibility == 'public'
              ? 'Herkes katılım isteği gönderebilir. Tarih eklediğinde Etkinlikler’de de görünür.'
              : _visibility == 'followers'
              ? 'Takipçilerin katılım isteği gönderebilir. Arkadaşlarını ayrıca davet edebilirsin.'
              : 'Yalnızca davet ettiğin kişiler katılabilir.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.calendar_month_outlined,
              color: AppColors.cyan,
            ),
            title: const Text('Tarih ve saat'),
            subtitle: Text(
              _startAt == null
                  ? 'Henüz belirlenmedi · Ekle'
                  : '${_startAt!.day}.${_startAt!.month}.${_startAt!.year} · ${TimeOfDay.fromDateTime(_startAt!).format(context)}',
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _busy ? null : _pickDate,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Buluşma noktası',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  _meeting?.label ?? 'Henüz seçilmedi',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: _busy ? null : _pickMeeting,
                      icon: const Icon(Icons.search),
                      label: const Text('Mekân ara'),
                    ),
                    TextButton.icon(
                      onPressed: _busy ? null : _meetingMap,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Haritadan seç'),
                    ),
                  ],
                ),
                if (_meeting != null)
                  TextField(
                    controller: _meetingNote,
                    enabled: !_busy,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'Buluşma notu (isteğe bağlı)',
                      hintText: 'Örn. ana girişte',
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Arkadaşlarını rotayı oluşturduktan sonra davet edebilirsin.',
          style: TextStyle(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
