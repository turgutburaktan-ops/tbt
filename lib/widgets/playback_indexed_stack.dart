import 'package:flutter/material.dart';

/// Retains tab state, while inactive tabs cannot own media playback.
class PlaybackIndexedStack extends StatelessWidget {
  const PlaybackIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });
  final int index;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => IndexedStack(
    index: index,
    children: [
      for (var i = 0; i < children.length; i++)
        TickerMode(enabled: i == index, child: children[i]),
    ],
  );
}
