import 'package:flutter/material.dart';

import 'event_create_screen_v2.dart';

/// Backward-compatible entry point used by existing event buttons.
/// The actual screen keeps all event options and requires a cover photo.
class EventPhotoCreateScreen extends StatelessWidget {
  const EventPhotoCreateScreen({super.key});

  @override
  Widget build(BuildContext context) => const EventCreateScreenV2();
}
