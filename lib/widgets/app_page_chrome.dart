import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared page hierarchy. Actions wrap below the title on narrow/large-text screens.
class AppPageHeading extends StatelessWidget {
  const AppPageHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final heading = Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium,
          );
          if (action == null) return heading;
          if (constraints.maxWidth < 340 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(height: AppSpacing.gap),
                action!,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: heading),
              const SizedBox(width: AppSpacing.gap),
              action!,
            ],
          );
        },
      ),
      if (subtitle != null) ...[
        const SizedBox(height: AppSpacing.small),
        Text(
          subtitle!,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.textMuted),
        ),
      ],
    ],
  );
}

class AppSectionTabs extends StatelessWidget {
  const AppSectionTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < labels.length; i++)
        Expanded(
          child: Semantics(
            selected: selected == i,
            button: true,
            child: InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(AppRadii.small),
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: AppSpacing.controlHeight,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected == i ? AppColors.cyan : AppColors.border,
                      width: selected == i ? 2 : 1,
                    ),
                  ),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected == i ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
