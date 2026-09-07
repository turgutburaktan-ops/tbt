import 'package:flutter/material.dart';

import '../widgets/app_video_player.dart';
import '../widgets/content_engagement_bar.dart';
import '../widgets/firebase_media_image.dart';

class FullscreenVideoPostScreen extends StatelessWidget {
  final Map<String, dynamic> post;

  const FullscreenVideoPostScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final videoUrl = (post['videoUrl'] ?? '').toString();
    final preview = (post['thumbnailUrl'] ?? post['imageUrl'] ?? '').toString();
    final caption = (post['caption'] ?? '').toString().trim();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Video'),
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AppVideoPlayer.network(
                url: videoUrl,
                autoplay: true,
                muted: false,
                loop: true,
                showControls: true,
                fit: BoxFit.contain,
                loading: FirebaseMediaImage(
                  imageUrl: preview,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .62),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ContentEngagementBar(
                    collection: 'posts',
                    contentId: (post['id'] ?? '').toString(),
                    ownerId: (post['userId'] ?? '').toString(),
                    title: caption.isEmpty ? 'Video paylaşımı' : caption,
                    sourceType: 'post',
                    showTagAction: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
