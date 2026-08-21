import 'package:flutter/material.dart';

import '../models/route_place.dart';
import '../screens/selected_route_map_screen.dart';
import '../services/route_selection_service.dart';

class RouteSelectionButton extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const RouteSelectionButton({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, RoutePlace>>(
      valueListenable: RouteSelectionService.instance.selected,
      builder: (context, selected, _) {
        if (selected.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: padding,
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SelectedRouteMapScreen(
                          places: selected.values.toList(growable: false),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.route_rounded),
                  label: Text('Rotaya Git (${selected.length})'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Rota seçimlerini temizle',
                onPressed: RouteSelectionService.instance.clear,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        );
      },
    );
  }
}
