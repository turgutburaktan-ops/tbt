import 'package:flutter/material.dart';
import '../screens/user_profile_screen.dart';

class ProfileNameLink extends StatelessWidget {
  const ProfileNameLink({super.key, required this.userId, required this.child,
    this.compact = false, this.onOpening, this.onReturned});
  final String userId;
  final Widget child;
  final bool compact;
  final VoidCallback? onOpening, onReturned;

  static Future<void> open(BuildContext context, String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return;
    final routeName = '/profile/$id';
    if (ModalRoute.of(context)?.settings.name == routeName) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push(MaterialPageRoute<void>(
      settings: RouteSettings(name: routeName),
      builder: (_) => UserProfileScreen(userId: id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (userId.trim().isEmpty) return child;
    return Semantics(
      link: true,
      child: InkWell(
        onTap: () async {
          onOpening?.call();
          try {
            await open(context, userId);
          } finally {
            if (context.mounted) onReturned?.call();
          }
        },
        child: compact ? child : ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Align(alignment: Alignment.centerLeft, child: child)),
      ),
    );
  }
}
