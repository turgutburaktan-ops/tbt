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
                        border: Border.all(color: const Color(0xFF090A0D), width: 2),
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
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 6), _next);
  }

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

  String _time(AppStory story) {
    final diff = DateTime.now().difference(story.createdAt);
    if (diff.inMinutes < 1) return 'şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    return '${diff.inHours.clamp(1, 24)} sa';
  }

  Future<void> _delete(AppStory story) async {
    _timer?.cancel();
    await StoryService.instance.deleteStory(story);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.stories[_index];
    final mine = current.userId == FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.stories.length,
              onPageChanged: (value) {
                setState(() => _index = value);
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
                            color: index <= _index
                                ? Colors.white
                                : Colors.white30,
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
                      if (mine)
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
          ],
        ),
      ),
    );
  }
}
