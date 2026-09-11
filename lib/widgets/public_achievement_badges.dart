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
    _BadgeDefinition('ambassador', 'TBT Elçisi', Icons.workspace_premium_rounded, Color(0xFFFFC857)),
    _BadgeDefinition('verified', 'Doğrulanmış', Icons.verified_rounded, Color(0xFF48C7FF)),
    _BadgeDefinition('creator', 'Creator', Icons.auto_awesome_rounded, Color(0xFFA66BFF)),
    _BadgeDefinition('explorer', 'Kâşif', Icons.explore_rounded, Color(0xFF55D6BE)),
    _BadgeDefinition('social', 'Sosyal', Icons.groups_rounded, Color(0xFFFF8A65)),
    _BadgeDefinition('gourmet', 'Gurme', Icons.restaurant_rounded, Color(0xFFFFD166)),
  ];

  List<_BadgeDefinition> _earned() {
    final rawRoles = profile['accountTypes'];
    final roles = rawRoles is Map
        ? Map<String, dynamic>.from(rawRoles)
        : const <String, dynamic>{};
    final verified = profile['tbtVerified'] == true;
    final ambassador = profile['tbtAmbassador'] == true;
    final selected = (profile['selectedBadgeIds'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toSet();
    final result = _catalog.where((badge) {
      if (badge.id == 'verified') return verified;
      if (badge.id == 'ambassador') return ambassador;
      if (badge.id == 'creator' && profile['isCreator'] == true) return true;
      final state = roles[badge.id];
      return state is Map && state['active'] == true;
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
  const _BadgeDefinition(this.id, this.label, this.icon, this.color);
}
