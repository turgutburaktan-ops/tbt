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
import '../widgets/route_editor_map.dart';
import '../services/route_itinerary_service.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  final _title = TextEditingController();
  RouteItinerary? _itinerary;
  bool _routing = false;
  int _routeRequest = 0;
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
    _refreshRoute();
  }

  @override
  void dispose() {
    _city.dispose();
    _title.dispose();
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
        _refreshRoute();
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
    _refreshRoute();
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
        _refreshRoute();
      });
  });
  Future<void> _save() => _act(() async {
    final city = _city.text.trim().isEmpty
        ? _stops.first.city
        : _city.text.trim();
    final id = await TravelPlanService.instance.create(
      title: _title.text.trim().isEmpty ? '$city gezisi' : _title.text.trim(),
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
  // Request IDs keep a late response from an older order/mode out of the UI.
  Future<void> _refreshRoute() async {
    final request = ++_routeRequest;
    _itinerary = null;
    _routing = _stops.length > 1;
    if (!_routing) return;
    final route = await RouteItineraryService.instance.calculate(
      _stops.map((s) => LatLng(s.latitude, s.longitude)).toList(),
      _transport,
    );
    if (!mounted || request != _routeRequest) return;
    setState(() {
      _itinerary = route;
      _routing = false;
    });
  }

  Future<void> _visibilitySheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Kimler katılabilir?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            for (final option in const [
              ('private', 'Davetliler', 'Yalnızca davet ettiğin kişiler.'),
              (
                'followers',
                'Takipçilerim',
                'Takipçilerin katılım isteği gönderebilir.',
              ),
              (
                'public',
                'Herkes',
                'Tarih eklediğinde Etkinlikler’de de görünür.',
              ),
            ])
              ListTile(
                title: Text(option.$2),
                subtitle: Text(option.$3),
                trailing: Icon(
                  _visibility == option.$1
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: _visibility == option.$1
                      ? AppColors.blue
                      : AppColors.textMuted,
                ),
                onTap: () => Navigator.pop(context, option.$1),
              ),
          ],
        ),
      ),
    );
    if (mounted && result != null) setState(() => _visibility = result);
  }

  Future<void> _meetingSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Buluşma noktası',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            if (_meeting != null) ListTile(title: Text(_meeting!.label)),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Mekân ara'),
              onTap: () => Navigator.pop(context, 'search'),
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Haritadan seç'),
              onTap: () => Navigator.pop(context, 'map'),
            ),
            if (_meeting != null) ...[
              TextField(
                controller: _meetingNote,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Buluşma notu (isteğe bağlı)',
                  hintText: 'Örn. ana girişte',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Buluşma noktasını kaldır'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            ],
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'search') await _pickMeeting();
    if (action == 'map') await _meetingMap();
    if (action == 'remove')
      setState(() {
        _meeting = null;
        _meetingNote.clear();
      });
  }

  String get _audience => _visibility == 'public'
      ? 'Herkes'
      : _visibility == 'followers'
      ? 'Takipçilerim'
      : 'Davetliler';

  Widget _detail(
    IconData icon,
    String title,
    String value,
    VoidCallback action,
  ) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    leading: Icon(icon, color: AppColors.textMuted, size: 22),
    title: Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      value,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
    ),
    trailing: const Icon(
      Icons.chevron_right,
      color: AppColors.textMuted,
      size: 20,
    ),
    onTap: _busy ? null : action,
  );

  void _openMap() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Rota önizlemesi')),
        body: RouteEditorMap(
          stops: _stops,
          itinerary: _itinerary,
          interactive: true,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Rota oluştur'), centerTitle: false),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: _stops.isEmpty || _busy
                    ? null
                    : const LinearGradient(
                        colors: [AppColors.blue, AppColors.violet],
                      ),
              ),
              child: FilledButton(
                onPressed: _busy || _stops.isEmpty ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    Text(_busy ? 'Hazırlanıyor…' : 'Rotayı oluştur'),
                    if (!_busy)
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(Icons.arrow_forward, size: 20),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      children: [
        TextField(
          controller: _title,
          enabled: !_busy,
          maxLength: 80,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            hintText: 'Rotana bir isim ver',
            counterText: '',
            suffixIcon: Icon(Icons.edit_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 10),
        SearchableSelectionField(
          controller: _city,
          options: turkeyCities,
          labelText: 'İl seç',
          hintText: 'Örn. Elazığ',
          prefixIcon: Icons.location_on_outlined,
          enabled: !_busy,
          onSelected: (_) {
            FocusScope.of(context).unfocus();
            setState(() {});
          },
        ),
        const SizedBox(height: 14),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              SizedBox(
                height: _stops.isEmpty ? 136 : 188,
                child: _stops.isEmpty
                    ? _emptyMap()
                    : Stack(
                        children: [
                          Positioned.fill(
                            child: RouteEditorMap(
                              stops: _stops,
                              itinerary: _itinerary,
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: IconButton.filledTonal(
                              tooltip: 'Haritayı büyüt',
                              onPressed: _openMap,
                              icon: const Icon(Icons.open_in_full, size: 19),
                            ),
                          ),
                        ],
                      ),
              ),
              if (_stops.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_stops.length} durak',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _routing
                              ? 'Güzergâh hesaplanıyor…'
                              : _itinerary != null
                              ? '${(_itinerary!.meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km · ${(_itinerary!.seconds / 60).ceil()} dk yol'
                              : _stops.length < 2
                              ? 'Bir durak daha ekle'
                              : 'Yol bilgisi alınamadı',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      if (_itinerary != null)
                        const Text(
                          'Tahmini',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      if (!_routing && _stops.length > 1 && _itinerary == null)
                        IconButton(
                          tooltip: 'Yol bilgisini yeniden dene',
                          onPressed: () => setState(() {
                            _refreshRoute();
                          }),
                          icon: const Icon(Icons.refresh, size: 18),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 340 ||
                MediaQuery.textScalerOf(context).scale(14) > 18) {
              return DropdownButtonFormField<String>(
                initialValue: _transport,
                decoration: const InputDecoration(labelText: 'Ulaşım'),
                items: [
                  for (final mode in ['Araç', 'Yürüyüş', 'Bisiklet'])
                    DropdownMenuItem(value: mode, child: Text(mode)),
                ],
                onChanged: _busy
                    ? null
                    : (mode) {
                        if (mode != null)
                          setState(() {
                            _transport = mode;
                            _refreshRoute();
                          });
                      },
              );
            }
            return SegmentedButton<String>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
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
                  : (value) => setState(() {
                      _transport = value.first;
                      _refreshRoute();
                    }),
            );
          },
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Duraklar',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: _busy || _stops.length >= 12 ? null : _suggest,
              child: const Text('Bana rota öner'),
            ),
          ],
        ),
        if (_stops.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Gezilecek yer veya mekân ekleyerek başla.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
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
              _refreshRoute();
            });
          },
          itemBuilder: (_, i) => _stopRow(i),
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
                MediaQuery.textScalerOf(context).scale(14) > 18) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [actions[0], const SizedBox(height: 8), actions[1]],
              );
            }
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
          'Gezi ayrıntıları',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Material(
          color: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Column(
            children: [
              _detail(
                Icons.calendar_today_outlined,
                'Tarih ve saat',
                _startAt == null
                    ? 'Tarih ekle'
                    : '${_startAt!.day}.${_startAt!.month}.${_startAt!.year} · ${TimeOfDay.fromDateTime(_startAt!).format(context)}',
                _pickDate,
              ),
              const Divider(height: 1, indent: 14, endIndent: 14),
              _detail(
                Icons.location_on_outlined,
                'Buluşma noktası',
                _meeting?.label ?? 'Konum seç',
                _meetingSheet,
              ),
              const Divider(height: 1, indent: 14, endIndent: 14),
              _detail(
                Icons.people_outline,
                'Kimler katılabilir?',
                _audience,
                _visibilitySheet,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _visibility == 'public'
              ? (_startAt == null
                    ? 'Tarih eklediğinde Etkinlikler’de de görünür.'
                    : 'Etkinlikler’de de görünür.')
              : _visibility == 'followers'
              ? 'Takipçilerin katılım isteği gönderebilir.'
              : 'Yalnızca davet ettiğin kişiler katılabilir.',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        const Text(
          'Arkadaşlarını rotayı oluşturduktan sonra davet edebilirsin.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    ),
  );

  Widget _emptyMap() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.route_outlined, color: AppColors.blue, size: 32),
        const SizedBox(height: 10),
        const Text(
          'Rotan burada şekillenecek',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Durak ekledikçe haritada gör',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    ),
  );

  Widget _stopRow(int i) {
    final stop = _stops[i];
    final leg = _itinerary != null && i > 0 && i - 1 < _itinerary!.legs.length
        ? _itinerary!.legs[i - 1]
        : null;
    return Column(
      key: ValueKey(stop.id),
      children: [
        if (leg != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.more_vert,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Text(
                  leg.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: .16),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: stop.imageUrl.isEmpty
                      ? _stopPlaceholder()
                      : Image.network(
                          stop.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, stack) => _stopPlaceholder(),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      i == 0 ? 'Başlangıç' : stop.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_busy)
                ReorderableDragStartListener(
                  index: i,
                  child: Semantics(
                    label: 'Sıralamak için sürükle',
                    child: SizedBox(
                      width: 40,
                      height: 48,
                      child: Icon(
                        Icons.drag_handle,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Durağı kaldır',
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _stops.removeAt(i);
                        _refreshRoute();
                      }),
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stopPlaceholder() => const ColoredBox(
    color: AppColors.surfaceAlt,
    child: Icon(Icons.place_outlined, color: AppColors.textMuted, size: 22),
  );
}
