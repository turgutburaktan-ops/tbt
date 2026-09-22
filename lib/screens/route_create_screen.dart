import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/travel_plan.dart';
import 'package:geolocator/geolocator.dart';
import '../services/route_geometry.dart';
import '../widgets/route_editor_map.dart';
import '../widgets/route_design/route_design.dart';
import 'route_path_editor_screen.dart';
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
    this.existingPlan,
  });
  final List<PhotoSpot> initialStops;
  final TravelPlan? existingPlan;
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
  LatLng? _origin;
  String _originLabel = 'Başlangıç noktası seç';
  bool _manual = false, _roundTrip = false, _fromMap = true;
  final _description = TextEditingController();

  Set<String> _invitees = {};
  String? _createdPlanId;
  bool _restoring = true, _completed = false;
  String? _draftUser;
  Timer? _draftTimer;
  Future<void> _draftWrites = Future.value();
  String _transport = 'Araç';
  String _difficulty = '';
  bool _allowJoin = false;
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
    _description.addListener(_scheduleDraft);
    _meetingNote.addListener(_scheduleDraft);
    if (widget.existingPlan != null) {
      final p = widget.existingPlan!;
      _title.text = p.title;
      _city.text = p.city;
      _transport = p.transport;
      _visibility = p.visibility;
      _description.text = (p.dayPlan['description'] ?? '').toString();
      _manual = p.dayPlan['manual'] == true;
      _roundTrip = p.dayPlan['roundTrip'] == true;
      _difficulty = (p.dayPlan['difficulty'] ?? '').toString();
      _startAt = p.hasSchedule ? p.startAt : null;
      _allowJoin = p.joinEnabled;
      if (p.routeOrigin['latitude'] is num &&
          p.routeOrigin['longitude'] is num) {
        _origin = LatLng(
          (p.routeOrigin['latitude'] as num).toDouble(),
          (p.routeOrigin['longitude'] as num).toDouble(),
        );
        _originLabel = (p.routeOrigin['label'] ?? 'Başlangıç').toString();
      }
      _step = 1;
      _restoring = false;
    } else {
      _restoreDraft();
    }
    _refreshRoute();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    if (!_completed && !_restoring) _writeDraft();
    _description.dispose();
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
    if (_restoring ||
        _completed ||
        _draftUser == null ||
        widget.existingPlan != null)
      return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), _writeDraft);
  }

  void _writeDraft() {
    final uid = _draftUser;
    if (uid == null || _completed || _restoring || widget.existingPlan != null)
      return;
    final data = <String, dynamic>{
      'title': _title.text,
      'description': _description.text,
      'manual': _manual,
      'roundTrip': _roundTrip,
      'difficulty': _difficulty,
      'allowJoin': _allowJoin,
      'origin':
          _origin == null
              ? null
              : {
                'lat': _origin!.latitude,
                'lng': _origin!.longitude,
                'label': _originLabel,
              },
      'city': _city.text,
      'step': _step,
      'transport': _transport,
      'visibility': _visibility,
      'startAt': _startAt?.toIso8601String(),
      'invitees': _invitees.toList(),
      'createdPlanId': _createdPlanId,
      'meeting':
          _meeting == null
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
      final draft =
          _draftUser == null || widget.initialStops.isNotEmpty
              ? null
              : await RouteDraftStore.read(_draftUser!);
      if (!mounted) return;
      if (draft != null) {
        final stops =
            (draft['stops'] as List? ?? [])
                .map(
                  (s) =>
                      RouteDraftStore.decodeSpot(Map<String, dynamic>.from(s)),
                )
                .take(12)
                .toList();
        _title.text = draft['title'] ?? '';
        _description.text = draft['description'] ?? '';
        _difficulty = (draft['difficulty'] ?? '').toString();
        _allowJoin = draft['allowJoin'] == true;
        _manual = draft['manual'] == true;
        _roundTrip = draft['roundTrip'] == true;
        final origin = draft['origin'];
        if (origin is Map && origin['lat'] is num && origin['lng'] is num) {
          _origin = LatLng(
            (origin['lat'] as num).toDouble(),
            (origin['lng'] as num).toDouble(),
          );
          _originLabel = (origin['label'] ?? 'Başlangıç').toString();
        }
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
        _step = ((draft['step'] as num?)?.toInt() ?? 0).clamp(0, 3);
        if (!turkeyCities.contains(_city.text) &&
            _origin == null &&
            _stops.isEmpty)
          _step = 0;
        if (_step >= 2 && _stops.isEmpty) _step = 1;
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
      builder:
          (context) => AlertDialog(
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
      _origin = null;
      _originLabel = 'Başlangıç noktası seç';
      _manual = false;
      _roundTrip = false;
      _description.clear();
      _difficulty = '';
      _allowJoin = false;
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
      () =>
          _meeting = EventLocationSelection(
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
        builder:
            (_) => EventLocationPickerScreen(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final selected = await showModalBottomSheet<List<PhotoSpot>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => RouteStopPicker(
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
      builder:
          (context) => AlertDialog(
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
        id:
            'map:${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}',
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
        builder:
            (_) => TravelPlanInviteScreen(
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
    final city =
        _city.text.trim().isEmpty ? _stops.first.city : _city.text.trim();
    if (_startAt != null && !_startAt!.isAfter(DateTime.now()))
      throw Exception('İleri bir tarih ve saat seç.');
    if (_allowJoin && (_visibility == 'private' || _startAt == null)) {
      throw Exception(
        'Onayla katılım için bir tarih ve takipçilere ya da herkese açık görünürlük seç.',
      );
    }
    if (widget.existingPlan != null) {
      final old = widget.existingPlan!;
      await TravelPlanService.instance.updateDesignedRoute(old.id, {
        'title':
            _title.text.trim().isEmpty ? '$city rotası' : _title.text.trim(),
        'city': city,
        'transport': _transport,
        'spotIds': _stops.map((s) => s.id).toList(),
        'spotNames': _stops.map((s) => s.name).toList(),
        'stopSnapshots': _stops.map(RouteDraftStore.encodeSpot).toList(),
        'dayPlan': {
          ...RouteGeometry.encode(
            _itinerary,
            RouteGeometry.signature(
              _stops,
              _transport,
              origin: _origin,
              roundTrip: _roundTrip,
            ),
            manual: _manual,
            roundTrip: _roundTrip,
          ),
          'description': _description.text.trim(),
          if (_difficulty.isNotEmpty) 'difficulty': _difficulty,
        },
        'routeOrigin':
            _origin == null
                ? {}
                : {
                  'latitude': _origin!.latitude,
                  'longitude': _origin!.longitude,
                  'label': _originLabel,
                },
        'distanceKm': (_itinerary?.meters ?? 0) / 1000,
        'travelMinutes': ((_itinerary?.seconds ?? 0) / 60).ceil(),
        'visibility': _visibility,
        'isPublic': _visibility == 'public',
        'joinEnabled':
            _allowJoin && _visibility != 'private' && _startAt != null,
        'hasSchedule': _startAt != null,
        'startAt': Timestamp.fromDate(_startAt ?? old.startAt),
        if (_meeting != null)
          'meetingPoint': {
            'label': _meeting!.label,
            'latitude': _meeting!.latitude,
            'longitude': _meeting!.longitude,
            'note': _meetingNote.text.trim(),
          },
      });
      if (_invitees.isNotEmpty)
        await TravelPlanService.instance.invite(
          planId: old.id,
          planTitle: _title.text,
          userIds: _invitees,
        );
      _completed = true;
      if (mounted) Navigator.pop(context);
      return;
    }
    final id =
        _createdPlanId ??
        await TravelPlanService.instance.create(
          title:
              _title.text.trim().isEmpty ? '$city gezisi' : _title.text.trim(),
          city: city,
          durationHours: 3,
          distanceKm: (_itinerary?.meters ?? 0) / 1000,
          travelMinutes: ((_itinerary?.seconds ?? 0) / 60).ceil(),
          budget: 'Orta',
          transport: _transport,
          interests: [],
          spots: _stops,
          dayPlan: {
            ...RouteGeometry.encode(
              _itinerary,
              RouteGeometry.signature(
                _stops,
                _transport,
                origin: _origin,
                roundTrip: _roundTrip,
              ),
              manual: _manual,
              roundTrip: _roundTrip,
            ),
            'description': _description.text.trim(),
            if (_difficulty.isNotEmpty) 'difficulty': _difficulty,
          },
          routeOrigin:
              _origin == null
                  ? const {}
                  : {
                    'latitude': _origin!.latitude,
                    'longitude': _origin!.longitude,
                    'label': _originLabel,
                  },
          visibility: _visibility,
          allowJoinRequests: _allowJoin,
          startAt: _startAt,
          meetingPoint:
              _meeting == null
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
    if (_invitees.isNotEmpty) {
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
    final points = RouteGeometry.waypoints(
      _stops,
      origin: _origin,
      roundTrip: _roundTrip,
    );
    _routing = points.length > 1;
    if (!_routing) return;
    final route =
        _manual
            ? RouteGeometry.manual(points)
            : await RouteItineraryService.instance.calculate(
              points,
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
      builder:
          (context) => Padding(
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
                      color:
                          _visibility == option.$1
                              ? AppColors.cyan
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
      builder:
          (context) => Padding(
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

  String get _audience =>
      _visibility == 'public'
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
    'Yeni rota',
    'Rotam',
    'Rotayı incele',
    'Rotayı kaydet',
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
      if (!turkeyCities.contains(city) && _origin == null && _stops.isEmpty) {
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

  Future<void> _joinSheet() async {
    final value = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (c) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Davet ettiklerim'),
                onTap: () => Navigator.pop(c, false),
              ),
              ListTile(
                title: const Text('Onayla katılım'),
                subtitle: const Text(
                  'Takipçilere veya herkese açık, tarihli rotalarda.',
                ),
                onTap: () => Navigator.pop(c, true),
              ),
            ],
          ),
    );
    if (mounted && value != null) setState(() => _allowJoin = value);
  }

  Future<void> _chooseOrigin() async {
    final point = await Navigator.push<EventLocationSelection>(
      context,
      MaterialPageRoute(
        builder:
            (_) => EventLocationPickerScreen(
              city: _city.text.trim(),
              title: 'Başlangıç noktası seç',
              addressLabel: 'Başlangıç',
              initialLatitude: _origin?.latitude,
              initialLongitude: _origin?.longitude,
            ),
      ),
    );
    if (mounted && point != null)
      setState(() {
        _origin = LatLng(point.latitude, point.longitude);
        _originLabel = point.label;
        _refreshRoute();
      });
  }

  Future<void> _locateOrigin() async {
    await _act(() async {
      if (!await Geolocator.isLocationServiceEnabled())
        throw Exception('Konum hizmetini aç veya haritadan başlangıç seç.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        throw Exception(
          'Konum izni verilmedi. Haritadan başlangıç seçebilirsin.',
        );
      final point = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 15),
      );
      if (mounted)
        setState(() {
          _origin = LatLng(point.latitude, point.longitude);
          _originLabel = 'Konumum';
          _refreshRoute();
        });
    });
  }

  Future<void> _path() async {
    final result = await Navigator.push<RoutePathResult>(
      context,
      MaterialPageRoute(
        builder:
            (_) => RoutePathEditorScreen(
              stops: _stops,
              city: _city.text.trim(),
              mode: _transport,
              origin: _origin,
              manual: _manual,
              roundTrip: _roundTrip,
            ),
      ),
    );
    if (mounted && result != null)
      setState(() {
        _stops
          ..clear()
          ..addAll(result.stops);
        _manual = result.manual;
        _roundTrip = result.roundTrip;
        _refreshRoute();
      });
  }

  void _removeSpot(PhotoSpot spot, {VoidCallback? onUndo}) {
    if (_busy) return;
    final index = _stops.indexWhere((s) => s.id == spot.id);
    if (index < 0) return;
    setState(() {
      _stops.removeAt(index);
      _refreshRoute();
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${spot.name} kaldırıldı'),
          action: SnackBarAction(
            label: 'Geri al',
            onPressed: () {
              if (!mounted ||
                  _stops.length >= 12 ||
                  _stops.any((s) => s.id == spot.id))
                return;
              setState(() {
                _stops.insert(index.clamp(0, _stops.length), spot);
                _refreshRoute();
              });
              onUndo?.call();
            },
          ),
        ),
      );
  }

  Future<void> _places() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder:
            (c) => StatefulBuilder(
              builder:
                  (c, refresh) => Scaffold(
                    backgroundColor: AppColors.background,
                    appBar: AppBar(title: const Text('Durak ekle')),
                    body: RouteStopsStep(
                      city: _city.text.trim(),
                      stops: _stops,
                      itinerary: _itinerary,
                      busy: _busy,
                      loadItems: widget.loadCatalog,
                      onAdd: (spot) {
                        _addSpot(spot);
                        refresh(() {});
                      },
                      onRemove: (spot) {
                        _removeSpot(
                          spot,
                          onUndo: () {
                            if (c.mounted) refresh(() {});
                          },
                        );
                        refresh(() {});
                      },
                      onMapTap: (point) async {
                        await _mapPoint(point);
                        refresh(() {});
                      },
                      onSuggest: () async {
                        await _suggest();
                        refresh(() {});
                      },
                      onSort: () {
                        _smartSort();
                        refresh(() {});
                      },
                      onSearch: () async {
                        await _add();
                        refresh(() {});
                      },
                      stopBuilder: _stopRow,
                      onReorder: (a, b) {
                        setState(() {
                          if (b > a) b--;
                          _stops.insert(b, _stops.removeAt(a));
                          _refreshRoute();
                        });
                        refresh(() {});
                      },
                    ),
                    bottomNavigationBar: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: RouteAction(
                          label: 'Rotama dön · ${_stops.length} durak',
                          onPressed: () => Navigator.pop(c),
                        ),
                      ),
                    ),
                  ),
            ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _addChoice() async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (c) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Yer ara'),
                subtitle: const Text('Mekân ve gezi noktaları'),
                onTap: () => Navigator.pop(c, 'places'),
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('Haritadan seç'),
                subtitle: const Text(
                  'Kendi yolunu ve geçiş noktalarını oluştur',
                ),
                onTap: () => Navigator.pop(c, 'map'),
              ),
            ],
          ),
    );
    if (!mounted) return;
    if (mode == 'places') await _places();
    if (mode == 'map') await _path();
  }

  String get _summary =>
      _routing
          ? 'Güzergâh hesaplanıyor…'
          : _itinerary == null
          ? '${_stops.length} durak · Yol bilgisi henüz yok'
          : '${(_itinerary!.meters / 1000).toStringAsFixed(1)} km · ${_manual ? 'Elle çizilmiş' : '${(_itinerary!.seconds / 60).ceil()} dk yol'}';
  Widget _map({double height = 230}) => SizedBox(
    height: height,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned.fill(
            child: RouteEditorMap(
              stops: _stops,
              itinerary: _itinerary,
              center: _origin,
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: IconButton.filledTonal(
              tooltip: 'Haritayı büyüt',
              onPressed: _path,
              icon: const Icon(Icons.open_in_full),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _originRow() => RoutePanel(
    padding: EdgeInsets.zero,
    child: ListTile(
      leading: const Icon(Icons.my_location, color: AppColors.cyan),
      title: const Text(
        'Başlangıç',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      subtitle: Text(
        _origin == null && _stops.isNotEmpty ? _stops.first.name : _originLabel,
        style: const TextStyle(color: Colors.white),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: _chooseOrigin,
    ),
  );
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
          PopupMenuButton<String>(
            enabled: !_busy,
            onSelected: (v) {
              if (v == 'new') _newDraft();
              if (v == 'sort') _smartSort();
              if (v == 'suggest') _suggest();
            },
            itemBuilder:
                (_) => [
                  const PopupMenuItem(value: 'new', child: Text('Yeni taslak')),
                  if (_step == 1) ...[
                    const PopupMenuItem(
                      value: 'suggest',
                      child: Text('Bana rota öner'),
                    ),
                    PopupMenuItem(
                      value: 'sort',
                      enabled: _stops.length >= 3,
                      child: const Text('Akıllı sırala'),
                    ),
                  ],
                ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_step == 1 || _step == 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _summary,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
              RouteAction(
                label:
                    _busy
                        ? 'Hazırlanıyor…'
                        : _step == 0
                        ? 'Rotanı oluşturmaya başla'
                        : _step == 1
                        ? 'Rotayı incele'
                        : _step == 2
                        ? 'Devam'
                        : 'Rotayı kaydet',
                onPressed:
                    _busy ||
                            _restoring ||
                            (_step > 0 && (_stops.isEmpty || _routing))
                        ? null
                        : _step == 3
                        ? _save
                        : () async {
                          _next();
                          if (_step == 1 && _stops.isEmpty) {
                            if (_fromMap)
                              await _path();
                            else
                              await _places();
                          }
                        },
              ),
            ],
          ),
        ),
      ),
      body:
          _restoring
              ? const Center(child: CircularProgressIndicator())
              : AbsorbPointer(
                absorbing: _busy,
                child:
                    _step == 0
                        ? _basics()
                        : _step == 1
                        ? _editor()
                        : _step == 2
                        ? _review()
                        : _settings(),
              ),
    ),
  );
  Widget _basics() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Nasıl gitmek istersin?',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 18),
      RouteModePicker(
        value: _transport,
        onChanged:
            (v) => setState(() {
              _transport = v;
              _refreshRoute();
            }),
      ),
      const SizedBox(height: 20),
      _originRow(),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _locateOrigin,
          icon: const Icon(Icons.my_location, size: 18),
          label: const Text('Konumumu kullan'),
        ),
      ),
      SearchableSelectionField(
        controller: _city,
        options: turkeyCities,
        labelText: 'Bölge',
        hintText: 'Şehir seç',
        prefixIcon: Icons.location_on_outlined,
        onSelected: (_) => setState(() {}),
      ),
      const SizedBox(height: 24),
      for (final map in [true, false])
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: RoutePanel(
            padding: EdgeInsets.zero,
            child: RadioListTile<bool>(
              value: map,
              groupValue: _fromMap,
              onChanged: (v) => setState(() => _fromMap = v!),
              title: Text(
                map ? 'Haritada kendim oluşturayım' : 'Yer seçerek oluşturayım',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                map
                    ? 'Yolunu noktalar ekleyerek belirle.'
                    : 'Gezilecek yer ve mola noktaları ekle.',
              ),
            ),
          ),
        ),
      const Text(
        'İki yöntemi aynı rotada birlikte kullanabilirsin.',
        style: TextStyle(color: AppColors.textMuted),
      ),
    ],
  );
  Widget _editor() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      RouteModePicker(
        value: _transport,
        onChanged:
            (v) => setState(() {
              _transport = v;
              _refreshRoute();
            }),
      ),
      const SizedBox(height: 14),
      _map(),
      const SizedBox(height: 14),
      _originRow(),
      const SizedBox(height: 22),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Duraklarım',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '${_stops.length} durak',
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (_stops.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('İlk durağını ekle veya haritada kendi yolunu oluştur.'),
        ),
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: _stops.length,
        onReorder:
            (a, b) => setState(() {
              if (b > a) b--;
              _stops.insert(b, _stops.removeAt(a));
              _refreshRoute();
            }),
        itemBuilder: (_, i) => _stopRow(i),
      ),
      const SizedBox(height: 12),
      RouteAction(
        label: 'Durak veya geçiş noktası ekle',
        icon: Icons.add,
        outlined: true,
        onPressed: _addChoice,
      ),
    ],
  );
  Widget _review() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _map(height: 270),
      const SizedBox(height: 16),
      RoutePanel(
        child: Text(
          _summary,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(height: 16),
      if (_manual)
        const RoutePanel(
          child: Text(
            'Elle çizilmiş güzergâh\nYol uygunluğu doğrulanmadı; yol süresi hesaplanmaz.',
            style: TextStyle(color: AppColors.warning),
          ),
        ),
      if (!_manual && _itinerary == null)
        TextButton(
          onPressed:
              () => setState(() {
                _refreshRoute();
              }),
          child: const Text('Yol bilgisi alınamadı · Tekrar dene'),
        ),
      const SizedBox(height: 16),
      _originRow(),
      ListTile(
        leading: const Icon(Icons.flag_outlined),
        title: const Text('Bitiş'),
        subtitle: Text(
          _roundTrip
              ? 'Başlangıç noktası'
              : _stops.isEmpty
              ? '—'
              : _stops.last.name,
        ),
      ),
      RouteAction(
        label: 'Rotayı düzenle',
        outlined: true,
        onPressed: () => setState(() => _step = 1),
      ),
    ],
  );
  Widget _settings() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _map(height: 155),
      const SizedBox(height: 20),
      TextField(
        controller: _title,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Rota adı'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _description,
        maxLength: 500,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Kısa açıklama (isteğe bağlı)',
        ),
      ),
      const SizedBox(height: 16),
      RoutePanel(
        padding: EdgeInsets.zero,
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
            _detail(
              Icons.public,
              'Rotayı kimler görebilir?',
              _audience,
              _visibilitySheet,
            ),
            _detail(
              Icons.people_outline,
              'Kimler katılabilir?',
              _allowJoin ? 'Onayla katılım' : 'Davet ettiklerim',
              _joinSheet,
            ),
            _detail(
              Icons.place_outlined,
              'Buluşma noktası',
              _meeting?.label ?? 'Daha sonra belirle',
              _meetingSheet,
            ),
          ],
        ),
      ),
      if (_startAt != null)
        TextButton(
          onPressed: () => setState(() => _startAt = null),
          child: const Text('Tarihi daha sonra belirle'),
        ),
      _detail(
        Icons.person_add_alt,
        'Davetlileri seç',
        '${_invitees.length} kişi seçildi',
        _pickInvitees,
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _difficulty,
        decoration: const InputDecoration(labelText: 'Zorluk (isteğe bağlı)'),
        items: [
          for (final d in ['', 'Kolay', 'Orta', 'Zor'])
            DropdownMenuItem(
              value: d,
              child: Text(d.isEmpty ? 'Belirtilmedi' : d),
            ),
        ],
        onChanged: (v) => setState(() => _difficulty = v ?? ''),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Text(
          'Herkese açık rotalar Keşfet’te görünür.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ),
    ],
  );

  Widget _stopRow(int i) {
    final stop = _stops[i];
    final leg =
        _itinerary != null && i > 0 && i - 1 < _itinerary!.legs.length
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
                  _manual
                      ? '${(leg.meters / 1000).toStringAsFixed(1)} km · Elle çizilmiş'
                      : leg.label,
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
                  color: AppColors.cyan.withValues(alpha: .16),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: AppColors.cyan,
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
                  child:
                      stop.id.startsWith('map:')
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
                onPressed: _busy ? null : () => _removeSpot(stop),
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
