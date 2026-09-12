import 'route_sharing_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/tbt_dialog.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/travel_plan.dart';
import '../services/travel_plan_service.dart';
import '../theme/app_theme.dart';
import 'travel_plan_detail_screen.dart';

class PublicTravelPlansScreen extends StatefulWidget {
  const PublicTravelPlansScreen({super.key});

  @override
  State<PublicTravelPlansScreen> createState() =>
      _PublicTravelPlansScreenState();
}

class _PublicTravelPlansScreenState extends State<PublicTravelPlansScreen> {
  String _query = '';
  String _filter = 'Tümü';

  Future<void> _rate(TravelPlan plan) async {
    final rating = await showTbtDialog<int>(
      context: context,
      builder: (dialogContext) => TbtDialog(
        title: const Text('Rotayı puanla'),
        content: Wrap(
          alignment: WrapAlignment.center,
          spacing: 2,
          runSpacing: 2,
          children: List.generate(
            5,
            (index) => IconButton(
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: () => Navigator.pop(dialogContext, index + 1),
              icon: const Icon(Icons.star_rounded, color: AppColors.warning),
            ),
          ),
        ),
      ),
    );
    if (rating == null) return;
    try {
      await TravelPlanService.instance.rate(plan.id, rating);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rotaya $rating yıldız verdin.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Puanlamak için giriş yapmalısın.')),
        );
      }
    }
  }

  Future<void> _copy(TravelPlan plan) async {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydetmek için giriş yapmalısın.')),
      );
      return;
    }
    try {
      final spots = await TravelPlanService.instance.resolveSpots(plan);
      await TravelPlanService.instance.create(
        title: '${plan.title} • Kopyam',
        city: plan.city,
        durationHours: plan.durationHours,
        budget: plan.budget,
        transport: plan.transport,
        interests: plan.interests,
        spots: spots,
        startAt: plan.startAt,
        distanceKm: plan.distanceKm,
        travelMinutes: plan.travelMinutes,
        estimatedBudget: plan.estimatedBudget,
        dayPlan: plan.dayPlan,
        stopDetails: plan.stopSnapshots,
        weatherSummary: plan.weatherSummary,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rota Rotalarım bölümüne kaydedildi.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Rota kaydedilemedi.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Rotaları keşfet')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Şehir veya rota adı ara',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.toLowerCase()),
            ),
          ),
          Wrap(
            spacing: 8,
            children: ['Tümü', 'Hazır rotalar', 'Birlikte gidelim']
                .map(
                  (v) => ChoiceChip(
                    label: Text(v),
                    selected: _filter == v,
                    onSelected: (_) => setState(() => _filter = v),
                  ),
                )
                .toList(),
          ),
          Expanded(
            child: StreamBuilder<List<TravelPlan>>(
              stream: TravelPlanService.instance.watchPublic(),
              builder: (_, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError)
                  return const Center(
                    child: Text(
                      'Rotalar yüklenemedi. İnternet bağlantını kontrol et.',
                    ),
                  );
                final plans = (snapshot.data ?? const <TravelPlan>[])
                    .where(
                      (plan) =>
                          _filter == 'Tümü' ||
                          (_filter == 'Birlikte gidelim'
                              ? plan.joinEnabled
                              : !plan.joinEnabled),
                    )
                    .where(
                      (plan) =>
                          _query.isEmpty ||
                          plan.title.toLowerCase().contains(_query) ||
                          plan.city.toLowerCase().contains(_query),
                    )
                    .toList();
                if (plans.isEmpty) {
                  return const Center(
                    child: Text('Henüz herkese açık rota yok.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (_, index) {
                    final plan = plans[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${plan.city} • ${plan.durationHours} saat • ${plan.spotNames.length} durak',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              plan.spotNames.join(' → '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: FirebaseFirestore.instance
                                  .collection('travel_plans')
                                  .doc(plan.id)
                                  .snapshots(),
                              builder: (_, s) {
                                final d = s.data?.data();
                                if (d == null || d['joinEnabled'] != true)
                                  return const SizedBox.shrink();
                                final start = (d['startAt'] as Timestamp?)
                                    ?.toDate();
                                final p = d['meetingPoint'] as Map?;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Birlikte gidelim · ${start == null ? '' : '${start.day}.${start.month} ${TimeOfDay.fromDateTime(start).format(context)}'}',
                                    ),
                                    Text(p?['label']?.toString() ?? ''),
                                    RouteParticipation(
                                      routeId: plan.id,
                                      data: d,
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _rate(plan),
                                  icon: const Icon(Icons.star_outline_rounded),
                                  label: const Text('Puanla'),
                                ),
                                TextButton.icon(
                                  onPressed: () => _copy(plan),
                                  icon: const Icon(Icons.bookmark_add_outlined),
                                  label: const Text('Kaydet'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          TravelPlanDetailScreen(plan: plan),
                                    ),
                                  ),
                                  child: const Text('İncele'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
