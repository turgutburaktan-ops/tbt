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
import '../widgets/firebase_media_image.dart';
import 'post_detail_screen.dart';
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
  bool _savingOffline = false;

  TravelPlan get plan => widget.plan;
  bool get _owned => FirebaseAuth.instance.currentUser?.uid == plan.ownerId;

  Future<void> _openRoute() async {
    final spots = await TravelPlanService.instance.resolveSpots(plan);
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
        builder: (_) => RoutePlannerScreen(initialSpots: spots),
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

  Future<void> _setPublic(bool value) async {
    setState(() => _public = value);
    try {
      await TravelPlanService.instance.setPublic(plan.id, value);
    } catch (_) {
      if (mounted) setState(() => _public = !value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = plan.memberIds.contains(FirebaseAuth.instance.currentUser?.uid);
    return DefaultTabController(
      length: member ? 3 : 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(plan.title),
          actions: [
            IconButton(
              tooltip: 'Paylaş',
              onPressed: _share,
              icon: const Icon(Icons.share_rounded),
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Plan'),
              if (member) const Tab(text: 'Grup'),
              const Tab(text: 'Anılar'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _overview(),
            if (member) _PlanGroupTab(plan: plan),
            _PlanMemoriesTab(plan: plan),
          ],
        ),
      ),
    );
  }

  Widget _overview() {
    final start = plan.startAt.toLocal();
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.subtleGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderAccent),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                '${start.day.toString().padLeft(2, '0')}.${start.month.toString().padLeft(2, '0')}.${start.year} • ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 10,
                children: [
                  _Metric(Icons.route_rounded, '${plan.distanceKm.toStringAsFixed(1)} km'),
                  _Metric(Icons.schedule_rounded, '${plan.travelMinutes} dk yol'),
                  _Metric(Icons.payments_outlined, '≈ ${plan.estimatedBudget} TL'),
                  if (plan.weatherSummary.isNotEmpty)
                    _Metric(Icons.cloud_outlined, plan.weatherSummary),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...List.generate(
          plan.spotNames.length,
          (index) => ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(plan.spotNames[index]),
            subtitle: Text(index == 0 ? 'Başlangıç durağı' : 'Sonraki durak'),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _openRoute,
          icon: const Icon(Icons.map_rounded),
          label: const Text('Rotayı Haritada Aç'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => _LiveTripScreen(plan: plan)),
          ),
          icon: const Icon(Icons.navigation_rounded),
          label: const Text('Canlı Gezi Modunu Başlat'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _savingOffline ? null : _saveOffline,
          icon: const Icon(Icons.offline_pin_outlined),
          label: const Text('Çevrimdışı Kullanmak İçin İndir'),
        ),
        if (_owned)
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            value: _public,
            onChanged: _setPublic,
            title: const Text('Hazır rotalarda yayınla'),
            subtitle: const Text('Diğer kullanıcılar rotanı bulup puanlayabilir.'),
          ),
      ],
    );
  }
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
          instruction:
              'Eklemek istediğin durağın tam noktasına dokun. Pini sürükleyerek düzeltebilirsin.',
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

  Future<void> _pickMeetingPoint(Map<String, dynamic> current) async {
    final labelController = TextEditingController(
      text: (current['label'] ?? '').toString(),
    );
    final continueToMap = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
          city: widget.plan.city,
          addressLabel: label.isEmpty ? 'Buluşma noktası' : label,
          initialLatitude: (current['latitude'] as num?)?.toDouble(),
          initialLongitude: (current['longitude'] as num?)?.toDouble(),
          title: 'Buluşma Noktasını Seç',
          instruction:
              'Grubun buluşacağı tam noktaya dokun. Pini sürükleyerek düzeltebilirsin.',
        ),
      ),
    );
    if (selection == null) return;
    await TravelPlanCollaborationService.instance.setMeetingPoint(
      planId: widget.plan.id,
      label: selection.label,
      latitude: selection.latitude,
      longitude: selection.longitude,
    );
  }

  Future<void> _openMeetingPoint(Map<String, dynamic> point) async {
    final latitude = (point['latitude'] as num?)?.toDouble();
    final longitude = (point['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return;
    await launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'),
      mode: LaunchMode.externalApplication,
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$text rotaya eklendi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: [
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('travel_plans')
              .doc(widget.plan.id)
              .snapshots(),
          builder: (context, snapshot) {
            final point = Map<String, dynamic>.from(
              snapshot.data?.data()?['meetingPoint'] as Map? ?? const {},
            );
            final hasPoint =
                point['latitude'] is num && point['longitude'] is num;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.handshake_outlined),
                title: Text(
                  hasPoint
                      ? (point['label'] ?? 'Buluşma noktası').toString()
                      : 'Buluşma noktası belirle',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  hasPoint
                      ? 'Haritada açmak için dokun'
                      : 'Grubun nerede buluşacağını haritadan seç',
                ),
                onTap: hasPoint
                    ? () => _openMeetingPoint(point)
                    : () => _pickMeetingPoint(point),
                trailing: IconButton(
                  tooltip: hasPoint ? 'Buluşma noktasını değiştir' : 'Seç',
                  onPressed: () => _pickMeetingPoint(point),
                  icon: Icon(
                    hasPoint ? Icons.edit_location_alt_outlined : Icons.add_location_alt_outlined,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        const Text('Durak önerileri ve oylama', style: _titleStyle),
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
            IconButton(onPressed: _addProposal, icon: const Icon(Icons.add_circle_rounded)),
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
          stream: TravelPlanCollaborationService.instance.proposals(widget.plan.id),
          builder: (_, snapshot) {
            final docs = snapshot.data?.docs ?? const [];
            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                final voters = (data['voterIds'] as List<dynamic>? ?? const [])
                    .map((id) => id.toString())
                    .toList();
                final voted = voters.contains(FirebaseAuth.instance.currentUser?.uid);
                final accepted = data['status'] == 'accepted';
                final owned = widget.plan.ownerId == FirebaseAuth.instance.currentUser?.uid;
                return Card(
                  child: ListTile(
                    title: Text((data['text'] ?? '').toString()),
                    subtitle: accepted ? const Text('Rotaya eklendi') : null,
                    trailing: Wrap(
                      spacing: 2,
                      children: [
                        TextButton.icon(
                          onPressed: voted
                              ? null
                              : () => TravelPlanCollaborationService.instance.vote(
                                    widget.plan.id,
                                    doc.id,
                                  ),
                          icon: Icon(voted ? Icons.thumb_up_rounded : Icons.thumb_up_outlined),
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
                            icon: const Icon(Icons.playlist_add_check_rounded),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        const Text('Plan sohbeti', style: _titleStyle),
        const SizedBox(height: 8),
        SizedBox(
          height: 300,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: TravelPlanCollaborationService.instance.messages(widget.plan.id),
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
                  final mine = data['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: mine ? AppColors.surfaceElevated : AppColors.surface,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!mine)
                            Text(
                              (data['senderName'] ?? '').toString(),
                              style: const TextStyle(fontSize: 10, color: AppColors.cyan),
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
            Expanded(child: TextField(controller: _message, decoration: const InputDecoration(hintText: 'Mesaj yaz'))),
            IconButton(onPressed: _send, icon: const Icon(Icons.send_rounded)),
          ],
        ),
      ],
    );
  }
}

class _PlanMemoriesTab extends StatelessWidget {
  final TravelPlan plan;
  const _PlanMemoriesTab({required this.plan});

  @override
  Widget build(BuildContext context) {
    final names = plan.spotNames.map((name) => name.toLowerCase()).toSet();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(160)
          .snapshots(),
      builder: (_, snapshot) {
        final docs = (snapshot.data?.docs ?? const []).where((doc) {
          final spot = (doc.data()['spotName'] ?? '').toString().toLowerCase();
          return names.contains(spot) || doc.data()['travelPlanId'] == plan.id;
        }).toList();
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'Bu rotanın duraklarında paylaşılan fotoğraf ve videolar burada otomatik albüme dönüşecek.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(3),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
          ),
          itemCount: docs.length,
          itemBuilder: (_, index) {
            final doc = docs[index];
            final data = {...doc.data(), 'id': doc.id};
            final image = (data['thumbnailUrl'] ?? data['imageUrl'] ?? '').toString();
            final path = (data['thumbnailStoragePath'] ?? data['storagePath'] ?? '').toString();
            return InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PostDetailScreen(post: data)),
              ),
              child: FirebaseMediaImage(imageUrl: image, storagePath: path, fit: BoxFit.cover),
            );
          },
        );
      },
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
            const Text('ŞU ANKİ DURAK', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 8),
            Text(stops[_index], textAlign: TextAlign.center, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text('${_index + 1} / ${stops.length}'),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: () => _update(true), icon: const Icon(Icons.location_on_rounded), label: const Text('Buradayım')),
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
            const Align(alignment: Alignment.centerLeft, child: Text('Gruptakiler', style: _titleStyle)),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: TravelPlanCollaborationService.instance.liveStates(widget.plan.id),
                builder: (_, snapshot) {
                  final docs = snapshot.data?.docs ?? const [];
                  return ListView(
                    children: docs.map((doc) {
                      final data = doc.data();
                      final latitude = (data['latitude'] as num?)?.toDouble();
                      final longitude = (data['longitude'] as num?)?.toDouble();
                      return ListTile(
                        leading: Icon(data['active'] == true ? Icons.location_on_rounded : Icons.location_off_outlined),
                        title: Text((data['userName'] ?? 'TBT kullanıcısı').toString()),
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
