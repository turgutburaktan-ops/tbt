import 'package:flutter/material.dart';

/// Child actions (author links, cards) win taps over story navigation.
class StoryNavigationSurface extends StatelessWidget {
  const StoryNavigationSurface({super.key, required this.child,
    required this.onPrevious, required this.onNext, required this.onPause,
    required this.onResume, this.onOpenShared});
  final Widget child;
  final VoidCallback onPrevious, onNext, onPause, onResume;
  final VoidCallback? onOpenShared;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) {
        final fraction = details.localPosition.dx / constraints.maxWidth;
        if (onOpenShared != null && fraction >= 1 / 6 && fraction <= 5 / 6) {
          onOpenShared!();
        } else if (fraction < .5) {
          onPrevious();
        } else {
          onNext();
        }
      },
      onLongPressStart: (_) => onPause(),
      onLongPressEnd: (_) => onResume(),
      onLongPressCancel: onResume,
      child: child,
    ),
  );
}
