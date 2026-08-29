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
  final Set<String> _deleting = <String>{};

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

  bool _isMemory(AppStory story, DateTime now) =>
      story.createdAt.year < now.year &&
      story.createdAt.month == now.month &&
      story.createdAt.day == now.day;

  int _yearsAgo(AppStory story, DateTime now) => now.year - story.createdAt.year;

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
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _sharing.remove(story.id));
    }
  }

  Future<void> _delete(AppStory story) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Story silinsin mi?'),
        content: const Text('Bu Story arşivden kalıcı olarak silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting.add(story.id));
    try {
      await StoryService.instance.deleteStory(story);
    } finally {
      if (mounted) setState(() => _deleting.remove(story.id));
    }
  }

  Widget _preview(AppStory story) => FirebaseMediaImage(
        imageUrl: story.previewUrl,
        storagePath: story.previewStoragePath,
        fit: BoxFit.cover,
        errorWidget: const ColoredBox(
          color: AppColors.surfaceStrong,
          child: Icon(Icons.broken_image_outlined),
        ),
      );

  Widget _memorySection(List<AppStory> memories, DateTime now) {
    if (memories.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bugünden Anılar',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            memories.any((s) => _yearsAgo(s, now) == 1)
                ? 'Geçen sene bugün paylaştıkların'
                : 'Geçmiş yıllarda bugün paylaştıkların',
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: memories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final story = memories[index];
                final years = _yearsAgo(story, now);
                final sharing = _sharing.contains(story.id);
                return SizedBox(
                  width: 140,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _preview(story),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                              stops: [.4, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              years == 1 ? 'Geçen sene bugün' : '$years yıl önce bugün',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: FilledButton.icon(
                            onPressed: sharing ? null : () => _repost(story),
                            icon: sharing
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.replay_rounded, size: 17),
                            label: const Text('Paylaş'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _archiveCard(AppStory story) {
    final sharing = _sharing.contains(story.id);
    final deleting = _deleting.contains(story.id);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _preview(story),
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
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.videocam_rounded),
              ),
            ),
          Positioned(
            top: 3,
            right: 3,
            child: IconButton(
              tooltip: 'Sil',
              onPressed: deleting ? null : () => _delete(story),
              icon: deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded),
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
            final now = DateTime.now();
            final memories = stories.where((story) => _isMemory(story, now)).toList();
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _memorySection(memories, now)),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12, 14, 12, 8),
                    child: Text(
                      'Tüm Story’ler',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _archiveCard(stories[index]),
                      childCount: stories.length,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: .67,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
}
