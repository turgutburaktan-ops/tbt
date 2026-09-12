import 'package:flutter/material.dart';
import 'app_video_player.dart';
import 'profile_name_link.dart';

/// Presentation only; the parent resolves access to the original post first.
class SharedStoryVideo extends StatelessWidget {
  const SharedStoryVideo({super.key, required this.url, required this.author,
    required this.active, this.note = '', this.onReady, this.onError, this.authorId = '', this.onProfileOpening, this.onProfileReturned});
  final String url, author, note, authorId;
  final VoidCallback? onProfileOpening, onProfileReturned;
  final bool active;
  final ValueChanged<Duration>? onReady;
  final VoidCallback? onError;

  static Duration storyDuration(Duration duration) => Duration(
    milliseconds: duration.inMilliseconds.clamp(1000, 15000).toInt());

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
    IgnorePointer(child: AppVideoPlayer.network(
      key: ValueKey(url), url: url, active: active, autoplay: true,
      muted: false, loop: false, showControls: false, fit: BoxFit.cover,
      resumePosition: false,
      onReady: (duration) => onReady?.call(storyDuration(duration)),
      onError: onError,
    )),
    Positioned(top: 110, left: 16, right: 16, child: ProfileNameLink(userId: authorId,
      onOpening: onProfileOpening, onReturned: onProfileReturned,
      child: Text('↗ $author', maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
          shadows: [Shadow(color: Colors.black, blurRadius: 6)])),
    )),
    if (note.trim().isNotEmpty) Positioned(bottom: 150, left: 20, right: 20,
      child: IgnorePointer(child: Text(note, maxLines: 4,
        overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 17,
          shadows: [Shadow(color: Colors.black, blurRadius: 8)])))),
  ]);
}
