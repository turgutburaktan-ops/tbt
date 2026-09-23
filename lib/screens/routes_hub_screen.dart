import '../widgets/use_ready_route_button.dart';
import '../services/nearby_venue_service.dart';
import '../data/turkey_selection_data.dart';
import '../widgets/route_bookmark_button.dart';

import 'package:geolocator/geolocator.dart';

import '../services/route_draft_store.dart';
import 'route_filters_screen.dart';
import '../widgets/route_design/route_design.dart';
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
  Position? _nearby;
  bool _nearbyBusy = false;
  RouteFilters _parkurFilters = const RouteFilters();
  late final _mine = TravelPlanService.instance.watchMine();
  late final _public = TravelPlanService.instance.watchPublic(
    discoverOnly: true,
  );
  final _followersPlans = <String, List<TravelPlan>>{};
  final _subscriptions =
      <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _following;
  @override
  void initState() {
    super.initState();
    final cityService = NearbyVenueService.instance;
    _parkurFilters = _parkurFilters.withCity(cityService.selectedCityName ?? '');
    cityService.selectedCityChanges.addListener(_onSelectedCityChanged);
    unawaited(cityService.restoreSelectedCity().catchError((Object _) => null));
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

  void _onSelectedCityChanged() {
    if (!mounted) return;
    setState(() => _parkurFilters = _parkurFilters.withCity(
      NearbyVenueService.instance.selectedCityName ?? '',
    ));
  }

  @override
  void dispose() {
    NearbyVenueService.instance.selectedCityChanges.removeListener(_onSelectedCityChanged);
    _following?.cancel();
    for (final s in _subscriptions.values) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _nearMe() async {
    if (_nearby != null) {
      setState(() => _nearby = null);
      return;
    }
    if (_nearbyBusy) return;
    setState(() => _nearbyBusy = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled())
        throw Exception('Konum hizmetini aç.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        throw Exception(
          'Konum izni verilmedi. Bölge filtresini kullanabilirsin.',
        );
      final location = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 15),
      );
      if (mounted) setState(() => _nearby = location);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _nearbyBusy = false);
    }
  }

  bool _isNearby(TravelPlan p) {
    if (_nearby == null) return true;
    final point = p.routeOrigin.isNotEmpty
        ? p.routeOrigin
        : p.stopSnapshots.firstOrNull;
    if (point == null ||
        point['latitude'] is! num ||
        point['longitude'] is! num)
      return false;
    return Geolocator.distanceBetween(
          _nearby!.latitude,
          _nearby!.longitude,
          (point['latitude'] as num).toDouble(),
          (point['longitude'] as num).toDouble(),
        ) <=
        50000;
  }

  Future<void> _create() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RouteCreateScreen()),
    );
    if (mounted) setState(() {});
  }

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
                title: 'Rota',
                action: IconButton(
                  tooltip: 'Kaydedilen rotalar',
                  icon: const Icon(Icons.bookmark_border),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Kaydedilen rotalar')),
                        body: const SingleChildScrollView(
                          padding: EdgeInsets.all(16),
                          child: _SavedRoutes(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bugün hangi yoldan gidelim?',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              RouteAction(
                label: 'Rota oluştur',
                icon: Icons.add,
                onPressed: _create,
              ),
              const SizedBox(height: 18),
              if (_tab == 1 && upcoming.isNotEmpty) ...[
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
                labels: const ['Keşfet', 'Rotalarım'],
                selected: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 14),
              if (_tab == 1) ...[
                Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < 3; i++)
                      ChoiceChip(
                        label: Text(
                          ['Planlanan', 'Tamamlanan', 'Taslaklar'][i],
                        ),
                        selected: _filter == i,
                        onSelected: (_) => setState(() => _filter = i),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_filter == 2)
                  FutureBuilder<Map<String, dynamic>?>(
                    future: FirebaseAuth.instance.currentUser == null
                        ? Future.value(null)
                        : RouteDraftStore.read(
                            FirebaseAuth.instance.currentUser!.uid,
                          ),
                    builder: (c, s) => s.data == null
                        ? _message(
                            'Henüz taslağın yok. Yeni rota oluşturarak başlayabilirsin.',
                          )
                        : RoutePanel(
                            child: ListTile(
                              leading: const Icon(Icons.edit_note),
                              title: Text(
                                (s.data!['title'] ?? 'Rota taslağı').toString(),
                              ),
                              subtitle: const Text('Kaldığın yerden devam et'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _create,
                            ),
                          ),
                  )
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
                    hintText: 'Şehir veya parkur ara',
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
                    final cities = turkeyCities;
                    final filtered = all
                        .where(
                          (p) =>
                              _isNearby(p) &&
                              _parkurFilters.matches(
                                p,
                                _subscriptions.keys.toSet(),
                              ) &&
                              '${p.title} ${p.city} ${p.spotNames.join(' ')}'
                                  .toLowerCase()
                                  .contains(_search.toLowerCase()),
                        )
                        .toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          key: ValueKey(_parkurFilters.city),
                          initialValue: _parkurFilters.city,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'İl', prefixIcon: Icon(Icons.location_city)),
                          items: [
                            const DropdownMenuItem(value: '', child: Text('Tüm iller')),
                            for (final city in cities)
                              DropdownMenuItem(value: city, child: Text(city)),
                          ],
                          onChanged: (city) => setState(() => _parkurFilters = _parkurFilters.withCity(city ?? '')),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: FilterChip(
                                        label: Text(
                                          _nearbyBusy
                                              ? 'Konum alınıyor…'
                                              : 'Yakınımda',
                                        ),
                                        selected: _nearby != null,
                                        onSelected: (_) => _nearMe(),
                                      ),
                                    ),
                                    for (final mode in [
                                      'Yürüyüş',
                                      'Bisiklet',
                                      'Araç',
                                    ])
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: FilterChip(
                                          label: Text(mode),
                                          selected: _parkurFilters.mode == mode,
                                          onSelected: (v) => setState(
                                            () => _parkurFilters = RouteFilters(
                                              mode: v ? mode : '',
                                              city: _parkurFilters.city,
                                              maxKm: _parkurFilters.maxKm,
                                              duration: _parkurFilters.duration,
                                              roundTrip:
                                                  _parkurFilters.roundTrip,
                                              following:
                                                  _parkurFilters.following,
                                              difficulties:
                                                  _parkurFilters.difficulties,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Parkur filtreleri',
                              icon: const Icon(Icons.tune),
                              onPressed: () async {
                                final value =
                                    await Navigator.push<RouteFilters>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RouteFiltersScreen(
                                          value: _parkurFilters,
                                          cities: cities,
                                        ),
                                      ),
                                    );
                                if (mounted && value != null)
                                  setState(() => _parkurFilters = value);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (filtered.any((p) => p.isCurated)) ...[
                          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('TBT’den hazır rotalar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                          ..._list(filtered.where((p) => p.isCurated).toList()),
                        ],
                        if (filtered.any((p) => !p.isCurated)) ...[
                          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Topluluktan rotalar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                          ..._list(filtered.where((p) => !p.isCurated).toList()),
                        ],
                        if (filtered.isEmpty) _message(_parkurFilters.city.isEmpty ? 'Bu filtrelere uygun rota bulunamadı.' : '${_parkurFilters.city} için bu filtrelere uygun rota bulunamadı.'),
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
            _tab == 0
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
                child: RoutePreviewCard(plan: p, featured: true),
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
        Row(
          children: [
            Expanded(
              child: Text(
                plan.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: featured ? 19 : 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            RouteManagementMenu(plan: plan),
          ],
        ),
        const SizedBox(height: 6),
        if (plan.ownerName.isNotEmpty)
          Text(
            plan.isCurated ? 'TBT · Hazır rota' : plan.ownerName,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        Text(
          plan.isCurated ? 'İstediğin gün kullan · Yaklaşık ${plan.durationHours} saat gezi' : routeDate(plan),
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
                '${plan.distanceKm > 0 ? '${plan.distanceKm.toStringAsFixed(1)} km · ' : ''}${plan.travelMinutes > 0 ? '${plan.travelMinutes} dk · ' : ''}${plan.spotIds.length} durak',
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
        if (['Yürüyüş', 'Bisiklet'].contains(plan.transport) &&
            (plan.dayPlan['difficulty'] ?? '').toString().isNotEmpty)
          Text(
            'Tahmini zorluk: ${plan.dayPlan['difficulty']}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        RouteBookmarkButton(routeId: plan.id),
        if (plan.isCurated) UseReadyRouteButton(plan: plan),
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
                    SizedBox(height: 175, child: thumbnail),
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
                              backgroundColor: AppColors.selection,
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
