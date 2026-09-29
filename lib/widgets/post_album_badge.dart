import 'package:flutter/material.dart';

/// A cover stays a single grid tile; the badge identifies its photo album.
class PostAlbumBadge extends StatelessWidget {
  final Map<String, dynamic> post;
  const PostAlbumBadge({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final urls = post['mediaUrls'];
    final paths = post['mediaStoragePaths'];
    final urlCount = urls is List ? urls.length : 0;
    final pathCount = paths is List ? paths.length : 0;
    final count = urlCount > pathCount ? urlCount : pathCount;
    if (count < 2 || (post['videoUrl'] ?? '').toString().isNotEmpty ||
        ['video', 'reel', 'reels', 'route'].contains(post['mediaType'])) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: 6,
      right: 6,
      child: IgnorePointer(
        child: Semantics(
          label: '$count fotoğraflı gönderi',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.photo_library_outlined, color: Colors.white, size: 15),
                const SizedBox(width: 4),
                Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
