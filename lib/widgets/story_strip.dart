import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_story.dart';
import '../services/story_service.dart';
import 'firebase_media_image.dart';

class StoryStrip extends StatefulWidget {
  final Set<String>? visibleUserIds;

  const StoryStrip({super.key, this.visibleUserIds});

  @override
  State<StoryStrip> createState() => _StoryStripState();
}

class _StoryStripState extends State<StoryStrip> {
  bool _uploading = false;

  Future<void> _addStory() async {
    if (_uploading) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF15181D),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Story ekle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Kamerayla çek'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galeriden seç'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 100,
      requestFullMetadata: false,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await StoryService.instance.createStory(File(picked.path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story 24 saatliğine paylaşıldı.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return StreamBuilder<List<AppStory>>(
      stream: StoryService.instance.watchActive(),
      builder: (context, snapshot) {
        final visible = snapshot.data?.where((story) {
              final ids = widget.visibleUserIds;
              return ids == null || ids.contains(story.userId);
            }).toList() ??
            const <AppStory>[];
        final grouped = LinkedHashMap<String, List<AppStory>>();
        for (final story in visible) {
          grouped.putIfAbsent(story.userId, () => <AppStory>[]).add(story);
        }

        return Container(
          height: 111,
          margin: const EdgeInsets.only(bottom: 6),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF20242B))),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
            children: [
              _AddStoryCircle(
                userId: currentUser?.uid ?? '',
                photoUrl: currentUser?.photoURL ?? '',
                uploading: _uploading,
                onTap: _addStory,
              ),
              ...grouped.values.map(
                (stories) => _StoryCircle(
                  stories: stories,
                  isMine: stories.first.userId == currentUser?.uid,
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
  final String userId;
  final String photoUrl;
  final bool uploading;
  final VoidCallback onTap;

  const _AddStoryCircle({
    required this.userId,
    required this.photoUrl,
    required this.uploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 76,
        child: InkWell(
          onTap: uploading ? null : onTap,
          borderRadius: BorderRadius.circular(40),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF2A2E35),
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
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF42F5E9),
                        border: Border.all(
                            color: const Color(0xFF090A0D), width: 2),
                      ),
                      child: uploading
                          ? const Padding(
                              padding: EdgeInsets.all(5),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.add_rounded,
                              size: 18, color: Colors.black),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              const Text(
                'Story ekle',
                maxLines: 1,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
}

class _StoryCircle extends StatelessWidget {
  final List<AppStory> stories;
  final bool isMine;
  final VoidCallback onTap;

  const _StoryCircle({
    required this.stories,
    required this.isMine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final story = stories.first;
    return SizedBox(
      width: 76,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Column(
          children: [
            Container(
              width: 66,
              height: 66,
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF42F5E9), Color(0xFF8B5CF6)],
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
                    imageUrl: story.userPhotoUrl,
                    fallbackStoragePaths:
                        FirebaseMediaImage.avatarPaths(story.userId),
                    errorWidget: FirebaseMediaImage(
                      imageUrl: story.imageUrl,
                      storagePath: story.storagePath,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              isMine ? 'Hikayen' : story.userName,
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

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late final PageController _controller;
  final TextEditingController _replyController = TextEditingController();
  Timer? _timer;
  int _index = 0;
  bool _sending = false;

  AppStory get _current => widget.stories[_index];
  bool get _mine =>
      _current.userId == FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markViewed());
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 7), _next);
  }

  void _pauseTimer() => _timer?.cancel();

  void _next() {
    if (!mounted) return;
    if (_index + 1 >= widget.stories.length) {
      Navigator.pop(context);
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _markViewed() => StoryService.instance.recordView(_current);

  String _time(AppStory story) {
    final diff = DateTime.now().difference(story.createdAt);
    if (diff.inMinutes < 1) return 'şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    return '${diff.inHours.clamp(1, 24)} sa';
  }

  Future<void> _delete(AppStory story) async {
    _pauseTimer();
    await StoryService.instance.deleteStory(story);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _react(String emoji) async {
    _pauseTimer();
    try {
      await StoryService.instance.setReaction(_current, emoji);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$emoji tepkisi gönderildi.')));
      }
    } finally {
      if (mounted) _restartTimer();
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _sending) return;
    _pauseTimer();
    setState(() => _sending = true);
    try {
      await StoryService.instance.sendReply(_current, text);
      _replyController.clear();
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Story mesajı gönderildi.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _restartTimer();
      }
    }
  }

  void _showViewers(AppStory story) {
    _pauseTimer();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111318),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .62,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: StoryService.instance.watchInteractions(story),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <Map<String, dynamic>>[];
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${items.length} görüntüleme',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(
                            child: Text('Henüz kimse bu Story’yi izlemedi.',
                                style: TextStyle(color: Colors.white54)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, indent: 70),
                            itemBuilder: (_, index) {
                              final item = items[index];
                              final name = (item['userName'] ?? 'Kullanıcı').toString();
                              final photo = (item['userPhotoUrl'] ?? '').toString();
                              final reaction = (item['reaction'] ?? '').toString();
                              final message = (item['message'] ?? '').toString();
                              final liked = item['liked'] == true;
                              return ListTile(
                                leading: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: ClipOval(
                                    child: FirebaseMediaImage(
                                      imageUrl: photo,
                                      fallbackStoragePaths:
                                          FirebaseMediaImage.avatarPaths(
                                              (item['userId'] ?? item['id'] ?? '')
                                                  .toString()),
                                      errorWidget: const ColoredBox(
                                        color: Color(0xFF22252A),
                                        child: Icon(Icons.person_outline),
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                subtitle: message.isEmpty
                                    ? null
                                    : Text(message,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (liked)
                                      const Icon(Icons.favorite_rounded,
                                          color: Colors.redAccent, size: 21),
                                    if (reaction.isNotEmpty) ...[
                                      const SizedBox(width: 7),
                                      Text(reaction,
                                          style: const TextStyle(fontSize: 21)),
                                    ],
                                  ],
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
      if (mounted) _restartTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.stories.length,
                onPageChanged: (value) {
                  setState(() => _index = value);
                  _replyController.clear();
                  _markViewed();
                  _restartTimer();
                },
                itemBuilder: (context, index) {
                  final story = widget.stories[index];
                  return FirebaseMediaImage(
                    imageUrl: story.imageUrl,
                    storagePath: story.storagePath,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain,
                    errorWidget: const Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 52, color: Colors.white38),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              left: 10,
              right: 10,
              child: Column(
                children: [
                  Row(
                    children: List.generate(
                      widget.stories.length,
                      (index) => Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: index <= _index ? Colors.white : Colors.white30,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: ClipOval(
                          child: FirebaseMediaImage(
                            imageUrl: current.userPhotoUrl,
                            fallbackStoragePaths:
                                FirebaseMediaImage.avatarPaths(current.userId),
                            errorWidget: const ColoredBox(
                              color: Color(0xFF22252A),
                              child: Icon(Icons.person_outline, size: 20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '${current.userName}  ${_time(current)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (_mine)
                        IconButton(
                          tooltip: 'Story’yi sil',
                          onPressed: () => _delete(current),
                          icon: const Icon(Icons.delete_outline_rounded),
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
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: _mine
                  ? StreamBuilder<List<Map<String, dynamic>>>(
                      stream: StoryService.instance.watchInteractions(current),
                      builder: (context, snapshot) {
                        final items = snapshot.data ?? const <Map<String, dynamic>>[];
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.tonalIcon(
                            onPressed: () => _showViewers(current),
                            icon: const Icon(Icons.visibility_outlined),
                            label: Text('${items.length} izleyen'),
                          ),
                        );
                      },
                    )
                  : StreamBuilder<Map<String, dynamic>>(
                      stream: StoryService.instance.watchMyInteraction(current.id),
                      builder: (context, snapshot) {
                        final interaction =
                            snapshot.data ?? const <String, dynamic>{};
                        final liked = interaction['liked'] == true;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: ['❤️', '🔥', '😍', '👏', '😂']
                                  .map(
                                    (emoji) => InkWell(
                                      onTap: () => _react(emoji),
                                      borderRadius: BorderRadius.circular(24),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 7),
                                        child: Text(emoji,
                                            style: const TextStyle(fontSize: 23)),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                IconButton.filledTonal(
                                  tooltip: liked ? 'Beğeniyi kaldır' : 'Beğen',
                                  onPressed: () => StoryService.instance
                                      .setLiked(current, !liked),
                                  icon: Icon(
                                    liked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: liked ? Colors.redAccent : Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _replyController,
                                    minLines: 1,
                                    maxLines: 3,
                                    maxLength: 500,
                                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                                    onTap: _pauseTimer,
                                    onSubmitted: (_) => _sendReply(),
                                    textInputAction: TextInputAction.send,
                                    decoration: InputDecoration(
                                      hintText: 'Story’ye mesaj yaz…',
                                      filled: true,
                                      fillColor: Colors.black54,
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: const BorderSide(
                                            color: Colors.white24),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: const BorderSide(
                                            color: Colors.white24),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  tooltip: 'Gönder',
                                  onPressed: _sending ? null : _sendReply,
                                  icon: _sending
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.send_rounded),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
