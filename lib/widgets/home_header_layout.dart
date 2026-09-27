import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Equal side columns keep the camera at the screen centre, independent of
/// the logo width and unread badges. Side actions share available space.
class HomeHeaderLayout extends StatelessWidget {
  const HomeHeaderLayout({super.key, required this.leading, required this.actions, required this.onCreate});
  final Widget leading;
  final List<Widget> actions;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 5, 8, 4),
    child: Row(children: [
      Expanded(child: leading),
      const SizedBox(width: 4),
      Tooltip(
        message: 'Paylaşım oluştur',
        child: Semantics(
          button: true,
          label: 'Paylaşım oluştur',
          enabled: onCreate != null,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              boxShadow: [BoxShadow(color: AppColors.brandCyan.withValues(alpha: .16), blurRadius: 12)],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(17),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: const BoxDecoration(gradient: AppColors.accentGradient),
                child: InkWell(
                  onTap: onCreate,
                  child: const Center(child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28)),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 4),
      Expanded(child: Row(children: [for (final action in actions) Expanded(child: action)])),
    ]),
  );
}

class HomeHeaderAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final int count;
  const HomeHeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
    padding: const EdgeInsets.all(8),
    icon: Badge(
      isLabelVisible: count > 0,
      backgroundColor: AppColors.violet,
      label: Text(count > 99 ? '99+' : '$count', textScaler: TextScaler.noScaling, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
      child: Icon(icon, color: Colors.white70, size: 20),
    ),
  );
}

