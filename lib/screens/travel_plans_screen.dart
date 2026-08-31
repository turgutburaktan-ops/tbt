import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/travel_plan.dart';
import '../services/travel_plan_service.dart';
import '../theme/app_theme.dart';
import 'route_planner_screen.dart';
import 'smart_plan_screen.dart';
import 'travel_plan_invite_screen.dart';

class TravelPlansScreen extends StatelessWidget {
  const TravelPlansScreen({super.key});

  Future<void> _openRoute(BuildContext context, TravelPlan plan) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Rota hazırlanıyor…')));
    try {
      final spots = await TravelPlanService.instance.resolveSpots(plan);
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      if (spots.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Bu planın durakları bulunamadı.')),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoutePlannerScreen(initialSpots: spots),
        ),
      );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Rota açılamadı. Tekrar dene.')),
        );
    }
  }

  Future<void> _delete(BuildContext context, TravelPlan plan) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Plan silinsin mi?'),
        content: Text('${plan.title} kalıcı olarak silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    try {
      await TravelPlanService.instance.delete(plan.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan silinemedi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Planlarım')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SmartPlanScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yeni plan'),
      ),
      body: StreamBuilder<List<TravelPlan>>(
        stream: TravelPlanService.instance.watchMine(),
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const _PlansMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Planlar yüklenemedi',
              body: 'Bağlantını kontrol edip tekrar dene.',
            );
          }
          final plans = snapshot.data ?? const <TravelPlan>[];
          if (plans.isEmpty) {
            return const _PlansMessage(
              icon: Icons.route_outlined,
              title: 'Henüz planın yok',
              body: 'Akıllı plan oluşturduğunda veya bir plana davet edildiğinde burada görünecek.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
            itemCount: plans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final plan = plans[index];
              final owned = plan.ownerId == currentUser?.uid;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: AppColors.subtleGradient,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(Icons.route_rounded),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                '${plan.city} • ${plan.durationHours} saat • ${plan.transport}',
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
                            tooltip: 'Planı sil',
                            onPressed: () => _delete(context, plan),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      plan.spotNames.join('  →  '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          owned ? Icons.person_rounded : Icons.mail_rounded,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          owned
                              ? '${plan.memberIds.length - 1} davetli'
                              : 'Davet edildiğin plan',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                        const Spacer(),
                        if (owned)
                          TextButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TravelPlanInviteScreen(
                                  planId: plan.id,
                                  planTitle: plan.title,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.group_add_rounded, size: 18),
                            label: const Text('Davet'),
                          ),
                        const SizedBox(width: 5),
                        FilledButton(
                          onPressed: () => _openRoute(context, plan),
                          child: const Text('Rotayı Aç'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PlansMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PlansMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: Colors.white30),
            const SizedBox(height: 12),
            Text(
              title,
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
}
