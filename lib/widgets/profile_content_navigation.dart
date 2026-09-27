import '../theme/app_theme.dart';
import 'app_page_chrome.dart';

import 'package:flutter/material.dart';

/// Text labels stay visible on narrow screens without squeezing the tabs.
class ProfileContentNavigation extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const ProfileContentNavigation({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.page,
      0,
      AppSpacing.page,
      AppSpacing.small,
    ),
    child: AppSectionTabs(
      labels: const ['Tümü', 'Rotalarım', 'Favoriler'],
      selected: const ['all', 'routes', 'favorites'].indexOf(selected),
      onChanged: (index) =>
          onChanged(const ['all', 'routes', 'favorites'][index]),
    ),
  );
}

class ProfileJourneyRow extends StatelessWidget {
  final int points;
  final VoidCallback onTap;
  const ProfileJourneyRow({
    super.key,
    required this.points,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
    child: Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.large),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        leading: const Icon(
          Icons.workspace_premium_rounded,
          color: AppColors.primary,
        ),
        title: const Text(
          'TBT Yolculuğu',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '$points gerçek katkı puanı',
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Colors.white54,
        ),
        onTap: onTap,
      ),
    ),
  );
}
