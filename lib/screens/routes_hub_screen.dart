import '../widgets/route_management_menu.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/travel_plan.dart';
import '../services/travel_plan_service.dart';
import '../services/user_facing_error.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_chrome.dart';
import '../widgets/firebase_media_image.dart';
import 'route_create_screen.dart';
import 'travel_plan_detail_screen.dart';

String routeDate(TravelPlan p) {
  if (!p.hasSchedule) return 'Tarih belirlenmedi';
  final d = p.startAt.toLocal();
  return '${d.day}.${d.month}.${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

IconData routeTransportIcon(String mode) => switch (mode) {
  'Yürüyüş' => Icons.directions_walk_rounded,
  'Bisiklet' => Icons.directions_bike_rounded,
  _ => Icons.directions_car_outlined,
};

class RoutesHubScreen extends StatefulWidget {
  const RoutesHubScreen({super.key});
  @override
  State<RoutesHubScreen> createState() => _RoutesHubScreenState();
}

class _RoutesHubScreenState extends State<RoutesHubScreen> {
  int _tab = 0, _filter = 0;
  String _search = '';
  String _city = '';
  late final _mine = TravelPlanService.instance.watchMine();
  late final _public = TravelPlanService.instance.watchPublic();
  final _followersPlans = <String, List<TravelPlan>>{};
  final _subscriptions =
      <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _following;
  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _following = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('following')
          .snapshots()
          .listen((s) {
            final ids = s.docs.map((d) => d.id).toSet();
            for (final id in _subscriptions.keys.toList()) {
              if (!ids.contains(id)) {
                _subscriptions.remove(id)?.cancel();
                _followersPlans.remove(id);
              }
            }
            for (final id in ids) {
              _subscriptions.putIfAbsent(
                id,
                () => FirebaseFirestore.instance
                    .collection('travel_plans')
                    .where('ownerId', isEqualTo: id)
                    .where('visibility', isEqualTo: 'followers')
                    .snapshots()
                    .listen(
                      (p) {
                        if (mounted)
                          setState(
                            () => _followersPlans[id] = p.docs
                                .map(TravelPlan.fromDoc)
                                .toList(),
                          );
                      },
                      onError: (_) {
                        if (mounted) setState(() => _followersPlans.remove(id));
                      },
                    ),
              );
            }
            if (mounted) setState(() {});
          }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _following?.cancel();
    for (final s in _subscriptions.values) {
      s.cancel();
    }
    super.dispose();
  }

  void _create() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const RouteCreateScreen()),
  );
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.background,
    child: SafeArea(
      bottom: false,
      child: StreamBuilder<List<TravelPlan>>(
        stream: _mine,
        builder: (_, mine) {
          final plans = mine.data ?? <TravelPlan>[];
          final upcoming =
              plans
                  .where(
                    (p) =>
                        p.status == 'active' ||
                        (p.status != 'completed' &&
                            p.hasSchedule &&
                            p.startAt.isAfter(DateTime.now())),
                  )
                  .toList()
                ..sort(
                  (a, b) => a.status == 'active' && b.status != 'active'
                      ? -1
                      : b.status == 'active' && a.status != 'active'
                      ? 1
                      : a.startAt.compareTo(b.startAt),
                );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            children: [
              AppPageHeading(
                title: 'Rotalar',
                action: FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add, size: 19),
                  label: const Text('Rota oluştur'),
                ),
              ),
              const SizedBox(height: 22),
              if (upcoming.isNotEmpty) ...[
                Text(
                  upcoming.first.status == 'active'
                      ? 'DEVAM EDEN GEZİN'
                      : 'YAKLAŞAN GEZİN',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                RoutePreviewCard(plan: upcoming.first, featured: true),
                const SizedBox(height: 20),
              ],
              AppSectionTabs(
                labels: const ['Rotalarım', 'Keşfet'],
                selected: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 14),
              if (_tab == 0) ...[
                Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < 3; i++)
                      ChoiceChip(
                        label: Text(
                          ['Yaklaşan', 'Tamamlanan', 'Kaydedilen'][i],
                        ),
                        selected: _filter == i,
                        onSelected: (_) => setState(() => _filter = i),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_filter == 2)
                  const _SavedRoutes()
                else if (mine.hasError)
                  _message(userFacingError(mine.error!))
                else if (mine.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else
                  ..._list(
                    plans
                        .where(
                          (p) => _filter == 1
                              ? p.status == 'completed'
                              : p.status != 'completed',
                        )
                        .toList(),
                  ),
              ] else ...[
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Rota veya yer ara',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
                const SizedBox(height: 10),
                StreamBuilder<List<TravelPlan>>(
                  stream: _public,
                  builder: (_, s) {
                    if (s.hasError) return _message(userFacingError(s.error!));
                    if (!s.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final all = <String, TravelPlan>{
                      for (final p in [
                        ...s.data!,
                        ..._followersPlans.values.expand((v) => v),
                      ])
                        p.id: p,
                    }.values.toList();
                    final cities =
                        all
                            .map((p) => p.city)
                            .where((s) => s.isNotEmpty)
                            .toSet()
                            .toList()
                          ..sort();
                    final selectedCity = cities.contains(_city) ? _city : '';
                    final filtered = all
                        .where(
                          (p) =>
                              (selectedCity.isEmpty ||
                                  p.city == selectedCity) &&
                              '${p.title} ${p.city} ${p.spotNames.join(' ')}'
                                  .toLowerCase()
                                  .contains(_search.toLowerCase()),
                        )
                        .toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedCity,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.location_city_outlined),
                            labelText: 'Şehir',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Tüm şehirler'),
                            ),
                            ...cities.map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            ),
                          ],
                          onChanged: (v) => setState(() => _city = v ?? ''),
                        ),
                        const SizedBox(height: 12),
                        ..._list(filtered),
                      ],
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
  Widget _message(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 35),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.textMuted),
    ),
  );
  List<Widget> _list(List<TravelPlan> plans) => plans.isEmpty
      ? [
          _message(
            _tab == 1
                ? 'Bu aramada rota bulunamadı.'
                : _filter == 1
                ? 'Tamamladığın geziler ve albümleri burada olacak.'
                : 'İlk rotanı oluştur, duraklarını seç ve arkadaşlarını davet et.',
          ),
        ]
      : plans
            .map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RoutePreviewCard(plan: p),
              ),
            )
            .toList();
}

class RoutePreviewCard extends StatelessWidget {
  const RoutePreviewCard({
    super.key,
    required this.plan,
    this.featured = false,
  });
  final TravelPlan plan;
  final bool featured;
  void _open(BuildContext c) => Navigator.push(
    c,
    MaterialPageRoute(builder: (_) => TravelPlanDetailScreen(plan: plan)),
  );
  @override
  Widget build(BuildContext context) {
    final image =
        plan.stopSnapshots
            .map((s) => (s['imageUrl'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .firstOrNull ??
        '';
    final thumbnail = image.isEmpty
        ? const ColoredBox(
            color: AppColors.surfaceAlt,
            child: Center(
              child: Icon(
                Icons.route_outlined,
                color: AppColors.cyan,
                size: 35,
              ),
            ),
          )
        : FirebaseMediaImage(imageUrl: image, fit: BoxFit.cover);
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children:[Expanded(child:Text(plan.title,maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:featured?19:15,fontWeight:FontWeight.w800))),RouteManagementMenu(plan:plan)]),
        const SizedBox(height: 6),
        Text(
          routeDate(plan),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              routeTransportIcon(plan.transport),
              size: 16,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${plan.transport} · ${plan.spotIds.length} durak',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        RouteMemberRow(ids: plan.memberIds),
      ],
    );
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.large),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadii.large),
          ),
          child: featured
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 155, child: thumbnail),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          summary,
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: () => _open(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.blue,
                              foregroundColor: Colors.white,
                            ),
                            label: const Text('Rotayı aç'),
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 78,
                          height: 92,
                          child: thumbnail,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: summary),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class RouteMemberRow extends StatelessWidget {
  const RouteMemberRow({super.key, required this.ids});
  final List<String> ids;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final id in ids.take(4))
        Padding(
          padding: const EdgeInsets.only(right: 3),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(id)
                .snapshots(),
            builder: (_, s) {
              final d = s.data?.data() ?? {};
              final url =
                  (d['photoUrl'] ?? d['photoURL'] ?? d['avatarUrl'] ?? '')
                      .toString();
              return CircleAvatar(
                radius: 13,
                backgroundColor: AppColors.surfaceStrong,
                backgroundImage: url.isEmpty ? null : NetworkImage(url),
                child: url.isEmpty
                    ? const Icon(
                        Icons.person_outline,
                        size: 16,
                        color: Colors.white70,
                      )
                    : null,
              );
            },
          ),
        ),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          '${ids.length} kişi',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ),
    ],
  );
}

class _SavedRoutes extends StatelessWidget {
  const _SavedRoutes();
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null)
      return const Text('Kaydettiğin rotaları görmek için giriş yap.');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('saved_routes')
          .snapshots(),
      builder: (_, s) {
        if (s.hasError) return Text(userFacingError(s.error!));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        if (s.data!.docs.isEmpty)
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Kaydettiğin rotalar burada görünecek.'),
          );
        return Column(
          children: s.data!.docs
              .map(
                (d) => FutureBuilder<TravelPlan>(
                  future: TravelPlanService.instance.read(d.id),
                  builder: (_, p) {
                    if (p.hasError)
                      return ListTile(
                        title: const Text('Bu rota artık erişilebilir değil'),
                        trailing: IconButton(
                          icon: const Icon(Icons.bookmark_remove_outlined),
                          onPressed: () =>
                              TravelPlanService.instance.bookmark(d.id, false),
                        ),
                      );
                    return p.hasData
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: RoutePreviewCard(plan: p.data!),
                          )
                        : const LinearProgressIndicator();
                  },
                ),
              )
              .toList(),
        );
      },
    );
  }
}

