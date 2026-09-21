import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class RouteAction extends StatelessWidget {
  const RouteAction({super.key, required this.label, required this.onPressed, this.outlined = false, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final child = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 8)],
      Flexible(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
    ]);
    if (outlined) return OutlinedButton(onPressed: onPressed,
      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 52), foregroundColor: AppColors.cyan,
        side: const BorderSide(color: AppColors.cyan), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: child);
    return DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
      gradient: onPressed == null ? null : const LinearGradient(colors: [Color(0xFF22CBD5), Color(0xFF6950EC)]),
      color: onPressed == null ? AppColors.surface : null), child: FilledButton(
        onPressed: onPressed, style: FilledButton.styleFrom(backgroundColor: Colors.transparent,
          foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: child));
  }
}

class RouteModePicker extends StatelessWidget {
  const RouteModePicker({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String>? onChanged;
  static IconData icon(String mode) => mode == 'Yürüyüş' ? Icons.directions_walk : mode == 'Bisiklet' ? Icons.directions_bike : Icons.directions_car_outlined;
  @override
  Widget build(BuildContext context) => Row(children: [for (final mode in ['Araç','Yürüyüş','Bisiklet'])
    Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: InkWell(
      borderRadius: BorderRadius.circular(16), onTap: onChanged == null ? null : () => onChanged!(mode),
      child: Container(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 3),
        decoration: BoxDecoration(color: value == mode ? AppColors.selection : AppColors.surface,
          border: Border.all(color: value == mode ? AppColors.cyan : AppColors.border), borderRadius: BorderRadius.circular(16)),
        child: Column(children: [Icon(icon(mode), color: value == mode ? AppColors.cyan : AppColors.textMuted),
          const SizedBox(height: 6), Text(mode, maxLines: 1, style: TextStyle(fontSize: 12, color: value == mode ? AppColors.cyan : AppColors.textMuted))])))))]);
}

class RoutePanel extends StatelessWidget {
  const RoutePanel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(padding: padding,
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: child);
}
