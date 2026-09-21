import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../services/route_draft_store.dart';
import '../widgets/route_stops_step.dart';
import 'travel_plan_invite_screen.dart';
import '../services/route_stop_order.dart';

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
import '../widgets/spot_image.dart';
import '../services/route_itinerary_service.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'travel_plan_detail_screen.dart';
import 'routes_hub_screen.dart';

class RouteCreateScreen extends StatefulWidget {
  const RouteCreateScreen({
    super.key,
    this.initialStops = const [],
    this.loadCatalog,
  });
  final List<PhotoSpot> initialStops;
  final Future<List<PhotoSpot>> Function(int)? loadCatalog;
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
  int _step = 0;
  Set<String> _invitees = {};
  String? _createdPlanId;
  bool _restoring = true, _completed = false;
  String? _draftUser;
  Timer? _draftTimer;
  Future<void> _draftWrites = Future.value();
  String _transport = 'Araç';
  String _visibility = 'private';
  bool _busy = false;
  DateTime? _startAt;
  EventLocationSelection? _meeting;
  final _meetingNote = TextEditingController();
  @override
  void initState() {
    super.initState();
    if (_stops.isNotEmpty) {
      _city.text = _stops.first.city;
      _title.text = '${_stops.first.city} gezisi';
    }
    try {
      _draftUser = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {}
    _city.addListener(_scheduleDraft);
    _title.addListener(_scheduleDraft);
    _meetingNote.addListener(_scheduleDraft);
    _restoreDraft();
    _refreshRoute();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    if (!_completed && !_restoring) _writeDraft();
    _city.dispose();
    _title.dispose();
    _meetingNote.dispose();
    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _scheduleDraft();
  }

  void _scheduleDraft() {
    if (_restoring || _completed || _draftUser == null) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), _writeDraft);
  }

  void _writeDraft() {
    final uid = _draftUser;
    if (uid == null || _completed || _restoring) return;
    final data = <String, dynamic>{
      'title': _title.text,
      'city': _city.text,
      'step': _step,
      'transport': _transport,
      'visibility': _visibility,
      'startAt': _startAt?.toIso8601String(),
      'invitees': _invitees.toList(),
      'createdPlanId': _createdPlanId,
      'meeting': _meeting == null
          ? null
          : {
              'label': _meeting!.label,
              'latitude': _meeting!.latitude,
              'longitude': _meeting!.longitude,
            },
      'meetingNote': _meetingNote.text,
      'stops': _stops.map(RouteDraftStore.encodeSpot).toList(),
    };
    _draftWrites = _draftWrites
        .then((_) => RouteDraftStore.write(uid, data))
        .catchError((Object _) {});
  }

  Future<void> _restoreDraft() async {
    try {
      final draft = _draftUser == null || widget.initialStops.isNotEmpty
          ? null
          : await RouteDraftStore.read(_draftUser!);
      if (!mounted) return;
      if (draft != null) {
        final stops = (draft['stops'] as List? ?? [])
            .map(
              (s) => RouteDraftStore.decodeSpot(Map<String, dynamic>.from(s)),
            )
            .take(12)
            .toList();
        _title.text = draft['title'] ?? '';
        _city.text = draft['city'] ?? '';
        _stops
          ..clear()
          ..addAll(stops);
        _transport =
            ['Araç', 'Yürüyüş', 'Bisiklet'].contains(draft['transport'])
            ? draft['transport']
            : 'Araç';
        _visibility =
            ['private', 'followers', 'public'].contains(draft['visibility'])
            ? draft['visibility']
            : 'private';
        _startAt = DateTime.tryParse(draft['startAt'] ?? '');
        _invitees = Set<String>.from(draft['invitees'] ?? []);
        _createdPlanId = draft['createdPlanId'];
        _meetingNote.text = draft['meetingNote'] ?? '';
        final meeting = draft['meeting'];
        if (meeting is Map)
          _meeting = EventLocationSelection(
            label: meeting['label'],
            latitude: (meeting['latitude'] as num).toDouble(),
            longitude: (meeting['longitude'] as num).toDouble(),
          );
        _step = ((draft['step'] as num?)?.toInt() ?? 0).clamp(0, 2);
        if (!turkeyCities.contains(_city.text)) _step = 0;
        if (_step == 2 && _stops.isEmpty) _step = 1;
        _refreshRoute();
      }
    } catch (_) {
      /* An invalid local draft must not block route creation. */
    }
    if (mounted) setState(() => _restoring = false);
  }

  Future<void> _newDraft() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni rota başlatılsın mı?'),
        content: const Text(
          'Bu cihazdaki taslak temizlenir. Oluşturduğun rotalar korunur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yeni rota'),
          ),
        ],
      ),
    );
    if (!mounted || discard != true) return;
    _draftTimer?.cancel();
    await _draftWrites;
    if (_draftUser != null) await RouteDraftStore.clear(_draftUser!);
    if (!mounted) return;
    setState(() {
      _title.clear();
      _city.clear();
      _meetingNote.clear();
      _stops.clear();
      _invitees.clear();
      _meeting = null;
      _startAt = null;
      _step = 0;
      _transport = 'Araç';
      _visibility = 'private';
      _createdPlanId = null;
      _completed = false;
      _refreshRoute();
    });
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startAt != null && _startAt!.isAfter(now) ? _startAt! : now,
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
    final selected = await showModalBottomSheet<List<PhotoSpot>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RouteStopPicker(
        city: _city.text.trim(),
        stops: _stops,
        multiple: true,
      ),
    );
    if (!mounted || selected == null || selected.isEmpty) return;
    setState(() {
      for (final spot in selected) {
        if (_stops.length < 12 && !_stops.any((s) => s.id == spot.id))
          _stops.add(spot);
      }
      if (_city.text.trim().isEmpty) _city.text = selected.first.city;
    });
    _refreshRoute();
  }

  void _smartSort() {
    if (_stops.length < 3 || _busy) return;
    final previous = List<PhotoSpot>.of(_stops);
    final sorted = smartOrderStops(_stops);
    setState(() {
      _stops
        ..clear()
        ..addAll(sorted);
    });
    _refreshRoute();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Başlangıç korundu, duraklar yakınlığa göre sıralandı.',
        ),
        action: SnackBarAction(
          label: 'Geri al',
          onPressed: () {
            if (!mounted ||
                _stops.length != sorted.length ||
                !_stops.asMap().entries.every(
                  (e) => e.value.id == sorted[e.key].id,
                ))
              return;
            setState(() {
              _stops
                ..clear()
                ..addAll(previous);
            });
            _refreshRoute();
          },
        ),
      ),
    );
  }

  void _addSpot(PhotoSpot spot) {
    if (_busy || _stops.any((s) => s.id == spot.id)) return;
    if (_stops.length >= 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rotaya en fazla 12 durak ekleyebilirsin.'),
        ),
      );
      return;
    }
    setState(() {
      _stops.add(spot);
      _refreshRoute();
    });
  }

  Future<void> _mapPoint(LatLng point) async {
    final name = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bu noktayı rotaya ekle'),
        content: TextField(
          controller: name,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Durak adı (isteğe bağlı)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, name.text.trim()),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    // The dialog's closing animation can still use its controller.
    Future<void>.delayed(const Duration(seconds: 1), name.dispose);
    if (!mounted || label == null) return;
    _addSpot(
      PhotoSpot(
        id: 'map:${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}',
        name: label.isEmpty ? 'Haritadan seçilen durak' : label,
        city: _city.text.trim(),
        latitude: point.latitude,
        longitude: point.longitude,
        rating: 0,
        bestTime: '',
        angle: '',
        imageUrl: '',
        category: 'Konum',
      ),
    );
  }

  Future<void> _pickInvitees() async {
    final ids = await Navigator.push<Set<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => TravelPlanInviteScreen(
          planId: '',
          planTitle: _title.text,
          selectionOnly: true,
          initialSelection: _invitees,
        ),
      ),
    );
    if (mounted && ids != null) setState(() => _invitees = ids);
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
    if (_startAt != null && !_startAt!.isAfter(DateTime.now()))
      throw Exception('İleri bir tarih ve saat seç.');
    final id =
        _createdPlanId ??
        await TravelPlanService.instance.create(
          title: _title.text.trim().isEmpty
              ? '$city gezisi'
              : _title.text.trim(),
          city: city,
          durationHours: 3,
          distanceKm: (_itinerary?.meters ?? 0) / 1000,
          travelMinutes: ((_itinerary?.seconds ?? 0) / 60).ceil(),
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
    _createdPlanId = id;
    _writeDraft();
    if (_visibility == 'private' && _invitees.isNotEmpty) {
      await TravelPlanService.instance.invite(
        planId: id,
        planTitle: _title.text,
        userIds: _invitees,
      );
    }
    final plan = await TravelPlanService.instance.read(id, preferCache: true);
    _completed = true;
    _draftTimer?.cancel();
    await _draftWrites;
    if (_draftUser != null) await RouteDraftStore.clear(_draftUser!);
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

  static const _stepTitles = [
    'Rotanı başlat',
    'Duraklarını ekle',
    'Gezini planla',
  ];
  void _back() {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (_createdPlanId != null) {
      Navigator.maybePop(context);
      return;
    }
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.maybePop(context);
    }
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      final city = _city.text.trim();
      if (!turkeyCities.contains(city)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listeden bir şehir seç.')),
        );
        return;
      }
      if (_title.text.trim().isEmpty) _title.text = '$city gezisi';
    }
    if (_step == 1 && _stops.isEmpty) return;
    setState(() => _step++);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && (_step == 0 || _createdPlanId != null),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_busy && _step > 0) _back();
    },
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: _busy ? null : _back,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(_stepTitles[_step]),
        actions: [
          IconButton(
            tooltip: 'Yeni taslak',
            onPressed: _busy || _restoring ? null : _newDraft,
            icon: const Icon(Icons.restart_alt),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_step + 1}/3',
                style: const TextStyle(color: AppColors.cyan, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_step == 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap:
                        _busy ||
                            _routing ||
                            _itinerary != null ||
                            _stops.length < 2
                        ? null
                        : () => setState(() {
                            _refreshRoute();
                          }),
                    child: Text(
                      '${_stops.length}/12 durak · ${_routing
                          ? 'Yol hesaplanıyor…'
                          : _itinerary != null
                          ? '${(_itinerary!.meters / 1000).toStringAsFixed(1)} km · ${(_itinerary!.seconds / 60).ceil()} dk yol'
                          : _stops.length < 2
                          ? 'Tahmin için iki durak ekle'
                          : 'Yol bilgisi alınamadı · Tekrar dene'}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  if (_step > 0) ...[
                    OutlinedButton(
                      onPressed: _busy || _createdPlanId != null ? null : _back,
                      child: const Text('Geri'),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [AppColors.blue, AppColors.violet],
                        ),
                      ),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: AppColors.surface,
                          minimumSize: const Size(0, 50),
                        ),
                        onPressed:
                            _busy || _restoring || (_step > 0 && _stops.isEmpty)
                            ? null
                            : _step == 2
                            ? _save
                            : _next,
                        child: Text(
                          _busy
                              ? 'Hazırlanıyor…'
                              : _step == 2
                              ? (_createdPlanId == null
                                    ? 'Rotayı oluştur'
                                    : 'Sonucu aç')
                              : 'Devam',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _restoring
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                LinearProgressIndicator(
                  value: (_step + 1) / 3,
                  minHeight: 3,
                  color: AppColors.cyan,
                  backgroundColor: AppColors.surface,
                ),
                Expanded(
                  child: AbsorbPointer(
                    absorbing: _busy || _createdPlanId != null,
                    child: _step == 0
                        ? ListView(
                            key: const ValueKey('basics'),
                            padding: const EdgeInsets.all(16),
                            children: [
                              TextField(
                                controller: _title,
                                enabled: !_busy,
                                maxLength: 80,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Rotana bir isim ver',
                                  counterText: '',
                                  suffixIcon: Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
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

                              LayoutBuilder(
                                builder: (context, constraints) {
                                  if (constraints.maxWidth < 340 ||
                                      MediaQuery.textScalerOf(context)
                                              .scale(14) >
                                          18) {
                                    return DropdownButtonFormField<String>(
                                      initialValue: _transport,
                                      decoration: const InputDecoration(
                                        labelText: 'Ulaşım',
                                      ),
                                      items: [
                                        for (final mode in [
                                          'Araç',
                                          'Yürüyüş',
                                          'Bisiklet',
                                        ])
                                          DropdownMenuItem(
                                            value: mode,
                                            child: Text(mode),
                                          ),
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
                                    style: const ButtonStyle(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    segments: [
                                      for (final mode in [
                                        'Araç',
                                        'Yürüyüş',
                                        'Bisiklet',
                                      ])
                                        ButtonSegment(
                                          value: mode,
                                          label: Text(mode),
                                          icon: Icon(
                                            routeTransportIcon(mode),
                                            size: 18,
                                          ),
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

                              const SizedBox(height: 20),
                              const Text(
                                'Önce şehrini ve nasıl gideceğini seç. Duraklarını sonraki adımda ekle.',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ],
                          )
                        : _step == 1
                        ? RouteStopsStep(
                            key: ValueKey(_city.text),
                            city: _city.text.trim(),
                            stops: _stops,
                            itinerary: _itinerary,
                            busy: _busy,
                            loadItems: widget.loadCatalog,
                            onAdd: _addSpot,
                            onRemove: (spot) {
                              if (_busy) return;
                              setState(() {
                                _stops.removeWhere((s) => s.id == spot.id);
                                _refreshRoute();
                              });
                            },
                            onMapTap: _mapPoint,
                            onSuggest: _suggest,
                            onSort: _smartSort,
                            onSearch: _add,
                            stopBuilder: _stopRow,
                            onReorder: (a, b) {
                              if (_busy) return;
                              setState(() {
                                if (b > a) b--;
                                _stops.insert(b, _stops.removeAt(a));
                                _refreshRoute();
                              });
                            },
                          )
                        : ListView(
                            key: const ValueKey('details'),
                            padding: const EdgeInsets.all(16),
                            children: [
                              Text(
                                _title.text,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${_city.text} · $_transport · ${_stops.length} durak',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Gezi ayrıntıları',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Material(
                                color: AppColors.surface,
                                clipBehavior: Clip.antiAlias,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    _detail(
                                      Icons.calendar_today_outlined,
                                      'Tarih ve saat',
                                      _startAt == null
                                          ? 'Daha sonra belirle'
                                          : '${_startAt!.day}.${_startAt!.month}.${_startAt!.year} · ${TimeOfDay.fromDateTime(_startAt!).format(context)}',
                                      _pickDate,
                                    ),
                                    const Divider(
                                      height: 1,
                                      indent: 14,
                                      endIndent: 14,
                                    ),
                                    _detail(
                                      Icons.location_on_outlined,
                                      'Buluşma noktası',
                                      _meeting?.label ?? 'Daha sonra belirle',
                                      _meetingSheet,
                                    ),
                                    const Divider(
                                      height: 1,
                                      indent: 14,
                                      endIndent: 14,
                                    ),
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
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),

                              if (_startAt != null)
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _startAt = null),
                                  child: const Text(
                                    'Tarihi daha sonra belirle',
                                  ),
                                ),
                              if (_visibility == 'private')
                                _detail(
                                  Icons.person_add_alt,
                                  'Davetlileri seç',
                                  _invitees.isEmpty
                                      ? 'Arkadaş seç · İsteğe bağlı'
                                      : '${_invitees.length} kişi seçildi',
                                  _pickInvitees,
                                ),
                              const Padding(
                                padding: EdgeInsets.only(top: 20),
                                child: Text(
                                  'Oluşturduktan sonra Plan, Sohbet ve Albüm ekranına geçeceksin.',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
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
                  child: stop.id.startsWith('map:')
                      ? _stopPlaceholder()
                      : SpotImage(spot: stop, width: 48, height: 48),
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
