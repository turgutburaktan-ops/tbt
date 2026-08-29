import 'dart:async';
import 'dart:collection';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_story.dart';
import '../screens/camera_screen.dart';
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

  Future<void> _addStory() async {
    if (_openingCamera) return;
    setState(() => _openingCamera = true);
    try {
      final shared = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const CameraScreen(storyMode: true)),
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
      stream: StoryService.instance.watchActive(),
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
              ...grouped.values.map(
                (stories) => _StoryCircle(
                  stories: stories,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoryViewerScreen(stories: stories),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
  final VoidCallback onTap;
  const _StoryCircle({required this.stories, required this.onTap});

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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
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
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class StoryViewerScreen extends StatefulWidget {
  final List<AppStory> stories;
  const StoryViewerScreen({super.key, required this.stories});
  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _controller;
  late final List<AppStory> _stories;
  late final AnimationController _progress;
  final _replyController = TextEditingController();
  int _index = 0;
  bool _sending = false;

  AppStory get _current => _stories[_index];
  bool get _mine =>
      _current.userId == FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _stories = [...widget.stories]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _controller = PageController();
    _progress = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markViewed();
      _restartProgress();
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Duration get _duration => Duration(
        milliseconds: _current.isVideo
            ? (_current.durationMs > 0
                ? _current.durationMs.clamp(1000, 15000).toInt()
                : 15000)
            : 7000,
      );

  void _restartProgress() {
    _progress.stop();
    _progress.duration = _duration;
    _progress.forward(from: 0);
  }

  void _pause() => _progress.stop();
  void _resume() {
    if (!_progress.isCompleted) _progress.forward();
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

  Future<void> _delete() async {
    _pause();
    await StoryService.instance.deleteStory(_current);
    if (mounted) Navigator.pop(context);
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
      if (mounted) setState(() => _sending = false);
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
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
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
                            child: Text(
                              'Henüz görüntüleme yok',
                              style: TextStyle(color: Colors.white54),
                            ),
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
                                      imageUrl:
                                          (x['userPhotoUrl'] ?? '').toString(),
                                      fallbackStoragePaths:
                                          FirebaseMediaImage.avatarPaths(
                                        (x['userId'] ?? x['id'] ?? '')
                                            .toString(),
                                      ),
                                      errorWidget:
                                          const Icon(Icons.person_outline),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  (x['userName'] ?? 'Kullanıcı').toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
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

  Widget _media(AppStory s, double width, double height) {
    if (s.isVideo && s.videoUrl.isNotEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: AppVideoPlayer.network(
          key: ValueKey(s.id),
          url: s.videoUrl,
          autoplay: true,
          muted: false,
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
          child: Icon(
            Icons.broken_image_outlined,
            size: 52,
            color: Colors.white38,
          ),
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
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : screen.width;
          final height = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : screen.height;
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
                    itemBuilder: (_, i) =>
                        _media(_stories[i], width, height),
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
                          colors: [
                            Colors.black.withValues(alpha: .68),
                            Colors.transparent,
                          ],
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
                                child: Container(
                                  height: 2.5,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1.5,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: i < _index
                                        ? 1
                                        : i > _index
                                            ? 0
                                            : _progress.value,
                                    child: const ColoredBox(
                                      color: Colors.white,
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
                                  fallbackStoragePaths:
                                      FirebaseMediaImage.avatarPaths(
                                    current.userId,
                                  ),
                                  errorWidget: const ColoredBox(
                                    color: Color(0xFF22252A),
                                    child: Icon(
                                      Icons.person_outline,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: current.userName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '  ${_time(current)}',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_mine)
                              IconButton(
                                onPressed: _delete,
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
                          colors: [
                            Colors.black.withValues(alpha: .58),
                            Colors.transparent,
                          ],
                        ),
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
                          stream:
                              StoryService.instance.watchInteractions(current),
                          builder: (_, snapshot) => Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _showViewers,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.visibility_outlined),
                              label:
                                  Text('${snapshot.data?.length ?? 0} izleyen'),
                            ),
                          ),
                        )
                      : StreamBuilder<Map<String, dynamic>>(
                          stream: StoryService.instance
                              .watchMyInteraction(current.id),
                          builder: (_, snapshot) {
                            final liked = (snapshot.data ??
                                    const <String, dynamic>{})['liked'] ==
                                true;
                            return Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: .35),
                                      border:
                                          Border.all(color: Colors.white30),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: TextField(
                                      controller: _replyController,
                                      maxLength: 500,
                                      buildCounter: (
                                        _, {
                                        required currentLength,
                                        required isFocused,
                                        maxLength,
                                      }) =>
                                          null,
                                      onSubmitted: (_) => _sendReply(),
                                      textInputAction: TextInputAction.send,
                                      decoration: const InputDecoration(
                                        hintText: 'Mesaj gönder…',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => StoryService.instance
                                      .setLiked(current, !liked),
                                  icon: Icon(
                                    liked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: liked
                                        ? Colors.redAccent
                                        : Colors.white,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Tepki',
                                  onOpened: _pause,
                                  onCanceled: _resume,
                                  onSelected: (emoji) => _react(emoji),
                                  itemBuilder: (_) =>
                                      ['❤️', '🔥', '😍', '👏', '😂']
                                          .map(
                                            (emoji) => PopupMenuItem<String>(
                                              value: emoji,
                                              child: Text(
                                                emoji,
                                                style: const TextStyle(
                                                  fontSize: 24,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Icon(
                                      Icons.emoji_emotions_outlined,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _sending ? null : _sendReply,
                                  icon: _sending
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
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
