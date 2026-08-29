import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_story.dart';
import '../services/story_service.dart';
import '../theme/app_theme.dart';
import '../widgets/firebase_media_image.dart';

class StoryArchiveScreen extends StatefulWidget {
  const StoryArchiveScreen({super.key});

  @override
  State<StoryArchiveScreen> createState() => _StoryArchiveScreenState();
}

class _StoryArchiveScreenState extends State<StoryArchiveScreen> {
  final Set<String> _sharing = <String>{};

  @override
  void initState() {
    super.initState();
    unawaited(StoryService.instance.syncLegacyStoriesToArchive());
  }

  String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  Future<void> _repost(AppStory story) async {
    if (_sharing.contains(story.id)) return;
    setState(() => _sharing.add(story.id));
    try {
      await StoryService.instance.repostArchivedStory(story);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story yeniden 24 saatliğine paylaşıldı.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing.remove(story.id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Story Arşivi')),
    body: StreamBuilder<List<AppStory>>(
      stream: StoryService.instance.watchArchive(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Story arşivi yüklenemedi.'));
        }
        final stories = (snapshot.data ?? const <AppStory>[])
            .where((story) => !story.isActive)
            .toList(growable: false);
        if (stories.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.archive_outlined, size: 62, color: Colors.white38),
                  SizedBox(height: 14),
                  Text(
                    'Arşivlenmiş Story yok',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Story’lerin 24 saat dolduğunda burada saklanacak.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: stories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: .67,
          ),
          itemBuilder: (context, index) {
            final story = stories[index];
            final sharing = _sharing.contains(story.id);
            return ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FirebaseMediaImage(
                    imageUrl: story.previewUrl,
                    storagePath: story.previewStoragePath,
                    fit: BoxFit.cover,
                    errorWidget: const ColoredBox(
                      color: AppColors.surfaceStrong,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                        stops: [.45, 1],
                      ),
                    ),
                  ),
                  if (story.isVideo)
                    const Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.videocam_rounded),
                      ),
                    ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _date(story.createdAt),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: sharing ? null : () => _repost(story),
                            icon: sharing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.replay_rounded, size: 18),
                            label: const Text('Tekrar paylaş'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}
