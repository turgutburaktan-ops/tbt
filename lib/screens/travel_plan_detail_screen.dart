import '../services/invite_link_service.dart';
import 'route_create_screen.dart';
import 'route_participants_screen.dart';
import 'route_path_editor_screen.dart';
import '../services/route_geometry.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../widgets/route_design/route_design.dart';
import '../widgets/firebase_media_image.dart';
import '../widgets/route_group_chat.dart';
import '../widgets/route_map_preview.dart';
import '../widgets/route_stop_picker.dart';
import '../services/user_facing_error.dart';
import 'routes_hub_screen.dart';
import 'travel_plan_invite_screen.dart';
import 'route_album_screen.dart';
import '../widgets/profile_name_link.dart';
import 'route_sharing_screen.dart';
import '../models/nearby_venue.dart';
import 'business_profile_screen.dart';
import '../widgets/tbt_dialog.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/travel_plan.dart';
import '../models/photo_spot.dart';
import '../services/travel_plan_collaboration_service.dart';
import '../services/travel_plan_service.dart';
import '../theme/app_theme.dart';
import 'event_location_picker_screen.dart';
import 'route_planner_screen.dart';

class TravelPlanDetailScreen extends StatefulWidget {
  final TravelPlan plan;

  const TravelPlanDetailScreen({super.key, required this.plan});

  @override
  State<TravelPlanDetailScreen> createState() => _TravelPlanDetailScreenState();
}

class _TravelPlanDetailScreenState extends State<TravelPlanDetailScreen> {
  late String _title = widget.plan.title;
  bool _savingOffline = false;

  TravelPlan? _current;
  String _legacyKey = '';
  List<Map<String, dynamic>>? _legacyStops;
  String? _legacyError;
  void _resolveLegacy() {
    final key = plan.spotIds.join('|');
    if (key == _legacyKey) return;
    _legacyKey = key;
    _legacyStops = null;
    _legacyError = null;
    TravelPlanService.instance
        .resolveSpots(plan)
        .then((spots) {
          if (!mounted || _legacyKey != key) return;
          setState(
            () =>
                _legacyStops =
                    spots
                        .map(
                          (s) => <String, dynamic>{
                            'id': s.id,
                            'name': s.name,
                            'city': s.city,
                            'latitude': s.latitude,
                            'longitude': s.longitude,
                            'imageUrl': s.imageUrl,
                            'category': s.category,
                          },
                        )
                        .toList(),
          );
        })
        .catchError((Object e) {
          if (mounted && _legacyKey == key)
            setState(() => _legacyError = userFacingError(e));
        });
  }

  TravelPlan get plan => _current ?? widget.plan;
  late final _stream =
      FirebaseFirestore.instance
          .collection('travel_plans')
          .doc(widget.plan.id)
          .snapshots();
  bool get _owned => FirebaseAuth.instance.currentUser?.uid == plan.ownerId;

  Future<void> _changeStart(DateTime current) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current.isBefore(now) ? now : current,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (start.isBefore(DateTime.now())) return;
    try {
      await TravelPlanService.instance.setOptions(plan.id, startAt: start);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Başlangıç saati güncellenemedi.')),
        );
    }
  }

  void _openVenueStop(Map<String, dynamic> stop) {
    final venue = stop['venue'];
    if (venue is Map)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => BusinessProfileScreen(
                venue: NearbyVenue.fromJson(Map<String, dynamic>.from(venue)),
              ),
        ),
      );
  }

  Future<void> _renamePlan() async {
    if (!_owned) return;
    final controller = TextEditingController(text: _title);
    final value = await showTbtDialog<String>(
      context: context,
      builder:
          (dialogContext) => TbtDialog(
            title: const Text('Rota adını değiştir'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Rota adı'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, controller.text),
                child: const Text('Kaydet'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty || !mounted) return;
    await TravelPlanService.instance.updateTitle(plan.id, value);
    if (mounted) setState(() => _title = value.trim());
  }

  Future<void> _pickMeetingPoint(Map<String, dynamic> current) async {
    final labelController = TextEditingController(
      text: (current['label'] ?? '').toString(),
    );
    final continueToMap = await showTbtDialog<bool>(
      context: context,
      builder:
          (dialogContext) => TbtDialog(
            title: const Text('Buluşma noktası'),
            content: TextField(
              controller: labelController,
              autofocus: true,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'Noktanın adı',
                hintText: 'Örn. Ayasofya ana giriş',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Haritada seç'),
              ),
            ],
          ),
    );
    final label = labelController.text.trim();
    labelController.dispose();
    if (continueToMap != true || !mounted) return;
    final selection = await Navigator.push<EventLocationSelection>(
      context,
      MaterialPageRoute(
        builder:
            (_) => EventLocationPickerScreen(
              city: plan.city,
              addressLabel: label.isEmpty ? 'Buluşma noktası' : label,
              initialLatitude: (current['latitude'] as num?)?.toDouble(),
              initialLongitude: (current['longitude'] as num?)?.toDouble(),
              title: 'Buluşma Noktasını Seç',
              instruction: 'Grubun buluşacağı tam noktaya dokun.',
            ),
      ),
    );
    if (selection == null) return;
    await TravelPlanCollaborationService.instance.setMeetingPoint(
      planId: plan.id,
      label: label.isEmpty ? selection.label : label,
      latitude: selection.latitude,
      longitude: selection.longitude,
      note: (current['note'] ?? '').toString(),
    );
  }

  Future<void> _openMeetingPoint(Map<String, dynamic> point) async {
    final latitude = (point['latitude'] as num?)?.toDouble();
    final longitude = (point['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return;
    await launchUrl(
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openRoute() async {
    final latest =
        await FirebaseFirestore.instance
            .collection('travel_plans')
            .doc(plan.id)
            .get();
    final current = TravelPlan.fromDoc(latest);
    final spots = await TravelPlanService.instance.resolveRouteSpots(current);
    if (!mounted) return;
    if (spots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rota durakları bulunamadı.')),
      );
      return;
    }
    if (current.ownerId == FirebaseAuth.instance.currentUser?.uid) {
      final editable = await TravelPlanService.instance.resolveSpots(current);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => RouteCreateScreen(
                existingPlan: current,
                initialStops: editable,
              ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => Scaffold(
                appBar: AppBar(title: Text(current.title)),
                body: RouteMapPreview(
                  height:
                      MediaQuery.sizeOf(context).height -
                      MediaQuery.paddingOf(context).vertical -
                      kToolbarHeight -
                      60,
                  interactive: true,
                  showTerrain: false,
                  stops: current.stopSnapshots,
                  transport: current.transport,
                  dayPlan: current.dayPlan,
                  origin: current.routeOrigin,
                  onOpen: () {},
                ),
              ),
        ),
      );
    }
  }

  Future<void> _share() async {
    final stops = plan.spotNames
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${entry.value}')
        .join('\n');
    await Share.share(
      '${plan.title}\n\n${plan.city} • ${plan.durationHours} saat • ${plan.transport}\n\n$stops\n\n${InviteLinkService.instance.routeUri(plan.id)}',
      subject: plan.title,
    );
  }

  Future<void> _saveOffline() async {
    if (_savingOffline) return;
    setState(() => _savingOffline = true);
    await TravelPlanCollaborationService.instance.saveOffline(plan);
    if (!mounted) return;
    setState(() => _savingOffline = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rota çevrimdışı kullanım için indirildi.')),
    );
  }

  Future<void> _showStop(Map<String, dynamic> stop) async {
    await showTbtDialog<void>(
      context: context,
      builder:
          (c) => TbtDialog(
            title: Text(stop['name']?.toString() ?? 'Durak'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((stop['imageUrl'] ?? '').toString().isNotEmpty)
                    Image.network(
                      stop['imageUrl'].toString(),
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => const Text('Fotoğraf yüklenemedi.'),
                    ),
                  Text((stop['description'] ?? '').toString()),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Kapat'),
              ),
            ],
          ),
    );
  }

  Future<void> _act(Future<void> Function() task) async {
    try {
      await task();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    }
  }

  Future<void> _addStop() => _act(() async {
    final spots = await TravelPlanService.instance.resolveSpots(plan);
    if (!mounted) return;
    final selected = await showModalBottomSheet<List<PhotoSpot>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => RouteStopPicker(city: plan.city, stops: spots, multiple: true),
    );
    if (selected == null || selected.isEmpty) return;
    if (_owned || plan.allowMemberEdits) {
      await TravelPlanService.instance.addStops(plan.id, selected);
    } else {
      for (final spot in selected) {
        await TravelPlanCollaborationService.instance.proposeStopIfAbsent(
          plan.id,
          spot.name,
          spotId: spot.id,
          latitude: spot.latitude,
          longitude: spot.longitude,
          city: spot.city,
        );
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Durak önerilerin sohbete eklendi.')),
        );
    }
  });
  Future<void> _options() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (c) => StatefulBuilder(
            builder:
                (c, refresh) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Rota ayarları',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Rota adını değiştir'),
                        onTap: () {
                          Navigator.pop(c);
                          _act(_renamePlan);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.calendar_month_outlined),
                        title: Text(
                          plan.hasSchedule ? routeDate(plan) : 'Tarih ekle',
                        ),
                        onTap: () {
                          Navigator.pop(c);
                          _act(() => _changeStart(plan.startAt));
                        },
                      ),
                      ListTile(title: const Text('Görünürlük ve katılım'),
                        trailing: const Icon(Icons.chevron_right), onTap: () {
                          Navigator.pop(c);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => RouteSharingScreen(routeId:plan.id,title:plan.title)));
                        }),
                      SwitchListTile(
                        title: const Text(
                          'Katılımcılar durakları düzenleyebilir',
                        ),
                        value: plan.allowMemberEdits,
                        onChanged: (v) async {
                          Navigator.pop(c);
                          await _act(
                            () => TravelPlanService.instance.setOptions(
                              plan.id,
                              allowMemberEdits: v,
                            ),
                          );
                        },
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(c);
                          _act(_saveOffline);
                        },
                        icon: const Icon(Icons.offline_pin_outlined),
                        label: const Text('Çevrimdışı kullanım için indir'),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: _stream,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return Scaffold(
          appBar: AppBar(title: const Text('Rota')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(userFacingError(snapshot.error!)),
            ),
          ),
        );
      if (snapshot.hasData && !snapshot.data!.exists) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Bu rota kaldırılmış.')),
        );
      }
      if (snapshot.hasData) _current = TravelPlan.fromDoc(snapshot.data!);
      _title = plan.title;
      final data = snapshot.data?.data() ?? <String, dynamic>{};
      final member = plan.memberIds.contains(
        FirebaseAuth.instance.currentUser?.uid,
      );
      if (plan.stopSnapshots.isEmpty && plan.spotIds.isNotEmpty)
        _resolveLegacy();
      final stops =
          plan.stopSnapshots.isNotEmpty
              ? plan.stopSnapshots
              : _legacyStops ?? <Map<String, dynamic>>[];
      final point = Map<String, dynamic>.from(
        data['meetingPoint'] as Map? ?? {},
      );
      return DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              plan.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'settings') _options();
                  if (v == 'share') _act(_share);
                  if (v == 'save')
                    _act(
                      () => TravelPlanService.instance.bookmark(plan.id, true),
                    );
                  if (v == 'copy')
                    _act(() async {
                      final id = await TravelPlanService.instance.copyPlan(
                        plan,
                      );
                      final copied = await TravelPlanService.instance.read(id);
                      if (mounted)
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => TravelPlanDetailScreen(plan: copied),
                          ),
                        );
                    });
                },
                itemBuilder:
                    (_) => [
                      if (_owned)
                        const PopupMenuItem(
                          value: 'settings',
                          child: Text('Rota ayarları'),
                        ),
                      const PopupMenuItem(
                        value: 'save',
                        child: Text('Rotayı kaydet'),
                      ),
                      const PopupMenuItem(
                        value: 'copy',
                        child: Text('Kendi planıma kopyala'),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: Text('Paylaş'),
                      ),
                    ],
              ),
            ],
          ),
          body: Column(
            children: [
              const _RouteTabBar(),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (stops.any(
                          (s) => (s['imageUrl'] ?? '').toString().isNotEmpty,
                        ))
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              height: 180,
                              child: FirebaseMediaImage(
                                imageUrl:
                                    stops
                                        .firstWhere(
                                          (s) =>
                                              (s['imageUrl'] ?? '')
                                                  .toString()
                                                  .isNotEmpty,
                                        )['imageUrl']
                                        .toString(),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          plan.title,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              routeTransportIcon(plan.transport),
                              color: AppColors.cyan,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${plan.transport}${plan.distanceKm > 0 ? ' · ${plan.distanceKm.toStringAsFixed(1)} km' : ''}${plan.travelMinutes > 0 ? ' · ${plan.travelMinutes} dk' : ''}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if ((plan.dayPlan['description'] ?? '')
                            .toString()
                            .isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(plan.dayPlan['description'].toString()),
                          ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.calendar_today_outlined,
                            size: 20,
                          ),
                          title: Text(
                            plan.hasSchedule
                                ? routeDate(plan)
                                : 'Tarih belirlenmedi',
                          ),
                          onTap:
                              _owned
                                  ? () => _act(() => _changeStart(plan.startAt))
                                  : null,
                        ),
                        if (point.isNotEmpty || _owned)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.place_outlined),
                            title: Text(
                              (point['label'] ?? 'Buluşma noktası ekle')
                                  .toString(),
                            ),
                            onTap:
                                _owned
                                    ? () => _act(() => _pickMeetingPoint(point))
                                    : () =>
                                        _act(() => _openMeetingPoint(point)),
                          ),
                        RouteMapPreview(
                          stops: stops,
                          transport: plan.transport,
                          dayPlan: plan.dayPlan,
                          origin: plan.routeOrigin,
                          onOpen: () => _act(_openRoute),
                        ),
                        const SizedBox(height: 14),
                        InkWell(
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) =>
                                          RouteParticipantsScreen(plan: plan),
                                ),
                              ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: RouteMemberRow(ids: plan.memberIds),
                                ),
                                const Text(
                                  'Tümünü gör',
                                  style: TextStyle(color: AppColors.cyan),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                        if (plan.stopSnapshots.isEmpty && _legacyStops == null)
                          _legacyError == null
                              ? const LinearProgressIndicator()
                              : TextButton(
                                onPressed:
                                    () => setState(() => _legacyKey = ''),
                                child: Text(_legacyError!),
                              ),
                        if (!_owned)
                          RouteParticipation(
                            routeId: plan.id,
                            data: data,
                            showSettings: false,
                          ),

                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: stops.length,
                          onReorder: (a, b) {
                            if (!member || (!_owned && !plan.allowMemberEdits))
                              return;
                            if (b > a) b--;
                            final next = [...stops];
                            next.insert(b, next.removeAt(a));
                            _act(
                              () => TravelPlanService.instance.updateStops(
                                plan.id,
                                next,
                              ),
                            );
                          },
                          itemBuilder:
                              (_, i) => Card(
                                key: ValueKey('${stops[i]['id']}_$i'),
                                color: AppColors.surface,
                                child: ListTile(
                                  leading: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: AppColors.onPrimary,
                                        child: Text(
                                          '${i + 1}',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      if ((stops[i]['imageUrl'] ?? '')
                                          .toString()
                                          .isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: SizedBox(
                                            width: 44,
                                            height: 48,
                                            child: FirebaseMediaImage(
                                              imageUrl:
                                                  (stops[i]['imageUrl'] ?? '')
                                                      .toString(),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  title: Text(
                                    '${stops[i]['name']}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${stops[i]['category'] ?? 'Durak'}',
                                  ),
                                  onTap:
                                      () =>
                                          stops[i]['venue'] is Map
                                              ? _openVenueStop(stops[i])
                                              : _showStop(stops[i]),
                                  trailing:
                                      member &&
                                              (_owned || plan.allowMemberEdits)
                                          ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                tooltip: 'Durağı kaldır',
                                                onPressed:
                                                    stops.length > 1
                                                        ? () => _act(
                                                          () =>
                                                              TravelPlanService
                                                                  .instance
                                                                  .updateStops(
                                                                    plan.id,
                                                                    [
                                                                      ...stops,
                                                                    ]..removeAt(
                                                                      i,
                                                                    ),
                                                                  ),
                                                        )
                                                        : null,
                                                icon: const Icon(
                                                  Icons.close,
                                                  size: 18,
                                                ),
                                              ),
                                              ReorderableDragStartListener(
                                                index: i,
                                                child: const Padding(
                                                  padding: EdgeInsets.all(8),
                                                  child: Icon(
                                                    Icons.drag_handle,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                          : null,
                                ),
                              ),
                        ),
                        if (member)
                          OutlinedButton.icon(
                            onPressed: stops.length < 12 ? _addStop : null,
                            icon: const Icon(Icons.add),
                            label: Text(
                              _owned || plan.allowMemberEdits
                                  ? 'Durak ekle'
                                  : 'Durak öner',
                            ),
                          ),
                        const SizedBox(height: 14),
                        if (_owned && plan.status != 'completed')
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                            ),
                            onPressed:
                                () => _act(
                                  () => TravelPlanService.instance.setOptions(
                                    plan.id,
                                    status:
                                        plan.status == 'active'
                                            ? 'completed'
                                            : 'active',
                                  ),
                                ),
                            icon: Icon(
                              plan.status == 'active'
                                  ? Icons.check
                                  : Icons.play_arrow,
                            ),
                            label: Text(
                              plan.status == 'active'
                                  ? 'Geziyi bitir'
                                  : 'Geziyi başlat',
                            ),
                          ),
                        if (plan.status == 'completed')
                          const ListTile(
                            leading: Icon(
                              Icons.check_circle_outline,
                              color: AppColors.cyan,
                            ),
                            title: Text('Gezi tamamlandı'),
                            subtitle: Text('Anılarınız Albüm sekmesinde.'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => _act(_openRoute),
                          icon: const Icon(Icons.directions_outlined),
                          label: const Text('Yol tarifi'),
                        ),
                        if (member)
                          TextButton(
                            onPressed:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _LiveTripScreen(plan: plan),
                                  ),
                                ),
                            child: const Text('Gezi durumunu paylaş'),
                          ),
                      ],
                    ),
                    member
                        ? RouteGroupChat(plan: plan)
                        : const _PrivateRouteTab(),
                    member
                        ? RouteAlbumScreen(plan: plan)
                        : const _PrivateRouteTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PrivateRouteTab extends StatelessWidget {
  const _PrivateRouteTab();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 36),
          SizedBox(height: 12),
          Text(
            'Bu alan yalnızca rota katılımcılarına açık.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _RouteTabBar extends StatelessWidget {
  const _RouteTabBar();
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.background,
    child: TabBar(
      onTap: (_) => FocusScope.of(context).unfocus(),
      tabs: const [Tab(text: 'Plan'), Tab(text: 'Sohbet'), Tab(text: 'Albüm')],
    ),
  );
}

class _LiveTripScreen extends StatefulWidget {
  final TravelPlan plan;
  const _LiveTripScreen({required this.plan});

  @override
  State<_LiveTripScreen> createState() => _LiveTripScreenState();
}

class _LiveTripScreenState extends State<_LiveTripScreen> {
  int _index = 0;

  Future<void> _update(bool active) async {
    Position? position;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
      }
    } catch (_) {}
    await TravelPlanCollaborationService.instance.setLiveState(
      planId: widget.plan.id,
      stopIndex: _index,
      stopName: widget.plan.spotNames[_index],
      active: active,
      latitude: position?.latitude,
      longitude: position?.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stops = widget.plan.spotNames;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Canlı Gezi')),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            LinearProgressIndicator(value: (_index + 1) / stops.length),
            const SizedBox(height: 28),
            const Text(
              'ŞU ANKİ DURAK',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Text(
              stops[_index],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text('${_index + 1} / ${stops.length}'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _update(true),
              icon: const Icon(Icons.location_on_rounded),
              label: const Text('Buradayım'),
            ),
            const SizedBox(height: 8),
            if (_index < stops.length - 1)
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _index++);
                  _update(true);
                },
                icon: const Icon(Icons.skip_next_rounded),
                label: const Text('Sonraki Durağa Geç'),
              ),
            const SizedBox(height: 26),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Gruptakiler', style: _titleStyle),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: TravelPlanCollaborationService.instance.liveStates(
                  widget.plan.id,
                ),
                builder: (_, snapshot) {
                  final docs = snapshot.data?.docs ?? const [];
                  return ListView(
                    children:
                        docs.map((doc) {
                          final data = doc.data();
                          final latitude =
                              (data['latitude'] as num?)?.toDouble();
                          final longitude =
                              (data['longitude'] as num?)?.toDouble();
                          return ListTile(
                            leading: Icon(
                              data['active'] == true
                                  ? Icons.location_on_rounded
                                  : Icons.location_off_outlined,
                            ),
                            title: ProfileNameLink(
                              userId: doc.id,
                              compact: true,
                              child: Text(
                                (data['userName'] ?? 'TBT kullanıcısı')
                                    .toString(),
                              ),
                            ),
                            subtitle: Text((data['stopName'] ?? '').toString()),
                            trailing:
                                latitude == null || longitude == null
                                    ? null
                                    : IconButton(
                                      tooltip: 'Haritada gör',
                                      onPressed:
                                          () => launchUrl(
                                            Uri.parse(
                                              'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
                                            ),
                                            mode:
                                                LaunchMode.externalApplication,
                                          ),
                                      icon: const Icon(Icons.map_outlined),
                                    ),
                          );
                        }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _titleStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w900);
