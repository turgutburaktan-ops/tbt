import 'package:flutter/material.dart';

import '../models/route_place.dart';
import '../screens/selected_route_map_screen.dart';
import '../services/route_selection_service.dart';
import '../theme/app_theme.dart';

class RouteSelectionButton extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const RouteSelectionButton({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(14, 4, 14, 8),
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, RoutePlace>>(
      valueListenable: RouteSelectionService.instance.selected,
      builder: (context, selected, _) {
        if (selected.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: padding,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      backgroundColor: AppColors.surfaceStrong,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
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
                    icon: const Icon(Icons.route_rounded, size: 19),
                    label: Text(
                      'Rotaya Git  •  ${selected.length}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Rota seçimlerini temizle',
                  onPressed: RouteSelectionService.instance.clear,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    foregroundColor: Colors.white54,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
