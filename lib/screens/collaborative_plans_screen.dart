import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/travel_plan.dart';
import '../services/travel_plan_service.dart';
import '../theme/app_theme.dart';
import 'smart_plan_screen.dart';
import 'travel_plan_detail_screen.dart';
import 'travel_plan_invite_screen.dart';

class CollaborativePlansScreen extends StatefulWidget {
  const CollaborativePlansScreen({super.key});

  @override
  State<CollaborativePlansScreen> createState() =>
      _CollaborativePlansScreenState();
}

class _CollaborativePlansScreenState extends State<CollaborativePlansScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ortak Planlar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SmartPlanScreen(inviteAfterSave: true),
          ),
        ),
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('Yeni ortak plan'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Arkadaşlarınla hazırladığın rotalar, davetler, oylamalar ve plan sohbetleri.',
                style: TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Tümü')),
                ButtonSegment(value: 1, label: Text('Benim')),
                ButtonSegment(value: 2, label: Text('Davetler')),
              ],
              selected: {_filter},
              onSelectionChanged: (value) =>
                  setState(() => _filter = value.first),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<TravelPlan>>(
              stream: TravelPlanService.instance.watchMine(),
              builder: (_, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const _CollaborativeEmpty(
                    icon: Icons.cloud_off_rounded,
                    title: 'Ortak planlar yüklenemedi',
                    body: 'Bağlantını kontrol edip tekrar dene.',
                  );
                }
                final plans = (snapshot.data ?? const <TravelPlan>[])
                    .where((plan) => plan.memberIds.length > 1)
                    .where((plan) {
                      if (_filter == 1) return plan.ownerId == uid;
                      if (_filter == 2) return plan.ownerId != uid;
                      return true;
                    })
                    .toList();
                if (plans.isEmpty) {
                  return const _CollaborativeEmpty(
                    icon: Icons.groups_2_outlined,
                    title: 'Henüz ortak plan yok',
                    body:
                        'Yeni ortak plan oluşturabilir veya arkadaşının davetini burada görebilirsin.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final plan = plans[index];
                    final owned = plan.ownerId == uid;
                    return Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TravelPlanDetailScreen(plan: plan),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    child: Icon(Icons.groups_2_rounded),
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          plan.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          owned
                                              ? 'Sen oluşturdun'
                                              : 'Bu plana davet edildin',
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (owned)
                                    IconButton(
                                      tooltip: 'Arkadaş davet et',
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              TravelPlanInviteScreen(
                                                planId: plan.id,
                                                planTitle: plan.title,
                                              ),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.person_add_alt_1_rounded,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${plan.city} • ${plan.durationHours} saat • ${plan.spotNames.length} durak',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.people_alt_outlined,
                                    size: 17,
                                    color: AppColors.cyan,
                                  ),
                                  const SizedBox(width: 5),
                                  Text('${plan.memberIds.length} kişi'),
                                  const Spacer(),
                                  const Text(
                                    'Sohbet ve oylamayı aç',
                                    style: TextStyle(
                                      color: AppColors.cyan,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.cyan,
                                  ),
                                ],
                              ),
                            ],
                          ),
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

class _CollaborativeEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _CollaborativeEmpty({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 58, color: Colors.white30),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, height: 1.4),
          ),
        ],
      ),
    ),
  );
}
