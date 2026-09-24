import 'package:flutter/material.dart';
import '../models/travel_plan.dart';
import '../services/travel_plan_service.dart';
import '../services/user_facing_error.dart';
import '../screens/travel_plan_detail_screen.dart';

class UseReadyRouteButton extends StatefulWidget {
  const UseReadyRouteButton({super.key, required this.plan});
  final TravelPlan plan;
  @override
  State<UseReadyRouteButton> createState() => _UseReadyRouteButtonState();
}

class _UseReadyRouteButtonState extends State<UseReadyRouteButton> {
  bool _busy = false;
  Future<void> _use() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final service = TravelPlanService.instance;
      final id = await service.copyPlan(widget.plan);
      final plan = await service.read(id);
      if (mounted) await Navigator.push(context, MaterialPageRoute<void>(
        builder: (_) => TravelPlanDetailScreen(plan: plan),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: _busy ? null : _use,
    icon: const Icon(Icons.route_outlined),
    label: Text(_busy ? 'Oluşturuluyor…' : 'Rotayı kullan'),
  );
}
