import 'package:flutter/material.dart';

import 'user_profile_screen.dart';

class MentionProfileScreen extends StatelessWidget {
  final String userId;

  const MentionProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return UserProfileScreen(userId: userId);
  }
}
