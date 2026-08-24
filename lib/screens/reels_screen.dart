import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/content_engagement_service.dart';
import '../services/social_service.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

class ReelsScreen extends StatefulWidget {
  final bool embedded;

  const ReelsScreen({super.key, this.embedded = false});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  int _activeIndex = 0;
  int _section = 0;

  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream => FirebaseFirestore
      .instance
      .collection('posts')
      .where('mediaType', isEqualTo: 'video')
      .limit(100)
      .snapshots();

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sorted(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    List<String> followingIds,
  ) {
    final docs = [...snapshot.docs];
    docs.sort((a, b) {
      final av = a.data()['createdAt'];
      final bv = b.data()['createdAt'];
      final at = av is Timestamp ? av.millisecondsSinceEpoch : 0;
      final bt = bv is Timestamp ? bv.millisecondsSinceEpoch : 0;
      return bt.compareTo(at);
    });
    return docs.where((doc) {
      final data = doc.data();
      final hasVideo =
          (data['videoUrl'] ?? '').toString().trim().isNotEmpty;
      if (!hasVideo) return false;
      if (_section == 0) return true;
      final ownerId = (data['userId'] ?? '').toString();
      final me = FirebaseAuth.instance.currentUser?.uid;
      return ownerId == me || followingIds.contains(ownerId);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<List<String>>(
      stream: SocialService.instance.followingIds(),
      builder: (context, followingSnapshot) {
        final followingIds = followingSnapshot.data ?? const <String>[];
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Reels şu anda yüklenemiyor.', style: TextStyle(color: Colors.white70)),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = _sorted(snapshot.data!, followingIds);
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.video_collection_outlined, size: 64, color: Colors.white38),
                    SizedBox(height: 14),
                    Text('Henüz Reels videosu yok', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text('Video paylaşıldığında burada tam ekran görünecek.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
            );
          }
          final safeIndex = _activeIndex.clamp(0, docs.length - 1).toInt();
          if (safeIndex != _activeIndex) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _activeIndex = safeIndex);
            });
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                scrollDirection: Axis.vertical,
                itemCount: docs.length,
                onPageChanged: (index) => setState(() => _activeIndex = index),
                itemBuilder: (_, index) {
                  final doc = docs[index];
                  return _ReelPage(
                    key: ValueKey(doc.id),
                    postId: doc.id,
                    data: doc.data(),
                    active: index == _activeIndex,
                  );
                },
              ),
              Positioned(
                top: widget.embedded ? 58 : 12,
                left: 0,
                right: 0,
                child: Center(
                  child: _ReelsFilter(
                    selected: _section,
                    onChanged: (value) {
                      setState(() {
                        _section = value;
                        _activeIndex = 0;
                      });
                    },
                  ),
                ),
              ),
            ],
          );
          },
        );
      },
    );

    if (widget.embedded) return ColoredBox(color: Colors.black, child: body);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title:
            const Text('Reels', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: body,
    );
  }
}

class _ReelsFilter extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _ReelsFilter({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(2, (index) {
            final active = selected == index;
            return InkWell(
              onTap: () => onChanged(index),
              borderRadius: BorderRadius.circular(99),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  index == 0 ? 'Sana Özel' : 'Takip',
                  style: TextStyle(
                    color: active ? Colors.black : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            );
          }),
        ),
      );
}

class _ReelPage extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> data;
  final bool active;

  const _ReelPage({
    super.key,
    required this.postId,
    required this.data,
    required this.active,
  });

  String get _videoUrl => (data['videoUrl'] ?? '').toString();
  String get _ownerId => (data['userId'] ?? '').toString();
  String get _userName => (data['userName'] ?? 'Kullanıcı').toString();
  String get _userPhoto => (data['userPhotoUrl'] ?? '').toString();
  String get _caption => (data['caption'] ?? '').toString();
  String get _spotName => (data['spotName'] ?? '').toString();

  Future<void> _openProfile(BuildContext context) async {
    if (_ownerId.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: _ownerId)),
    );
  }

  Future<void> _share(BuildContext context) async {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Göndermek için giriş yapmalısın.')),
      );
      return;
    }
    final selected = await showModalBottomSheet<Map<String, String>>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF111315),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * .55,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Row(
                children: [
                  Icon(Icons.send_outlined),
                  SizedBox(width: 9),
                  Text('Birine gönder', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ContentEngagementService.instance.users(),
                builder: (_, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final me = FirebaseAuth.instance.currentUser?.uid;
                  final users = snapshot.data!.docs.where((doc) => doc.id != me).toList();
                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (_, index) {
                      final doc = users[index];
                      final u = doc.data();
                      final name = (u['displayName'] ?? u['username'] ?? 'Kullanıcı').toString();
                      final photo = (u['photoUrl'] ?? '').toString();
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
                          child: photo.isEmpty ? const Icon(Icons.person_outline) : null,
                        ),
                        title: Text(name),
                        onTap: () => Navigator.pop(sheetContext, {'id': doc.id, 'name': name}),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    try {
      await ContentEngagementService.instance.shareToUser(
        targetUserId: selected['id'] ?? '',
        sourceType: 'post',
        sourceId: postId,
        title: _caption.trim().isEmpty ? 'Reels videosu' : _caption.trim(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${selected['name'] ?? 'Kullanıcı'} kullanıcısına gönderildi.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _ReelVideo(url: _videoUrl, active: active),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.transparent, Color(0xB3000000)],
                stops: [0, .56, 1],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 84,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _openProfile(context),
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: Colors.white12,
                        backgroundImage: _userPhoto.isEmpty ? null : NetworkImage(_userPhoto),
                        child: _userPhoto.isEmpty ? const Icon(Icons.person, size: 18) : null,
                      ),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(_userName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                      ),
                    ],
                  ),
                ),
              ),
              if (_caption.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_caption, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.35)),
              ],
              if (_spotName.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 17, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(child: Text(_spotName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12.5))),
                  ],
                ),
              ],
            ],
          ),
        ),
        Positioned(
          right: 10,
          bottom: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<bool>(
                stream: ContentEngagementService.instance.isLiked('posts', postId),
                builder: (_, likedSnap) => StreamBuilder<int>(
                  stream: ContentEngagementService.instance.likesCount('posts', postId),
                  builder: (_, countSnap) => _Action(
                    icon: likedSnap.data == true ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    label: '${countSnap.data ?? 0}',
                    active: likedSnap.data == true,
                    onTap: () async {
                      try {
                        await ContentEngagementService.instance.toggleLike(
                          collection: 'posts',
                          id: postId,
                          ownerId: _ownerId,
                          title: _caption.trim().isEmpty ? 'Reels videosu' : _caption.trim(),
                          sourceType: 'post',
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
                        }
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ContentEngagementService.instance.comments('posts', postId),
                builder: (_, snap) => _Action(
                  icon: Icons.mode_comment_outlined,
                  label: '${snap.data?.docs.length ?? 0}',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PostDetailScreen(post: {...data, 'id': postId})),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _Action(icon: Icons.send_outlined, label: 'Gönder', onTap: () => _share(context)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Action({required this.icon, required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Material(
            color: Colors.black45,
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: onTap,
              icon: Icon(icon, color: active ? const Color(0xFFFF4D67) : Colors.white, size: 27),
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      );
}

class _ReelVideo extends StatefulWidget {
  final String url;
  final bool active;

  const _ReelVideo({required this.url, required this.active});

  @override
  State<_ReelVideo> createState() => _ReelVideoState();
}

class _ReelVideoState extends State<_ReelVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant _ReelVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active && _ready) {
      if (widget.active) {
        _controller?.play();
      } else {
        _controller?.pause();
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _init() async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1);
      if (widget.active) await controller.play();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c == null || !_ready) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleMute() async {
    final c = _controller;
    if (c == null || !_ready) return;
    _muted = !_muted;
    await c.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const ColoredBox(color: Colors.black, child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48)));
    if (!_ready || _controller == null) return const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator()));
    final size = _controller!.value.size;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(_controller!)),
          ),
          if (!_controller!.value.isPlaying)
            const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: Padding(padding: EdgeInsets.all(12), child: Icon(Icons.play_arrow_rounded, size: 42)),
              ),
            ),
          Positioned(
            top: 12,
            right: 12,
            child: IconButton.filledTonal(
              onPressed: _toggleMute,
              icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
