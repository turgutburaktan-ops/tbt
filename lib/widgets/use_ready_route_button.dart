import 'package:flutter/material.dart';
import '../models/travel_plan.dart';
import '../services/travel_plan_service.dart';
import '../services/user_facing_error.dart';
import '../screens/travel_plan_detail_screen.dart';
import '../screens/ready_route_event_screen.dart';

class UseReadyRouteButton extends StatefulWidget {
  const UseReadyRouteButton({super.key, required this.plan, this.saveOnly = false});
  final TravelPlan plan;
  final bool saveOnly;
  @override
  State<UseReadyRouteButton> createState() => _UseReadyRouteButtonState();
}

class _UseReadyRouteButtonState extends State<UseReadyRouteButton> {
  bool _busy = false;
  String? _savedId;
  @override
  void didUpdateWidget(covariant UseReadyRouteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan.id != widget.plan.id) _savedId = null;
  }
  Future<void> _use() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!widget.saveOnly) {
        await Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => ReadyRouteEventScreen(plan: widget.plan),
        ));
        return;
      }
      final service = TravelPlanService.instance;
      final id = _savedId ?? await service.copyPlan(widget.plan);
      _savedId = id;
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
  Widget build(BuildContext context) {
    if (widget.saveOnly) return IconButton(
      tooltip: _savedId == null ? 'Planlarıma kaydet' : 'Planımı aç',
      onPressed: _busy ? null : _use,
      style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
      icon: Icon(_savedId == null ? Icons.bookmark_border : Icons.bookmark),
    );
    return SizedBox(width: double.infinity, child: FilledButton.icon(
      onPressed: _busy ? null : _use,
      icon: const Icon(Icons.event_available_outlined),
      label: Text(_busy ? 'Açılıyor…' : 'Etkinlik oluştur'),
    ));
  }
}
