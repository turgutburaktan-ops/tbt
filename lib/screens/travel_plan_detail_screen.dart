import '../widgets/route_polls.dart';
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
import '../services/spot_repository.dart';
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
  late bool _public = widget.plan.isPublic;
  late String _title = widget.plan.title;
  bool _savingOffline = false;

  TravelPlan? _current;
  TravelPlan get plan => _current ?? widget.plan;
  late final _stream = FirebaseFirestore.instance
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
      await FirebaseFirestore.instance
          .collection('travel_plans')
          .doc(plan.id)
          .update({
            'startAt': Timestamp.fromDate(start),
            'hasSchedule': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
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
          builder: (_) => BusinessProfileScreen(
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
      builder: (dialogContext) => TbtDialog(
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
      builder: (dialogContext) => TbtDialog(
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
        builder: (_) => EventLocationPickerScreen(
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

  Future<void> _removeMeetingPoint() async {
    await TravelPlanCollaborationService.instance.clearMeetingPoint(plan.id);
  }

  Future<void> _openRoute() async {
    final latest = await FirebaseFirestore.instance
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoutePlannerScreen(
          routeId: current.ownerId == FirebaseAuth.instance.currentUser?.uid
              ? current.id
              : null,
          initialTitle: current.title,
          city: current.city,
          durationHours: current.durationHours,
          budget: current.budget,
          interests: current.interests,
          initialSpots: spots,
          initialUseCurrentLocation: false,
          initialTransport: current.transport,
        ),
      ),
    );
  }

  Future<void> _share() async {
    final stops = plan.spotNames
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${entry.value}')
        .join('\n');
    await Share.share(
      '${plan.title}\n\n${plan.city} • ${plan.durationHours} saat • ${plan.transport}\n\n$stops\n\nTBT ile hazırlandı.',
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
      builder: (c) => TbtDialog(
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
                  errorBuilder: (_, __, ___) =>
                      const Text('Fotoğraf yüklenemedi.'),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(e))));
    }
  }

  Future<void> _addStop() => _act(() async {
    final spots = await TravelPlanService.instance.resolveRouteSpots(plan);
    if (!mounted) return;
    final spot = await showModalBottomSheet<PhotoSpot>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RouteStopPicker(city: plan.city, stops: spots),
    );
    if (spot == null) return;
    if (_owned || plan.allowMemberEdits) {
      await TravelPlanService.instance.addStop(plan.id, spot);
    } else {
      await TravelPlanCollaborationService.instance.propose(
        plan.id,
        spot.name,
        spotId: spot.id,
        latitude: spot.latitude,
        longitude: spot.longitude,
        city: spot.city,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Durak önerin sohbete eklendi.')),
        );
    }
  });
  Future<void> _options() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => StatefulBuilder(
        builder: (c, refresh) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Rota ayarları',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                title: Text(plan.hasSchedule ? routeDate(plan) : 'Tarih ekle'),
                onTap: () {
                  Navigator.pop(c);
                  _act(() => _changeStart(plan.startAt));
                },
              ),
              const Text(
                'Kimler görebilir?',
                style: TextStyle(color: AppColors.textMuted),
              ),
              for (final v in [
                ('private', 'Davetliler'),
                ('followers', 'Takipçilerim'),
                ('public', 'Herkes'),
              ])
                RadioListTile<String>(
                  value: v.$1,
                  groupValue: plan.visibility,
                  title: Text(v.$2),
                  onChanged: (_) async {
                    Navigator.pop(c);
                    await _act(
                      () => TravelPlanService.instance.setOptions(
                        plan.id,
                        visibility: v.$1,
                      ),
                    );
                  },
                ),
              SwitchListTile(
                title: const Text('Katılımcılar durakları düzenleyebilir'),
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
      if (!snapshot.hasData)
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()),
        );
      if (!snapshot.data!.exists)
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Bu rota kaldırılmış.')),
        );
      _current = TravelPlan.fromDoc(snapshot.data!);
      _title = plan.title;
      _public = plan.isPublic;
      final data = snapshot.data!.data()!;
      final member = plan.memberIds.contains(
        FirebaseAuth.instance.currentUser?.uid,
      );
      final stops = plan.stopSnapshots;
      final point = Map<String, dynamic>.from(
        data['meetingPoint'] as Map? ?? {},
      );
      return DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: const Color(0xFF07080B),
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
                            builder: (_) =>
                                TravelPlanDetailScreen(plan: copied),
                          ),
                        );
                    });
                },
                itemBuilder: (_) => [
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
                  const PopupMenuItem(value: 'share', child: Text('Paylaş')),
                ],
              ),
            ],
          ),
          body: NestedScrollView(
            headerSliverBuilder: (_, inner) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        plan.title,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _owned
                            ? () => _act(() => _changeStart(plan.startAt))
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            '${routeDate(plan)} · ${plan.city}',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final mode in ['Araç', 'Yürüyüş', 'Bisiklet'])
                            ChoiceChip(
                              avatar: Icon(routeTransportIcon(mode), size: 18),
                              label: Text(mode),
                              selected: plan.transport == mode,
                              onSelected: _owned
                                  ? (_) => _act(
                                      () => TravelPlanService.instance
                                          .setOptions(plan.id, transport: mode),
                                    )
                                  : null,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      RouteMapPreview(
                        stops: stops,
                        transport: plan.transport,
                        onOpen: () => _act(_openRoute),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: RouteMemberRow(ids: plan.memberIds)),
                          if (_owned)
                            OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TravelPlanInviteScreen(
                                    planId: plan.id,
                                    planTitle: plan.title,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Davet et'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _owned ? _options : null,
                        child: Row(
                          children: [
                            Icon(
                              plan.isPublic ? Icons.public : Icons.lock_outline,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                plan.isPublic
                                    ? (plan.hasSchedule
                                          ? 'Herkese açık · Etkinliklerde görünür'
                                          : 'Herkese açık')
                                    : plan.visibility == 'followers'
                                    ? 'Takipçilerime açık'
                                    : 'Davetlilere özel',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(pinned: true, delegate: _RouteTabs()),
            ],
            body: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    RouteParticipation(
                      routeId: plan.id,
                      data: data,
                      showSettings: false,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.place_outlined),
                      title: Text(
                        (point['label'] ?? 'Buluşma noktası ekle').toString(),
                      ),
                      onTap: member
                          ? () => _act(() => _pickMeetingPoint(point))
                          : point.isNotEmpty
                          ? () => _act(() => _openMeetingPoint(point))
                          : null,
                      trailing: point.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.directions_outlined),
                              onPressed: () =>
                                  _act(() => _openMeetingPoint(point)),
                            )
                          : null,
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
                      itemBuilder: (_, i) => Card(
                        key: ValueKey('${stops[i]['id']}_$i'),
                        color: const Color(0xFF12151C),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.cyan,
                            foregroundColor: Colors.black,
                            child: Text('${i + 1}'),
                          ),
                          title: Text('${stops[i]['name']}'),
                          subtitle: Text('${stops[i]['category'] ?? 'Durak'}'),
                          onTap: () => stops[i]['venue'] is Map
                              ? _openVenueStop(stops[i])
                              : _showStop(stops[i]),
                          trailing: member && (_owned || plan.allowMemberEdits)
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Durağı kaldır',
                                      onPressed: stops.length > 1
                                          ? () => _act(
                                              () => TravelPlanService.instance
                                                  .updateStops(
                                                    plan.id,
                                                    [...stops]..removeAt(i),
                                                  ),
                                            )
                                          : null,
                                      icon: const Icon(Icons.close, size: 18),
                                    ),
                                    ReorderableDragStartListener(
                                      index: i,
                                      child: const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Icon(Icons.drag_handle),
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
                          backgroundColor: AppColors.cyan,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () => _act(
                          () => TravelPlanService.instance.setOptions(
                            plan.id,
                            status: plan.status == 'active'
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
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _LiveTripScreen(plan: plan),
                          ),
                        ),
                        child: const Text('Gezi durumunu paylaş'),
                      ),
                  ],
                ),
                member ? _PlanGroupTab(plan: plan) : const _PrivateRouteTab(),
                member
                    ? RouteAlbumScreen(plan: plan)
                    : const _PrivateRouteTab(),
              ],
            ),
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

class _RouteTabs extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 49;
  @override
  double get maxExtent => 49;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => const ColoredBox(
    color: Color(0xFF07080B),
    child: TabBar(
      indicatorColor: AppColors.cyan,
      tabs: [
        Tab(text: 'Plan'),
        Tab(text: 'Sohbet'),
        Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Albüm'),
              SizedBox(width: 5),
              Icon(Icons.lock_outline, size: 13),
            ],
          ),
        ),
      ],
    ),
  );
  @override
  bool shouldRebuild(covariant _RouteTabs oldDelegate) => false;
}

class _PlanGroupTab extends StatefulWidget {
  final TravelPlan plan;
  const _PlanGroupTab({required this.plan});

  @override
  State<_PlanGroupTab> createState() => _PlanGroupTabState();
}

class _PlanGroupTabState extends State<_PlanGroupTab> {
  final _message = TextEditingController();
  final _proposal = TextEditingController();
  List<PhotoSpot> _suggestions = const [];
  PhotoSpot? _selectedProposalSpot;
  int _searchGeneration = 0;

  @override
  void dispose() {
    _message.dispose();
    _proposal.dispose();
    super.dispose();
  }

  Future<void> _addProposal() async {
    final selected = _selectedProposalSpot;
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listeden bir yer seç veya haritadan konum belirle.'),
        ),
      );
      return;
    }
    await TravelPlanCollaborationService.instance.propose(
      widget.plan.id,
      _proposal.text,
      spotId: selected.id,
      latitude: selected.latitude,
      longitude: selected.longitude,
      city: selected.city,
    );
    _proposal.clear();
    setState(() {
      _selectedProposalSpot = null;
      _suggestions = const [];
    });
  }

  Future<void> _searchProposal(String value) async {
    final generation = ++_searchGeneration;
    _selectedProposalSpot = null;
    final query = value.trim();
    if (query.length < 2) {
      if (mounted) setState(() => _suggestions = const []);
      return;
    }
    final matches = await SpotRepository.instance.search(query, limit: 8);
    if (!mounted || generation != _searchGeneration) return;
    setState(() => _suggestions = matches.take(6).toList());
  }

  void _selectSuggestion(PhotoSpot spot) {
    _proposal.text = spot.name;
    _proposal.selection = TextSelection.collapsed(offset: spot.name.length);
    setState(() {
      _selectedProposalSpot = spot;
      _suggestions = const [];
    });
  }

  Future<void> _pickProposalFromMap() async {
    final selection = await Navigator.push<EventLocationSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => EventLocationPickerScreen(
          city: widget.plan.city,
          addressLabel: _proposal.text.trim(),
          title: 'Durak Konumunu Seç',
          instruction: 'Eklemek istediğin durağın tam noktasına dokun. Pini sürükleyerek düzeltebilirsin.',
        ),
      ),
    );
    if (selection == null || !mounted) return;
    final label = _proposal.text.trim().isEmpty
        ? 'Haritadan seçilen durak'
        : _proposal.text.trim();
    await TravelPlanCollaborationService.instance.propose(
      widget.plan.id,
      label,
      latitude: selection.latitude,
      longitude: selection.longitude,
      city: widget.plan.city,
    );
    _proposal.clear();
    setState(() {
      _selectedProposalSpot = null;
      _suggestions = const [];
    });
  }

  Future<void> _send() async {
    await TravelPlanCollaborationService.instance.sendMessage(
      widget.plan.id,
      _message.text,
    );
    _message.clear();
  }

  Future<void> _accept(
    String proposalId,
    String text,
    Map<String, dynamic> proposal,
  ) async {
    if (proposal['stopSnapshot'] is Map) {
      try {
        await TravelPlanCollaborationService.instance.acceptDayStopProposal(
          widget.plan.id,
          proposalId,
        );
      } catch (error) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.toString().replaceFirst('Exception: ', '')),
            ),
          );
      }
      return;
    }
    final spotId = (proposal['spotId'] ?? '').toString();
    final allSpots = await SpotRepository.instance.loadSpots();
    final byId = allSpots.where((spot) => spot.id == spotId).toList();
    final matches = byId.isNotEmpty
        ? byId
        : await SpotRepository.instance.search(text, limit: 2000);
    if (!mounted) return;
    if (matches.isNotEmpty) {
      await TravelPlanService.instance.addStop(widget.plan.id, matches.first);
    } else {
      final latitude = (proposal['latitude'] as num?)?.toDouble();
      final longitude = (proposal['longitude'] as num?)?.toDouble();
      if (latitude == null || longitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu yer bulunamadı. Haritadan seç.')),
        );
        return;
      }
      await TravelPlanService.instance.addCustomStop(
        planId: widget.plan.id,
        name: text,
        latitude: latitude,
        longitude: longitude,
        city: (proposal['city'] ?? widget.plan.city).toString(),
      );
    }
    await TravelPlanCollaborationService.instance.acceptProposal(
      widget.plan.id,
      proposalId,
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$text rotaya eklendi.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: [
        RoutePolls(planId: widget.plan.id, ownerId: widget.plan.ownerId),
        ExpansionTile(
          title: const Text('Durak önerileri'),
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _proposal,
                    maxLength: 180,
                    onChanged: _searchProposal,
                    decoration: const InputDecoration(
                      hintText: 'Yer veya mekan adı yaz',
                      prefixIcon: Icon(Icons.search_rounded),
                      counterText: '',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _addProposal,
                  icon: const Icon(Icons.add_circle_rounded),
                ),
              ],
            ),
            if (_suggestions.isNotEmpty)
              Card(
                margin: const EdgeInsets.only(top: 4, bottom: 8),
                child: Column(
                  children: [
                    for (final spot in _suggestions)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.place_outlined),
                        title: Text(spot.name),
                        subtitle: Text('${spot.city} • ${spot.category}'),
                        onTap: () => _selectSuggestion(spot),
                      ),
                  ],
                ),
              )
            else if (_proposal.text.trim().length >= 2 &&
                _selectedProposalSpot == null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _pickProposalFromMap,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Yer yoksa haritadan konum seç'),
                ),
              ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: TravelPlanCollaborationService.instance.proposals(
                widget.plan.id,
              ),
              builder: (_, snapshot) {
                final docs = snapshot.data?.docs ?? const [];
                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final voters =
                        (data['voterIds'] as List<dynamic>? ?? const [])
                            .map((id) => id.toString())
                            .toList();
                    final voted = voters.contains(
                      FirebaseAuth.instance.currentUser?.uid,
                    );
                    final accepted = data['status'] == 'accepted';
                    final owned =
                        widget.plan.ownerId ==
                        FirebaseAuth.instance.currentUser?.uid;
                    return Card(
                      child: ListTile(
                        title: Text((data['text'] ?? '').toString()),
                        subtitle: accepted
                            ? const Text('Rotaya eklendi')
                            : null,
                        onTap:
                            data['stopSnapshot'] is Map &&
                                (data['stopSnapshot'] as Map)['venue'] is Map
                            ? () {
                                final venue = Map<String, dynamic>.from(
                                  (data['stopSnapshot'] as Map)['venue'] as Map,
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BusinessProfileScreen(
                                      venue: NearbyVenue.fromJson(venue),
                                    ),
                                  ),
                                );
                              }
                            : null,
                        trailing: Wrap(
                          spacing: 2,
                          children: [
                            TextButton.icon(
                              onPressed: voted
                                  ? null
                                  : () => TravelPlanCollaborationService
                                        .instance
                                        .vote(widget.plan.id, doc.id),
                              icon: Icon(
                                voted
                                    ? Icons.thumb_up_rounded
                                    : Icons.thumb_up_outlined,
                              ),
                              label: Text('${voters.length}'),
                            ),
                            if (owned && !accepted)
                              IconButton(
                                tooltip: 'Rotaya ekle',
                                onPressed: () => _accept(
                                  doc.id,
                                  (data['text'] ?? '').toString(),
                                  data,
                                ),
                                icon: const Icon(
                                  Icons.playlist_add_check_rounded,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Rota sohbeti', style: _titleStyle),
        const SizedBox(height: 8),
        SizedBox(
          height: 300,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: TravelPlanCollaborationService.instance.messages(
              widget.plan.id,
            ),
            builder: (_, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              if (docs.isEmpty) {
                return const Center(child: Text('Henüz mesaj yok.'));
              }
              return ListView.builder(
                reverse: true,
                itemCount: docs.length,
                itemBuilder: (_, index) {
                  final data = docs[index].data();
                  final mine =
                      data['senderId'] ==
                      FirebaseAuth.instance.currentUser?.uid;
                  return Align(
                    alignment: mine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: mine
                            ? AppColors.surfaceElevated
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!mine)
                            ProfileNameLink(
                              userId: (data['senderId'] ?? '').toString(),
                              compact: true,
                              child: Text(
                                (data['senderName'] ?? '').toString(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.cyan,
                                ),
                              ),
                            ),
                          Text((data['text'] ?? '').toString()),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _message,
                decoration: const InputDecoration(hintText: 'Mesaj yaz'),
              ),
            ),
            IconButton(onPressed: _send, icon: const Icon(Icons.send_rounded)),
          ],
        ),
      ],
    );
  }
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
                    children: docs.map((doc) {
                      final data = doc.data();
                      final latitude = (data['latitude'] as num?)?.toDouble();
                      final longitude = (data['longitude'] as num?)?.toDouble();
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
                            (data['userName'] ?? 'TBT kullanıcısı').toString(),
                          ),
                        ),
                        subtitle: Text((data['stopName'] ?? '').toString()),
                        trailing: latitude == null || longitude == null
                            ? null
                            : IconButton(
                                tooltip: 'Haritada gör',
                                onPressed: () => launchUrl(
                                  Uri.parse(
                                    'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
                                  ),
                                  mode: LaunchMode.externalApplication,
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

class _Metric extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Metric(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: AppColors.cyan),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    ],
  );
}

const _titleStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w900);
