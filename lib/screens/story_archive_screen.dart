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

  String _duration(AppStory story) {
    final total = (story.durationMs / 1000).round();
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
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
      if (mounted) Navigator.of(context).maybePop();
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

  void _openStory(AppStory story) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) {
        final sharing = _sharing.contains(story.id);
        final deleting = _deleting.contains(story.id);
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: StatefulBuilder(
            builder: (context, setSheetState) => Stack(
              fit: StackFit.expand,
              children: [
                _preview(story),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black54, Colors.transparent, Colors.black87],
                      stops: [0, .35, 1],
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _date(story.createdAt),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: sharing
                                    ? null
                                    : () async {
                                        setSheetState(() {});
                                        await _repost(story);
                                        if (context.mounted) setSheetState(() {});
                                      },
                                icon: _sharing.contains(story.id)
                                    ? const SizedBox(
                                        width: 17,
                                        height: 17,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.replay_rounded),
                                label: const Text('Tekrar Paylaş'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton.filledTonal(
                              tooltip: 'Sil',
                              onPressed: deleting
                                  ? null
                                  : () async {
                                      setSheetState(() {});
                                      await _delete(story);
                                    },
                              icon: _deleting.contains(story.id)
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _memorySection(List<AppStory> memories, DateTime now) {
    if (memories.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bugünden Anılar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 154,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: memories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, index) {
                final story = memories[index];
                final years = _yearsAgo(story, now);
                return GestureDetector(
                  onTap: () => _openStory(story),
                  child: SizedBox(
                    width: 104,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _preview(story),
                        ),
                        Positioned(
                          left: 6,
                          right: 6,
                          bottom: 6,
                          child: Text(
                            years == 1 ? 'Geçen sene bugün' : '$years yıl önce bugün',
                            maxLines: 2,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                            ),
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

  Widget _archiveTile(AppStory story) => GestureDetector(
        onTap: () => _openStory(story),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _preview(story),
            if (story.isVideo)
              Positioned(
                left: 6,
                bottom: 6,
                child: Row(
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 15),
                    if (story.durationMs > 0) ...[
                      const SizedBox(width: 2),
                      Text(
                        _duration(story),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Story Arşivi'),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  enabled: false,
                  value: 'info',
                  child: Text('Story’lerin yalnızca sana görünür'),
                ),
              ],
            ),
          ],
        ),
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
                      Icon(Icons.archive_outlined, size: 54, color: Colors.white38),
                      SizedBox(height: 12),
                      Text(
                        'Arşivlenmiş Story yok',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '24 saati dolan Story’lerin burada saklanacak.',
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
                SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _archiveTile(stories[index]),
                    childCount: stories.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                    childAspectRatio: .72,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        ),
      );
}
