import 'package:flutter/material.dart';

class ProfileRewardSurface extends StatelessWidget {
  final Map<String, dynamic> profile;
  final Widget child;
  final BorderRadius borderRadius;

  const ProfileRewardSurface({
    super.key,
    required this.profile,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
  });

  @override
  Widget build(BuildContext context) {
    final theme = (profile['selectedProfileTheme'] ?? 'default').toString();
    final colors = switch (theme) {
      'aurora' => const [Color(0x5538E8FF), Color(0x334A7DFF), Color(0x229B4DFF)],
      'sunset' => const [Color(0x55FF8A65), Color(0x33FF5C8A), Color(0x22100F18)],
      'midnight' => const [Color(0x554F6CFF), Color(0x332B235B), Color(0x22090A0C)],
      'emerald' => const [Color(0x5544D7A8), Color(0x33204C45), Color(0x22090A0C)],
      _ => const <Color>[],
    };
    if (colors.isEmpty) return child;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: borderRadius,
        border: Border.all(color: colors.first.withValues(alpha: .7)),
      ),
      child: child,
    );
  }
}
