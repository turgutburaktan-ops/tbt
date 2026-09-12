import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/travel_plan_service.dart';
import '../theme/app_theme.dart';
import 'event_location_picker_screen.dart';
import 'travel_plan_invite_screen.dart';

class RouteSharingScreen extends StatefulWidget {
  final String routeId;
  final String title;
  final bool inviteFriends;
  const RouteSharingScreen({
    super.key,
    required this.routeId,
    required this.title,
    this.inviteFriends = false,
  });
  @override
  State<RouteSharingScreen> createState() => _RouteSharingScreenState();
}

class _RouteSharingScreenState extends State<RouteSharingScreen> {
  String _visibility = 'Sadece ben', _kind = 'Rotayı paylaş';
  DateTime? _start;
  EventLocationSelection? _point;
  final _limit = TextEditingController();
  bool _busy = false, _loaded = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d =
          (await FirebaseFirestore.instance
                  .collection('travel_plans')
                  .doc(widget.routeId)
                  .get())
              .data()!;
      if (!mounted) return;
      setState(() {
        _visibility = d['isPublic'] == true
            ? 'Herkese açık'
            : widget.inviteFriends
            ? 'Arkadaşlarım'
            : 'Sadece ben';
        _kind = d['joinEnabled'] == true ? 'Birlikte gidelim' : 'Rotayı paylaş';
        _start = (d['startAt'] as Timestamp?)?.toDate();
        final p = d['meetingPoint'];
        if (p is Map)
          _point = EventLocationSelection(
            latitude: (p['latitude'] as num).toDouble(),
            longitude: (p['longitude'] as num).toDouble(),
            label: p['label'].toString(),
          );
        if (d['participantLimit'] is num)
          _limit.text = d['participantLimit'].toString();
        _loaded = true;
      });
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rota yüklenemedi. Tekrar açmayı dene.'),
          ),
        );
    }
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Future<void> _date() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (t != null && mounted)
      setState(
        () => _start = DateTime(d.year, d.month, d.day, t.hour, t.minute),
      );
  }

  Future<void> _save() async {
    if (_busy) return;
    final together =
        _visibility == 'Herkese açık' && _kind == 'Birlikte gidelim';
    final limit = _limit.text.trim().isEmpty
        ? null
        : int.tryParse(_limit.text.trim());
    if (together &&
        (_start == null ||
            !_start!.isAfter(DateTime.now()) ||
            _point == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gelecekte bir tarih, saat ve buluşma noktası seç.'),
        ),
      );
      return;
    }
    if (together &&
        _limit.text.trim().isNotEmpty &&
        (limit == null || limit < 2 || limit > 60)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kişi sınırı, sen dahil 2–60 arasında olmalı.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await TravelPlanService.instance.configureSharing(
        widget.routeId,
        isPublic: _visibility == 'Herkese açık',
        together: together,
        privateOnly: _visibility == 'Sadece ben',
        start: _start,
        meetingPoint: _point == null
            ? null
            : {
                'label': _point!.label,
                'latitude': _point!.latitude,
                'longitude': _point!.longitude,
              },
        limit: limit,
      );
      if (!mounted) return;
      if (_visibility == 'Arkadaşlarım')
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TravelPlanInviteScreen(
              planId: widget.routeId,
              planTitle: widget.title,
            ),
          ),
        );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Rotayı paylaş')),
    body: !_loaded
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _visibility,
                decoration: const InputDecoration(labelText: 'Kim görebilsin?'),
                items: ['Sadece ben', 'Arkadaşlarım', 'Herkese açık']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _visibility = v!),
              ),
              if (_visibility == 'Sadece ben')
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Rota kişisel kalır. Daha önce davet ettiğin kişiler varsa erişimleri kaldırılır.',
                  ),
                ),
              if (_visibility == 'Herkese açık') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _kind,
                  items: ['Rotayı paylaş', 'Birlikte gidelim']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _kind = v!),
                ),
                if (_kind == 'Rotayı paylaş')
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Diğer kullanıcılar bu hazır rotayı keşfedip kaydedebilir.',
                    ),
                  ),
                if (_kind == 'Birlikte gidelim') ...[
                  ListTile(
                    title: const Text('Tarih ve buluşma saati'),
                    subtitle: Text(
                      _start == null
                          ? 'Seç'
                          : '${_start!.day}.${_start!.month}.${_start!.year} · ${TimeOfDay.fromDateTime(_start!).format(context)}',
                    ),
                    onTap: _date,
                  ),
                  ListTile(
                    title: const Text('Buluşma noktası'),
                    subtitle: Text(_point?.label ?? 'Haritadan seç'),
                    onTap: () async {
                      final p = await Navigator.push<EventLocationSelection>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EventLocationPickerScreen(
                            city: '',
                            addressLabel: 'Buluşma noktası',
                            title: 'Buluşma noktası',
                            instruction: 'Buluşacağınız noktayı haritadan seç.',
                          ),
                        ),
                      );
                      if (p != null && mounted) setState(() => _point = p);
                    },
                  ),
                  TextField(
                    controller: _limit,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Kişi sınırı (isteğe bağlı)',
                      helperText: 'Sen dahil. Boş bırakırsan uygulama sınırı 60 kişidir.',
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Katılım isteklerini sen onaylayacaksın.'),
                  ),
                ],
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Kaydediliyor…' : 'Kaydet'),
              ),
            ],
          ),
  );
}

class RouteParticipation extends StatelessWidget {
  final String routeId;
  final Map<String, dynamic> data;
  const RouteParticipation({
    super.key,
    required this.routeId,
    required this.data,
  });
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final owner = uid == data['ownerId'];
    final enabled = data['joinEnabled'] == true;
    if (!owner && !enabled) return const SizedBox.shrink();
    final ref = FirebaseFirestore.instance
        .collection('travel_plans')
        .doc(routeId)
        .collection('join_requests');
    Future<void> act(Future<void> Function() fn) async {
      try {
        await fn();
      } catch (e) {
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
            ),
          );
      }
    }

    if (owner)
      return Column(
        children: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RouteSharingScreen(
                  routeId: routeId,
                  title: data['title'] ?? 'Rota',
                ),
              ),
            ),
            icon: const Icon(Icons.group_outlined),
            label: const Text('Paylaşım ve katılım ayarları'),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: ref.where('status', isEqualTo: 'pending').snapshots(),
            builder: (_, snapshot) => Column(
              children: (snapshot.data?.docs ?? [])
                  .map(
                    (d) => ListTile(
                      title: Text(d.data()['name'] ?? 'Katılım isteği'),
                      trailing: Wrap(
                        children: [
                          TextButton(
                            onPressed: () => act(
                              () => TravelPlanService.instance.reviewJoin(
                                routeId,
                                d.id,
                                true,
                              ),
                            ),
                            child: const Text('Onayla'),
                          ),
                          TextButton(
                            onPressed: () => act(
                              () => TravelPlanService.instance.reviewJoin(
                                routeId,
                                d.id,
                                false,
                              ),
                            ),
                            child: const Text('Reddet'),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      );
    if ((data['memberIds'] as List? ?? []).contains(uid))
      return const ListTile(title: Text('Bu rotaya katılıyorsun'));
    if (uid == null)
      return const ListTile(title: Text('Katılım isteği için giriş yap.'));
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.doc(uid).snapshots(),
      builder: (_, s) {
        final status = s.data?.data()?['status'];
        return FilledButton(
          onPressed: status == 'pending'
              ? null
              : () =>
                    act(() => TravelPlanService.instance.requestJoin(routeId)),
          child: Text(
            status == 'pending'
                ? 'Katılım isteği gönderildi'
                : 'Katılım isteği gönder',
          ),
        );
      },
    );
  }
}
