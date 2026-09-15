import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BusinessEditorSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget content;
  final List<Widget> actions;

  const BusinessEditorSheet({super.key, required this.title, required this.content, required this.actions, this.subtitle = 'Bilgileri eksiksiz doldur ve yayınlamadan önce kontrol et.', this.icon = Icons.storefront_rounded});

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99))),
                  const SizedBox(height: 18),
                  Row(children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.cyan.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: AppColors.cyan)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.3)),
                    ])),
                    IconButton(tooltip: 'Kapat', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ]),
                  const SizedBox(height: 18),
                  Flexible(child: content),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
