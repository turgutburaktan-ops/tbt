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
