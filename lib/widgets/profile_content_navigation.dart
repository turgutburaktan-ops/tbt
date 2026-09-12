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
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
    child: SegmentedButton<String>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: 'all', label: Text('Paylaşımlar')),
        ButtonSegment(value: 'reposts', label: Text('Yeniden paylaşımlar')),
        ButtonSegment(value: 'saved', label: Text('Kaydedilenler')),
      ],
      selected: {selected},
      onSelectionChanged: (values) => onChanged(values.first),
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
      color: const Color(0xFF13161C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Color(0xFF2C3240)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        leading: const Icon(
          Icons.workspace_premium_rounded,
          color: Color(0xFFB8A1FF),
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
