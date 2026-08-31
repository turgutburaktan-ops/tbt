import 'dart:async';
import 'dart:collection';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/app_story.dart';
import '../screens/main_camera_screen.dart';
import '../screens/music_detail_screen.dart';
import '../screens/story_music_picker.dart';
import '../services/story_service.dart';
import 'app_video_player.dart';
import 'firebase_media_image.dart';

class StoryStrip extends StatefulWidget {
  final Set<String>? visibleUserIds;
  const StoryStrip({super.key, this.visibleUserIds});
  @override
  State<StoryStrip> createState() => _StoryStripState();
}

class _StoryStripState extends State<StoryStrip> {
  bool _openingCamera = false;
  late final Stream<List<AppStory>> _activeStories;

  @override
  void initState() {
    super.initState();
    _activeStories = StoryService.instance.watchActive();
  }

  Future<void> _addStory() async {
    if (_openingCamera) return;
    setState(() => _openingCamera = true);
    try {
      final shared = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const MainCameraScreen(
            initialMode: CameraShareMode.story,
          ),
        ),
      );
      if (!mounted || shared != true) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 18),
                SizedBox(width: 8),
                Text('Story paylaşıldı'),
              ],
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _openingCamera = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    return StreamBuilder<List<AppStory>>(
      stream: _activeStories,
      builder: (context, snapshot) {
        final visible = (snapshot.data ?? const <AppStory>[])
            .where(
              (s) => widget.visibleUserIds == null ||
                  widget.visibleUserIds!.contains(s.userId),
            )
            .toList();
        final grouped = LinkedHashMap<String, List<AppStory>>();
        for (final s in visible) {
          grouped.putIfAbsent(s.userId, () => <AppStory>[]).add(s);
        }
        for (final stories in grouped.values) {
          stories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        }
        final mine = grouped.remove(me?.uid);
        final otherStoryIds = grouped.values
            .expand((stories) => stories)
            .map((story) => story.id)
            .toList(growable: false);

        return StreamBuilder<Set<String>>(
          stream: StoryService.instance.watchViewedStoryIds(otherStoryIds),
          initialData: const <String>{},
          builder: (context, viewedSnapshot) {
            final viewedIds = viewedSnapshot.data ?? const <String>{};
            final groups = grouped.values.toList(growable: false);
            groups.sort((a, b) {
              final aViewed = a.every((story) => viewedIds.contains(story.id));
              final bViewed = b.every((story) => viewedIds.contains(story.id));
              if (aViewed != bViewed) return aViewed ? 1 : -1;
              return a.first.createdAt.compareTo(b.first.createdAt);
            });

            return SizedBox(
              height: 104,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
                children: [
                  _AddStoryCircle(
                    userId: me?.uid ?? '',
                    photoUrl: me?.photoURL ?? '',
                    loading: _openingCamera,
                    hasStory: mine != null && mine.isNotEmpty,
                    onTap: _addStory,
                    onStoryTap: mine == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StoryViewerScreen(stories: mine),
                              ),
                            ),
                  ),
                  ...groups.map((stories) {
                    final fullyViewed =
                        stories.every((story) => viewedIds.contains(story.id));
                    final firstUnviewed = stories.indexWhere(
                      (story) => !viewedIds.contains(story.id),
                    );
                    final initialIndex = firstUnviewed >= 0 ? firstUnviewed : 0;
                    return _StoryCircle(
                      stories: stories,
                      viewed: fullyViewed,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StoryViewerScreen(
                            stories: stories,
                            initialIndex: initialIndex,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AddStoryCircle extends StatelessWidget {
  final String userId, photoUrl;
  final bool loading, hasStory;
  final VoidCallback onTap;
  final VoidCallback? onStoryTap;
  const _AddStoryCircle({
    required this.userId,
    required this.photoUrl,
    required this.loading,
    required this.hasStory,
    required this.onTap,
    this.onStoryTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 78,
        child: Column(
          children: [
            GestureDetector(
              onTap: hasStory ? onStoryTap : onTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    padding: EdgeInsets.all(hasStory ? 2.5 : 0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: hasStory
                          ? const LinearGradient(
                              colors: [
                                Color(0xFF39E7E0),
                                Color(0xFF6977FF),
                                Color(0xFFB65CFF),
                              ],
                            )
                          : null,
                    ),
                    child: Container(
                      padding: EdgeInsets.all(hasStory ? 2 : 0),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF090A0D),
                      ),
                      child: ClipOval(
                        child: FirebaseMediaImage(
                          imageUrl: photoUrl,
                          fallbackStoragePaths:
                              FirebaseMediaImage.avatarPaths(userId),
                          errorWidget: const ColoredBox(
                            color: Color(0xFF20242A),
                            child: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -1,
                    child: GestureDetector(
                      onTap: onTap,
                      child: Container(
                        width: 23,
                        height: 23,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFF090A0D),
                            width: 2,
                          ),
                        ),
                        child: loading
                            ? const Padding(
                                padding: EdgeInsets.all(5),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(
                                Icons.add_rounded,
                                size: 17,
                                color: Colors.black,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              hasStory ? 'Hikayen' : 'Story ekle',
              maxLines: 1,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
}

class _StoryCircle extends StatelessWidget {
  final List<AppStory> stories;
  final bool viewed;
  final VoidCallback onTap;
  const _StoryCircle({
    required this.stories,
    required this.viewed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = stories.first;
    return SizedBox(
      width: 78,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: viewed ? const Color(0xFF626870) : null,
                gradient: viewed
                    ? null
                    : const LinearGradient(
                        colors: [
                          Color(0xFF39E7E0),
                          Color(0xFF6977FF),
                          Color(0xFFB65CFF),
                        ],
                      ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF090A0D),
                ),
                child: ClipOval(
                  child: FirebaseMediaImage(
                    imageUrl: s.userPhotoUrl,
                    fallbackStoragePaths:
                        FirebaseMediaImage.avatarPaths(s.userId),
                    errorWidget: FirebaseMediaImage(
                      imageUrl:
                          s.thumbnailUrl.isNotEmpty ? s.thumbnailUrl : s.imageUrl,
                      storagePath: s.thumbnailStoragePath.isNotEmpty
                          ? s.thumbnailStoragePath
                          : s.storagePath,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              s.userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: viewed ? Colors.white60 : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StoryViewerScreen extends StatefulWidget {
  final List<AppStory> stories;
  final int initialIndex;
  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });
  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  static const bool _musicFeatureVisible = false;
  late final PageController _controller;
  late final List<AppStory> _stories;
  late final AnimationController _progress;
  final AudioPlayer _musicPlayer = AudioPlayer();
  final _replyController = TextEditingController();
  final _replyFocusNode = FocusNode();
  int _index = 0;
  bool _sending = false;
  bool _musicReady = false;
  int _musicGeneration = 0;

  AppStory get _current => _stories[_index];
  bool get _mine => _current.userId == FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _stories = [...widget.stories]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _index = widget.initialIndex.clamp(0, _stories.length - 1);
    _controller = PageController(initialPage: _index);
    _progress = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    _replyFocusNode.addListener(_handleReplyFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markViewed();
      _restartProgress();
    });
  }

  @override
  void dispose() {
    _musicGeneration++;
    unawaited(_musicPlayer.dispose());
    _replyFocusNode.removeListener(_handleReplyFocusChange);
    _replyFocusNode.dispose();
    _progress.dispose();
    _controller.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _handleReplyFocusChange() {
    if (_replyFocusNode.hasFocus) {
      _pause();
    } else if (!_sending) {
      _resume();
    }
  }

  Duration get _duration => Duration(
        milliseconds: _musicFeatureVisible && _current.hasMusic
            ? (_current.musicDurationMs > 0
                ? _current.musicDurationMs.clamp(1000, 15000).toInt()
                : 15000)
            : _current.isVideo
                ? (_current.durationMs > 0
                    ? _current.durationMs.clamp(1000, 15000).toInt()
                    : 15000)
                : 7000,
      );

  void _restartProgress() {
    _progress.stop();
    _progress.duration = _duration;
    _progress.forward(from: 0);
    unawaited(_startCurrentMusic());
  }

  Future<void> _startCurrentMusic() async {
    final generation = ++_musicGeneration;
    _musicReady = false;
    await _musicPlayer.stop();
    if (!_musicFeatureVisible) return;
    final story = _current;
    if (!story.hasMusic) return;
    try {
      await _musicPlayer.setUrl(story.musicPreviewUrl);
      final targetVolume = story.musicVolume.clamp(0, 1).toDouble();
      await _musicPlayer.setVolume(story.musicFadeInMs > 0 ? 0 : targetVolume);
      if (generation != _musicGeneration || !mounted) return;
      final start = Duration(milliseconds: story.musicStartMs.clamp(0, 86400000));
      final clipLength = Duration(
        milliseconds: (story.musicDurationMs > 0 ? story.musicDurationMs : 15000)
            .clamp(1000, 15000),
      );
      await _musicPlayer.setClip(start: start, end: start + clipLength);
      if (generation != _musicGeneration || !mounted) return;
      _musicReady = true;
      if (_progress.isAnimating) {
        unawaited(_musicPlayer.play());
        unawaited(_runMusicFades(story, generation, targetVolume));
      }
    } catch (_) {
      if (generation == _musicGeneration) _musicReady = false;
    }
  }

  Future<void> _runMusicFades(
    AppStory story,
    int generation,
    double targetVolume,
  ) async {
    final fadeIn = story.musicFadeInMs.clamp(0, 1500);
    if (fadeIn > 0) {
      const steps = 10;
      for (var step = 1; step <= steps; step++) {
        await Future<void>.delayed(Duration(milliseconds: fadeIn ~/ steps));
        if (generation != _musicGeneration || !mounted) return;
        await _musicPlayer.setVolume(targetVolume * step / steps);
      }
    }
    final clipMs = (story.musicDurationMs > 0 ? story.musicDurationMs : 15000)
        .clamp(1000, 15000);
    final fadeOut = story.musicFadeOutMs.clamp(0, 1500);
    final waitMs = (clipMs - fadeIn - fadeOut).clamp(0, 15000);
    if (waitMs > 0) await Future<void>.delayed(Duration(milliseconds: waitMs));
    if (fadeOut > 0) {
      const steps = 10;
      for (var step = steps - 1; step >= 0; step--) {
        if (generation != _musicGeneration || !mounted) return;
        await _musicPlayer.setVolume(targetVolume * step / steps);
        await Future<void>.delayed(Duration(milliseconds: fadeOut ~/ steps));
      }
    }
  }

  void _pause() {
    _progress.stop();
    unawaited(_musicPlayer.pause());
  }

  void _resume() {
    if (!_progress.isCompleted) _progress.forward();
    if (_musicReady && !_musicPlayer.playing) {
      unawaited(_musicPlayer.play());
    }
  }

  void _next() {
    if (!mounted) return;
    if (_index + 1 >= _stories.length) {
      Navigator.pop(context);
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  void _previous() {
    if (_index == 0) {
      _restartProgress();
      return;
    }
    _controller.previousPage(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  Future<void> _markViewed() => StoryService.instance.recordView(_current);

  String _time(AppStory s) {
    final d = DateTime.now().difference(s.createdAt);
    if (d.inMinutes < 1) return 'şimdi';
    if (d.inMinutes < 60) return '${d.inMinutes} dk';
    return '${d.inHours.clamp(1, 24)} sa';
  }

  Future<void> _archive() async {
    _pause();
    try {
      await StoryService.instance.archiveStory(_current);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story arşive alındı.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      _resume();
    }
  }

  Future<void> _delete() async {
    _pause();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Story silinsin mi?'),
        content: const Text(
          'Bu Story aktif akıştan ve arşivden kalıcı olarak silinecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      if (mounted) _resume();
      return;
    }
    try {
      await StoryService.instance.deleteStory(_current);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      _resume();
    }
  }

  Future<void> _showOwnerMenu() async {
    _pause();
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Arşive al'),
              subtitle: const Text('Story aktif akıştan kalkar, arşivinde kalır.'),
              onTap: () => Navigator.pop(sheetContext, 'archive'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
              subtitle: const Text('Story kalıcı olarak silinir.'),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('İptal'),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'archive') {
      await _archive();
    } else if (action == 'delete') {
      await _delete();
    } else {
      _resume();
    }
  }

  Future<void> _react(String emoji) async {
    _pause();
    try {
      await StoryService.instance.setReaction(_current, emoji);
    } finally {
      if (mounted) _resume();
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _sending) return;
    _pause();
    setState(() => _sending = true);
    try {
      await StoryService.instance.sendReply(_current, text);
      _replyController.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        if (!_replyFocusNode.hasFocus) _resume();
      }
    }
  }

  void _showViewers() {
    _pause();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .62,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: StoryService.instance.watchInteractions(_current),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <Map<String, dynamic>>[];
              return Column(
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(top: 9, bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 8, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${items.length} izleyen',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(
                            child: Text('Henüz görüntüleme yok', style: TextStyle(color: Colors.white54)),
                          )
                        : ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (_, i) {
                              final x = items[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF22252A),
                                  child: ClipOval(
                                    child: FirebaseMediaImage(
                                      imageUrl: (x['userPhotoUrl'] ?? '').toString(),
                                      fallbackStoragePaths: FirebaseMediaImage.avatarPaths(
                                        (x['userId'] ?? x['id'] ?? '').toString(),
                                      ),
                                      errorWidget: const Icon(Icons.person_outline),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  (x['userName'] ?? 'Kullanıcı').toString(),
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: (x['message'] ?? '').toString().isEmpty
                                    ? null
                                    : Text(
                                        (x['message']).toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                trailing: Text(
                                  (x['reaction'] ?? '').toString(),
                                  style: const TextStyle(fontSize: 20),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted) _resume();
    });
  }

  Future<void> _openMusicDetail() async {
    final story = _current;
    if (!story.hasMusic) return;
    _pause();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MusicDetailScreen(
          music: StoryMusicSelection(
            trackId: story.musicTrackId,
            title: story.musicTitle,
            artist: story.musicArtist,
            artworkUrl: story.musicArtworkUrl,
            previewUrl: story.musicPreviewUrl,
            durationMs: story.musicDurationMs,
            startMs: story.musicStartMs,
            clipDurationMs: story.musicDurationMs > 0 ? story.musicDurationMs : 15000,
            stickerStyle: story.musicStickerStyle,
            license: story.musicLicense,
            sourceUrl: story.musicSourceUrl,
            musicVolume: story.musicVolume,
            originalAudioVolume: story.originalAudioVolume,
            fadeInMs: story.musicFadeInMs,
            fadeOutMs: story.musicFadeOutMs,
            mood: story.musicMood,
          ),
        ),
      ),
    );
    if (mounted) _resume();
  }

  Widget _media(AppStory s, double width, double height) {
    if (s.isVideo && s.videoUrl.isNotEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: AppVideoPlayer.network(
          key: ValueKey(s.id),
          url: s.videoUrl,
          autoplay: true,
          muted: s.hasMusic && s.originalAudioVolume <= 0,
          volume: s.hasMusic ? s.originalAudioVolume : 1,
          loop: false,
          showControls: false,
          fit: BoxFit.cover,
        ),
      );
    }
    return SizedBox(
      width: width,
      height: height,
      child: FirebaseMediaImage(
        imageUrl: s.imageUrl,
        storagePath: s.storagePath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorWidget: const Center(
          child: Icon(Icons.broken_image_outlined, size: 52, color: Colors.white38),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final screen = MediaQuery.sizeOf(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite ? constraints.maxWidth : screen.width;
          final height = constraints.maxHeight.isFinite ? constraints.maxHeight : screen.height;
          return SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                SizedBox(
                  width: width,
                  height: height,
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _stories.length,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (value) {
                      setState(() => _index = value);
                      _replyController.clear();
                      _markViewed();
                      _restartProgress();
                    },
                    itemBuilder: (_, i) => _media(_stories[i], width, height),
                  ),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onLongPressStart: (_) => _pause(),
                    onLongPressEnd: (_) => _resume(),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: _previous,
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: _next,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 150,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withValues(alpha: .68), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _progress,
                          builder: (_, __) => Row(
                            children: List.generate(
                              _stories.length,
                              (i) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: i < _index
                                          ? 1
                                          : i > _index
                                              ? 0
                                              : _progress.value,
                                      minHeight: 2.5,
                                      backgroundColor: Colors.white24,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 11),
                        Row(
                          children: [
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: ClipOval(
                                child: FirebaseMediaImage(
                                  imageUrl: current.userPhotoUrl,
                                  fallbackStoragePaths: FirebaseMediaImage.avatarPaths(current.userId),
                                  errorWidget: const ColoredBox(
                                    color: Color(0xFF22252A),
                                    child: Icon(Icons.person_outline, size: 20),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  children: [
                                    TextSpan(
                                      text: current.userName,
                                      style: const TextStyle(fontWeight: FontWeight.w900),
                                    ),
                                    TextSpan(
                                      text: '  ${_time(current)}',
                                      style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_mine)
                              IconButton(
                                onPressed: _showOwnerMenu,
                                icon: const Icon(Icons.more_horiz_rounded),
                              ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 110,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withValues(alpha: .58), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
                if (current.caption.trim().isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .52),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            current.caption,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_musicFeatureVisible && current.hasMusic)
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 66,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        onPressed: _openMusicDetail,
                        icon: const Icon(Icons.music_note_rounded, size: 18),
                        label: Text(
                          '${current.musicTitle} · ${current.musicArtist}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 8,
                  child: _mine
                      ? StreamBuilder<List<Map<String, dynamic>>>(
                          stream: StoryService.instance.watchInteractions(current),
                          builder: (_, snapshot) => Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _showViewers,
                              style: TextButton.styleFrom(foregroundColor: Colors.white),
                              icon: const Icon(Icons.visibility_outlined),
                              label: Text('${snapshot.data?.length ?? 0} izleyen'),
                            ),
                          ),
                        )
                      : StreamBuilder<Map<String, dynamic>>(
                          stream: StoryService.instance.watchMyInteraction(current.id),
                          builder: (_, snapshot) {
                            final liked = (snapshot.data ?? const <String, dynamic>{})['liked'] == true;
                            const fieldBorder = OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(24)),
                              borderSide: BorderSide(color: Colors.white30),
                            );
                            return Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 46,
                                    child: TextField(
                                      controller: _replyController,
                                      focusNode: _replyFocusNode,
                                      maxLength: 500,
                                      buildCounter: (
                                        _, {
                                        required currentLength,
                                        required isFocused,
                                        maxLength,
                                      }) => null,
                                      onSubmitted: (_) => _sendReply(),
                                      textInputAction: TextInputAction.send,
                                      decoration: InputDecoration(
                                        hintText: 'Mesaj gönder…',
                                        filled: true,
                                        fillColor: Colors.black.withValues(alpha: .35),
                                        border: fieldBorder,
                                        enabledBorder: fieldBorder,
                                        focusedBorder: fieldBorder,
                                        disabledBorder: fieldBorder,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => StoryService.instance.setLiked(current, !liked),
                                  icon: Icon(
                                    liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: liked ? Colors.redAccent : Colors.white,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Tepki',
                                  onOpened: _pause,
                                  onCanceled: _resume,
                                  onSelected: (emoji) => _react(emoji),
                                  itemBuilder: (_) => ['❤️', '🔥', '😍', '👏', '😂']
                                      .map(
                                        (emoji) => PopupMenuItem<String>(
                                          value: emoji,
                                          child: Text(emoji, style: const TextStyle(fontSize: 24)),
                                        ),
                                      )
                                      .toList(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Icon(Icons.emoji_emotions_outlined),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _sending ? null : _sendReply,
                                  icon: _sending
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.send_rounded),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
