import 'package:flutter/material.dart';
import '../models/travel_plan.dart';
import '../models/route_access.dart';
import '../services/travel_plan_service.dart';
import '../services/route_community.dart';
import '../services/user_facing_error.dart';
import '../widgets/route_access_settings.dart';
import '../theme/app_theme.dart';
import 'event_location_picker_screen.dart';
import 'travel_plan_invite_screen.dart';
import 'travel_plan_detail_screen.dart';

/// A template is only read here; a new personal event is written on confirmation.
class ReadyRouteEventScreen extends StatefulWidget {
  const ReadyRouteEventScreen({super.key, required this.plan});
  final TravelPlan plan;
  @override
  State<ReadyRouteEventScreen> createState() => _ReadyRouteEventScreenState();
}

class _ReadyRouteEventScreenState extends State<ReadyRouteEventScreen> {
  late final _title = TextEditingController(text: widget.plan.title);
  DateTime? _date;
  EventLocationSelection? _meeting;
  RouteAccess _access = const RouteAccess(enabled: true);
  Set<String> _invitees = {};
  bool _busy = false;
  String? _createdId;

  @override
  void dispose() { _title.dispose(); super.dispose(); }

  Future<DateTime?> _pickDate() async {
    final now = DateTime.now();
    final day = await showDatePicker(context: context,
      initialDate: _date != null && _date!.isAfter(now) ? _date! : now,
      firstDate: now, lastDate: now.add(const Duration(days: 730)));
    if (!mounted || day == null) return _date;
    final time = await showTimePicker(context: context,
      initialTime: TimeOfDay.fromDateTime(_date ?? now.add(const Duration(hours: 1))));
    if (!mounted || time == null) return _date;
    final selected = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (!selected.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İleri bir tarih ve saat seç.')));
      return _date;
    }
    setState(() => _date = selected);
    return selected;
  }

  Future<void> _pickMeeting() async {
    final first = widget.plan.stopSnapshots.firstOrNull;
    final point = await Navigator.push<EventLocationSelection>(context, MaterialPageRoute(builder: (_) =>
      EventLocationPickerScreen(city: widget.plan.city, addressLabel: 'Buluşma noktası',
        title: 'Buluşma noktası seç',
        initialLatitude: _meeting?.latitude ?? (first?['latitude'] as num?)?.toDouble(),
        initialLongitude: _meeting?.longitude ?? (first?['longitude'] as num?)?.toDouble())));
    if (mounted && point != null) setState(() => _meeting = point);
  }

  Future<void> _pickInvitees() async {
    final result = await Navigator.push<Set<String>>(context, MaterialPageRoute(builder: (_) =>
      TravelPlanInviteScreen(planId: '', planTitle: _title.text,
        selectionOnly: true, initialSelection: _invitees)));
    if (mounted && result != null) setState(() => _invitees = result);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_createdId == null) {
        if (_title.text.trim().isEmpty) throw Exception('Etkinlik adını yaz.');
        if (_date == null || !_date!.isAfter(DateTime.now())) throw Exception('İleri bir tarih ve saat seç.');
        if (_meeting == null) throw Exception('Buluşma noktasını seç.');
        final error = _access.validate(_date);
        if (error != null) throw Exception(error);
        final service = TravelPlanService.instance;
        final source = await service.read(widget.plan.id);
        final stops = await service.resolveSpots(source);
        if (stops.isEmpty) throw Exception('Rotanın durakları yüklenemedi.');
        _createdId = await service.create(
          title: _title.text.trim(), city: source.city, durationHours: source.durationHours,
          budget: source.budget, transport: source.transport, interests: source.interests,
          spots: stops, stopDetails: source.stopSnapshots,
          dayPlan: copyRouteDayPlan(source.dayPlan), routeOrigin: source.routeOrigin,
          distanceKm: source.distanceKm, travelMinutes: source.travelMinutes,
          startAt: _date, visibility: _access.visibility,
          discoverPublished: _access.visibility == 'public',
          allowJoinRequests: _access.enabled, joinAudience: _access.audience,
          joinRequiresApproval: _access.approval,
          meetingPoint: {'label': _meeting!.label, 'latitude': _meeting!.latitude, 'longitude': _meeting!.longitude});
      }
      final service = TravelPlanService.instance;
      // Retain the new ID if inviting or navigation fails, so retry cannot create duplicates.
      if (_invitees.isNotEmpty) await service.invite(planId: _createdId!, planTitle: _title.text, userIds: _invitees);
      final created = await service.read(_createdId!, preferCache: true);
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TravelPlanDetailScreen(plan: created)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Etkinlik oluştur')),
      body: AbsorbPointer(absorbing: _busy || _createdId != null,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(widget.plan.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Hazır rotanın durakları, fotoğrafı ve güzergâhı etkinliğine aktarılır.', style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 20),
          TextField(controller: _title, maxLength: 80, decoration: const InputDecoration(labelText: 'Etkinlik adı')),
          ListTile(leading: const Icon(Icons.calendar_today_outlined), title: const Text('Tarih ve saat'),
            subtitle: Text(_date == null ? 'Tarih ve saat seç' : '${_date!.day}.${_date!.month}.${_date!.year} · ${TimeOfDay.fromDateTime(_date!).format(context)}'),
            trailing: const Icon(Icons.chevron_right), onTap: _pickDate),
          ListTile(leading: const Icon(Icons.place_outlined), title: const Text('Buluşma noktası'),
            subtitle: Text(_meeting?.label ?? 'Haritadan seç'), trailing: const Icon(Icons.chevron_right), onTap: _pickMeeting),
          RouteAccessSettings(value: _access, startAt: _date, pickDate: _pickDate,
            onChanged: (v) => setState(() => _access = v)),
          ListTile(leading: const Icon(Icons.person_add_alt), title: const Text('Davetlileri seç'),
            subtitle: Text('${_invitees.length} kişi seçildi'), trailing: const Icon(Icons.chevron_right), onTap: _pickInvitees),
        ])),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(16),
        child: FilledButton.icon(onPressed: _busy ? null : _save,
          icon: const Icon(Icons.event_available_outlined),
          label: Text(_busy ? 'Oluşturuluyor…' : _createdId != null ? 'Etkinliğe devam et' : 'Etkinliği oluştur')))),
    ));
}
