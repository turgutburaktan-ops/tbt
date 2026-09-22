import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/route_access.dart';
import '../widgets/route_access_settings.dart';
import '../services/travel_plan_service.dart';
import 'travel_plan_invite_screen.dart';

class RouteSharingScreen extends StatefulWidget {
  const RouteSharingScreen({super.key, required this.routeId, required this.title, this.inviteFriends = false});
  final String routeId, title;
  final bool inviteFriends;
  @override
  State<RouteSharingScreen> createState() => _RouteSharingScreenState();
}
class _RouteSharingScreenState extends State<RouteSharingScreen> {
  RouteAccess _access = const RouteAccess();
  DateTime? _start;
  bool _loaded = false, _busy = false;
  String? _error;
  final _limit = TextEditingController();
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _limit.dispose(); super.dispose(); }
  Future<void> _load() async {
    try {
      final d = (await FirebaseFirestore.instance.collection('travel_plans').doc(widget.routeId).get()).data();
      if (d == null) throw Exception('Rota bulunamadı.');
      if (!mounted) return;
      setState(() {
        _access = RouteAccess.fromMap(d);
        _start = d['hasSchedule'] == true || d['joinEnabled'] == true ? (d['startAt'] as Timestamp?)?.toDate() : null;
        _limit.text = (d['participantLimit'] ?? 60).toString();
        _loaded = true; _error = null;
      });
    } catch (_) { if (mounted) setState(() => _error = 'Ayarlar yüklenemedi. Tekrar dene.'); }
  }
  Future<DateTime?> _date() async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, initialDate: _start != null && _start!.isAfter(now) ? _start! : now,
      firstDate: now, lastDate: now.add(const Duration(days: 730)));
    if (date == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start ?? now.add(const Duration(hours:1))));
    if (time == null || !mounted) return null;
    final next = DateTime(date.year,date.month,date.day,time.hour,time.minute);
    if (!next.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İleri bir tarih ve saat seç.')));
      return null;
    }
    setState(() => _start = next);
    return next;
  }
  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final limit = int.tryParse(_limit.text.trim());
      if (limit == null) throw Exception('Geçerli bir kişi sınırı gir.');
      await TravelPlanService.instance.setAccess(widget.routeId, _access, _start, limit: limit);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ',''))));
    } finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Görünürlük ve katılım')),
    body: _error != null ? Center(child: TextButton(onPressed: _load, child: Text(_error!)))
      : !_loaded ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
        RouteAccessSettings(value: _access, startAt: _start, pickDate: _date, busy: _busy,
          onChanged: (v) => setState(() => _access = v)),
        ListTile(title: const Text('Tarih ve saat'),
          subtitle: Text(_start == null ? 'Daha sonra belirle' : '${_start!.day}.${_start!.month}.${_start!.year} · ${TimeOfDay.fromDateTime(_start!).format(context)}'),
          onTap: _busy ? null : _date),
        if (_start != null) TextButton(onPressed: _busy ? null : () async {
          if (_access.enabled) {
            final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
              title: const Text('Tarihi kaldır'), content: const Text('Tarihi kaldırırsan katılım da kapanır.'),
              actions: [TextButton(onPressed: () => Navigator.pop(c,false),child: const Text('Vazgeç')),
                FilledButton(onPressed: () => Navigator.pop(c,true), child: const Text('Tarihi kaldır ve katılımı kapat'))]));
            if (ok != true || !mounted) return;
          }
          setState(() { _start = null; _access = RouteAccess(visibility:_access.visibility, audience:_access.audience, approval:_access.approval); });
        }, child: const Text('Tarihi daha sonra belirle')),
        if (_access.enabled) TextField(controller: _limit, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Kişi sınırı',helperText: 'Sen dahil en fazla 60 kişi.')),
        ListTile(title: const Text('Davetlileri seç'), trailing: const Icon(Icons.person_add_alt),
          onTap: _busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => TravelPlanInviteScreen(planId:widget.routeId,planTitle:widget.title)))),
        const SizedBox(height:16),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Kaydediliyor…' : 'Kaydet')),
      ]),
  );
}

class RouteParticipation extends StatelessWidget {
  final String routeId;
  final Map<String, dynamic> data;
  final bool showSettings;
  const RouteParticipation({
    super.key,
    required this.routeId,
    required this.data,
    this.showSettings = true,
  });
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final owner = uid == data['ownerId'];
    final enabled = data['joinEnabled'] == true;
    final invited = (data['invitedIds'] as List? ?? []).contains(uid);
    if (!owner && !enabled) return ListTile(title: Text(invited ? 'Bu rotaya davetlisin. Katılım henüz açık değil.' : 'Katılım kapalı'));
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
          if (showSettings)
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
    final access = RouteAccess.fromMap(data);
    final start = (data['startAt'] as Timestamp?)?.toDate();
    if (start == null || !start.isAfter(DateTime.now())) return const ListTile(title: Text('Bu rotaya katılım sona erdi.'));
    if ((data['memberIds'] as List? ?? []).length >= (data['participantLimit'] as num? ?? 60)) return const ListTile(title: Text('Rota dolu.'));
    Widget action() {
      if (invited) return Wrap(spacing: 8, children: [
        FilledButton(onPressed: () => act(() => TravelPlanService.instance.requestJoin(routeId)), child: const Text('Daveti kabul et')),
        TextButton(onPressed: () => act(() => TravelPlanService.instance.declineInvite(routeId)), child: const Text('Daveti reddet')),
      ]);
      if (!access.approval) return FilledButton(onPressed: () => act(() => TravelPlanService.instance.requestJoin(routeId)), child: const Text('Katıl'));
      return StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream: ref.doc(uid).snapshots(), builder: (_,s) {
        final pending = s.data?.data()?['status'] == 'pending';
        return FilledButton(onPressed: pending ? null : () => act(() => TravelPlanService.instance.requestJoin(routeId)),
          child: Text(pending ? 'Katılım isteği gönderildi' : 'Katılım isteği gönder'));
      });
    }
    if (invited || access.audience == 'public') return action();
    if (access.audience == 'private') return const ListTile(title: Text('Katılım yalnızca davetlilere açık.'));
    return StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(data['ownerId'] as String).collection('followers').doc(uid).snapshots(),
      builder: (_,s) => s.data?.exists == true ? action() : const ListTile(title: Text('Katılım yalnızca takipçilere açık.')),
    );
  }
}
