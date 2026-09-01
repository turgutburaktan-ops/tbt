import 'package:flutter/material.dart';

class VenueBadgeStrip extends StatelessWidget {
  final bool verified;
  final double rating;
  final int ratingCount;
  final String category;
  final Iterable<String> tags;
  final bool premium;

  const VenueBadgeStrip({
    super.key,
    required this.verified,
    required this.rating,
    this.ratingCount = 0,
    required this.category,
    this.tags = const [],
    this.premium = false,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = '${category.toLowerCase()} ${tags.join(' ').toLowerCase()}';
    final badges = <_VenueBadge>[
      if (verified) const _VenueBadge('Doğrulanmış', Icons.verified_rounded, Color(0xFF48C7FF)),
      if (premium) const _VenueBadge('Premium İşletme', Icons.diamond_rounded, Color(0xFFFFC857)),
      if (rating >= 4.6 && (ratingCount == 0 || ratingCount >= 10))
        const _VenueBadge('Yüksek Puanlı', Icons.star_rounded, Color(0xFFFFC857)),
      if (normalized.contains('foto') || normalized.contains('manzara'))
        const _VenueBadge('Fotoğraf Noktası', Icons.photo_camera_rounded, Color(0xFFC89BFF)),
      if (normalized.contains('kafe') || normalized.contains('restoran') || normalized.contains('lezzet'))
        const _VenueBadge('Lezzet Durağı', Icons.restaurant_rounded, Color(0xFFFF8A65)),
      if (normalized.contains('gizli') || normalized.contains('yerel'))
        const _VenueBadge('Gizli Cevher', Icons.auto_awesome_rounded, Color(0xFF55D6BE)),
      if (normalized.contains('aile'))
        const _VenueBadge('Aile Dostu', Icons.family_restroom_rounded, Color(0xFF6DE4A8)),
      if (normalized.contains('erişilebilir') || normalized.contains('engelli'))
        const _VenueBadge('Erişilebilir', Icons.accessible_rounded, Color(0xFF8EA7FF)),
    ];
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: badges.take(4).map((badge) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: badge.color.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: badge.color.withValues(alpha: .42)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(badge.icon, size: 14, color: badge.color),
            const SizedBox(width: 5),
            Text(badge.label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
          ],
        ),
      )).toList(),
    );
  }
}

class _VenueBadge {
  final String label;
  final IconData icon;
  final Color color;
  const _VenueBadge(this.label, this.icon, this.color);
}
