import 'package:flutter/material.dart';

import '../models/travel_plan.dart';
import '../services/travel_plan_service.dart';
import '../screens/route_sharing_screen.dart';

class RoutePublishButton extends StatefulWidget {
  const RoutePublishButton({super.key, required this.plan});
  final TravelPlan plan;
  @override
  State<RoutePublishButton> createState() => _RoutePublishButtonState();
}

class _RoutePublishButtonState extends State<RoutePublishButton> {
  bool _busy = false;
  Future<void> _change() async {
    final plan = widget.plan;
    if (!plan.isPublic) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RouteSharingScreen(routeId: plan.id, title: plan.title),
        ),
      );
      return;
    }
    final publish = !plan.discoverPublished;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(publish ? 'Keşfet’te yayınla' : 'Keşfet’ten kaldır'),
        content: Text(
          publish
              ? 'Rota adı, açıklaması, başlangıç noktası ve durakları herkese gösterilecek. Başkaları rotayı kaydedebilir ve kendi planına kopyalayabilir. Katılım için belirlediğin koşullar geçerli kalır.'
              : 'Rota Keşfet listesinden kaldırılacak. Bağlantıyla erişim görünürlük ayarına bağlıdır. Tamamen gizlemek için görünürlüğü de değiştir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(publish ? 'Yayınla' : 'Kaldır'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await TravelPlanService.instance.setDiscoverPublished(plan.id, publish);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              publish
                  ? 'Rotan Rota → Keşfet’te yayınlandı.'
                  : 'Rota Keşfet’ten kaldırıldı.',
            ),
          ),
        );
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
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.plan.discoverPublished
                ? 'Rotan Keşfet’te yayında'
                : 'Rotanı toplulukla paylaş',
          ),
          const SizedBox(height: 6),
          Text(
            widget.plan.isPublic ? 'Katılım ve yayınlama ayrı ayarlardır.' : 'Keşfet’te yayınlamak için önce görünürlüğü Herkes yapmalısın.',
          ),
          TextButton.icon(
            onPressed: _busy ? null : _change,
            icon: const Icon(Icons.explore_outlined),
            label: Text(
              _busy
                  ? 'Kaydediliyor…'
                  : !widget.plan.isPublic
                  ? 'Görünürlüğü düzenle'
                  : widget.plan.discoverPublished
                  ? 'Keşfet’ten kaldır'
                  : 'Keşfet’te yayınla',
            ),
          ),
        ],
      ),
    ),
  );
}
