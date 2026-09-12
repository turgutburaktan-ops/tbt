import 'package:flutter/material.dart';
import '../screens/user_profile_screen.dart';

class ProfileNameLink extends StatelessWidget {
  const ProfileNameLink({super.key, required this.userId, required this.child});
  final String userId;
  final Widget child;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: userId.trim().isEmpty ? null : () {
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => UserProfileScreen(userId: userId.trim()),
      ));
    },
    child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 44),
      child: Align(alignment: Alignment.centerLeft, child: child)),
  );
}
