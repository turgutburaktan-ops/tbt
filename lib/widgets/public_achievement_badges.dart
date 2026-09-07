import 'package:flutter/material.dart';

class PublicAchievementBadges extends StatelessWidget {
  final Map<String, dynamic> profile;
  final bool showAll;

  const PublicAchievementBadges({
    super.key,
    required this.profile,
    this.showAll = false,
  });

  static const _catalog = <_BadgeDefinition>[
    _BadgeDefinition('verified', 'Doğrulanmış', Icons.verified_rounded, Color(0xFF48C7FF), 0),
    _BadgeDefinition('turkiye_explorer', 'Türkiye Kaşifi', Icons.public_rounded, Color(0xFFFFC857), 6000),
    _BadgeDefinition('master_explorer', 'Usta Kaşif', Icons.workspace_premium_rounded, Color(0xFFC89BFF), 3000),
    _BadgeDefinition('local_guide', 'Yerel Rehber', Icons.explore_rounded, Color(0xFF55D6BE), 1500),
    _BadgeDefinition('photo_hunter', 'Fotoğraf Avcısı', Icons.photo_camera_rounded, Color(0xFFFF8FA3), 600),
    _BadgeDefinition('explorer', 'Kaşif', Icons.hiking_rounded, Color(0xFF8EA7FF), 200),
  ];

  List<_BadgeDefinition> _earned() {
    final xp = (profile['xp'] as num?)?.toInt() ?? 0;
    final verified = profile['identityVerified'] == true || profile['verified'] == true;
    final selected = (profile['selectedBadgeIds'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toSet();
    final result = _catalog.where((badge) {
      if (badge.id == 'verified') return verified;
      return xp >= badge.requiredXp;
    }).toList();
    if (selected.isNotEmpty) {
      result.sort((a, b) {
        final ai = selected.contains(a.id) ? 0 : 1;
        final bi = selected.contains(b.id) ? 0 : 1;
        return ai.compareTo(bi);
      });
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final earned = _earned();
    if (earned.isEmpty) return const SizedBox.shrink();
    final visible = showAll ? earned : earned.take(3).toList();
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: visible.map((badge) => _PublicBadge(badge: badge)).toList(),
    );
  }
}

class _PublicBadge extends StatelessWidget {
  final _BadgeDefinition badge;
  const _PublicBadge({required this.badge});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(7, 5, 9, 5),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [badge.color.withValues(alpha: .22), const Color(0xFF151820)],
      ),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: badge.color.withValues(alpha: .55)),
      boxShadow: [
        BoxShadow(color: badge.color.withValues(alpha: .10), blurRadius: 10),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(badge.icon, size: 14, color: badge.color),
        const SizedBox(width: 5),
        Text(
          badge.label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class _BadgeDefinition {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final int requiredXp;
  const _BadgeDefinition(this.id, this.label, this.icon, this.color, this.requiredXp);
}
