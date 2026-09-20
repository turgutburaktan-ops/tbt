import '../theme/app_theme.dart';
import 'content_engagement_bar.dart';
import 'profile_name_link.dart';
import 'shared_story_video.dart';
import 'creator_view_tracker.dart';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/creator_service.dart';
import '../screens/post_deep_link_screen.dart';
import '../screens/user_profile_screen.dart';
import 'package:video_player/video_player.dart';
import 'firebase_media_image.dart';

/// Reference-only rendering: live source/account/block changes invalidate the card.
class SharedPostCard extends StatefulWidget {
  const SharedPostCard({
    super.key,
    required this.postId,
    this.repostId,
    this.storyId,
    this.compact = false,
    this.onOpen,
    this.storyPresentation = false,
    this.active = true,
    this.note = '',
    this.onStoryReady,
    this.onStoryPlayback,
    this.onProfileOpening,
    this.onProfileReturned,
  });
  final String postId;
  final String? repostId;
  final String? storyId;
  final bool compact;
  final bool storyPresentation, active;
  final String note;
  final ValueChanged<Duration>? onStoryReady;
  final ValueChanged<VideoPlayerValue>? onStoryPlayback;
  final VoidCallback? onProfileOpening, onProfileReturned;
  final Future<void> Function()? onOpen;
  @override
  State<SharedPostCard> createState() => _SharedPostCardState();
}

class _SharedPostCardState extends State<SharedPostCard> {
  final _subscriptions = <StreamSubscription>[];
  final _watched = <String>{};
  Map<String, dynamic>? _post;
  Map<String, dynamic>? _sharedBy;
  bool _loading = true;
  int _version = 0;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    _watch('posts/${widget.postId}');
  }

  @override
  void didUpdateWidget(covariant SharedPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId ||
        oldWidget.repostId != widget.repostId ||
        oldWidget.storyId != widget.storyId) {
      _version++;
      _debounce?.cancel();
      for (final sub in _subscriptions) {
        sub.cancel();
      }
      _subscriptions.clear();
      _watched.clear();
      _post = null;
      _sharedBy = null;
      _loading = true;
      _watch('posts/${widget.postId}');
    }
  }

  void _watch(String path) {
    if (!_watched.add(path)) return;
    _subscriptions.add(
      FirebaseFirestore.instance
          .doc(path)
          .snapshots()
          .listen((_) => _invalidate(), onError: (_) => _unavailable()),
    );
  }

  void _storyReady([Duration duration = const Duration(seconds: 7)]) {
    if (widget.storyPresentation) widget.onStoryReady?.call(duration);
  }

  void _unavailable() {
    _debounce?.cancel();
    if (mounted)
      setState(() {
        _version++;
        _post = null;
        _loading = false;
      });
    _storyReady();
  }

  void _invalidate() {
    if (!mounted) return;
    setState(() {
      _version++;
      _post = null;
      _loading = true;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 80), _load);
  }

  Future<void> _load() async {
    final version = _version;
    try {
      final result = await CreatorService.instance.publishing(
        'resolve',
        widget.postId,
        {
          if (widget.repostId != null) 'repostId': widget.repostId,
          if (widget.storyId != null) 'storyId': widget.storyId,
        },
      );
      if (!mounted || version != _version) return;
      final post = Map<String, dynamic>.from(result['post'] as Map);
      final actor = result['sharedBy'] is Map
          ? Map<String, dynamic>.from(result['sharedBy'] as Map)
          : null;
      if (actor != null) {
        try {
          final profile = await FirebaseFirestore.instance
              .doc('users/${actor['userId']}')
              .get();
          actor['photoUrl'] = profile.data()?['photoUrl'] ?? '';
        } catch (_) {}
        if (!mounted || version != _version) return;
      }
      final me = FirebaseAuth.instance.currentUser?.uid;
      final owners = <String>{
        post['userId'].toString(),
        if (actor != null) actor['userId'].toString(),
      };
      for (final owner in owners) {
        _watch('users/$owner');
        if (me != null && me != owner) {
          _watch('users/$me/blocked/$owner');
          _watch('users/$owner/blocked/$me');
        }
      }
      if (actor != null &&
          actor['userId'] != post['userId'] &&
          me == actor['userId'])
        _watch('users/${actor['userId']}/blocked/${post['userId']}');
      if (post['mediaType'] == 'route')
        _watch('travel_plans/${post['travelPlanId']}');
      if ((post['eventId'] ?? '').toString().isNotEmpty)
        _watch('social_events/${post['eventId']}');
      if (widget.storyId != null && me == actor?['userId'])
        _watch('users/$me/story_archive/${widget.storyId}');
      if (widget.repostId != null) _watch('post_reposts/${widget.repostId}');
      if (widget.storyId != null) _watch('stories/${widget.storyId}');
      setState(() {
        _post = post;
        _sharedBy = actor;
        _loading = false;
      });
      if ((post['videoUrl'] ?? '').toString().isEmpty) _storyReady();
    } catch (_) {
      if (mounted && version == _version)
        setState(() {
          _post = null;
          _loading = false;
        });
      if (mounted && version == _version) _storyReady();
    }
  }

  Future<void> _open() async {
    if (_post == null) return;
    if (widget.onOpen != null) {
      await widget.onOpen!();
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDeepLinkScreen(
          postId: widget.postId,
          repostId: widget.repostId,
          storyId: widget.storyId,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _version++;
    _debounce?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  Widget _avatar(String url, double size) => ClipOval(
    child: SizedBox(
      width: size,
      height: size,
      child: url.isEmpty
          ? const ColoredBox(
              color: AppColors.surfaceAlt,
              child: Icon(
                Icons.person_outline,
                color: AppColors.textMuted,
                size: 18,
              ),
            )
          : FirebaseMediaImage(imageUrl: url, fit: BoxFit.cover),
    ),
  );

  Widget _repost(Map<String, dynamic> post) {
    final actor = _sharedBy;
    final caption = (post['caption'] ?? '').toString().trim();
    final image = (post['imageUrl'] ?? '').toString();
    final video = (post['videoUrl'] ?? '').toString().isNotEmpty;
    return CreatorViewTracker(
      postId: widget.postId,
      child: Material(
        color: AppColors.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (actor != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: ProfileNameLink(
                  userId: (actor['userId'] ?? '').toString(),
                  compact: true,
                  onOpening: widget.onProfileOpening,
                  onReturned: widget.onProfileReturned,
                  child: Row(
                    children: [
                      _avatar((actor['photoUrl'] ?? '').toString(), 22),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.repeat_rounded,
                        size: 17,
                        color: AppColors.blue,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${actor['name']} yeniden paylaştı',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (widget.note.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(widget.note.trim()),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ProfileNameLink(
                userId: (post['userId'] ?? '').toString(),
                compact: true,
                onOpening: widget.onProfileOpening,
                onReturned: widget.onProfileReturned,
                child: Row(
                  children: [
                    _avatar((post['userPhotoUrl'] ?? '').toString(), 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (post['userName'] ?? '').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: _open,
              child: image.isNotEmpty
                  ? ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * .65,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          FirebaseMediaImage(
                            imageUrl: image,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                          if (video)
                            const Icon(
                              Icons.play_circle_fill_rounded,
                              size: 56,
                              color: Colors.white,
                            ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            video
                                ? Icons.play_circle_outline
                                : Icons.route_rounded,
                            color: AppColors.blue,
                            size: 42,
                          ),
                          const SizedBox(height: 8),
                          Text((post['title'] ?? 'Gönderiyi aç').toString()),
                        ],
                      ),
                    ),
            ),
            if (caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  caption,
                  maxLines: widget.compact ? 3 : 8,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if ((post['guideNote'] ?? '').toString().trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(post['guideNote'].toString()),
              ),
            ContentEngagementBar(
              collection: 'posts',
              contentId: widget.postId,
              ownerId: (post['userId'] ?? '').toString(),
              title: (post['title'] ?? '').toString(),
              sourceType: 'post',
            ),
            const Divider(height: 1, color: AppColors.border),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    if (post == null)
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  'Bu gönderi artık kullanılamıyor.',
                  style: TextStyle(color: Colors.white60),
                ),
        ),
      );
    if (widget.repostId != null && !widget.storyPresentation)
      return _repost(post);
    final videoUrl = (post['videoUrl'] ?? '').toString();
    if (widget.storyPresentation && videoUrl.isNotEmpty) {
      return CreatorViewTracker(
        postId: widget.postId,
        child: SharedStoryVideo(
          url: videoUrl,
          author: (post['userName'] ?? '').toString(),
          authorId: (post['userId'] ?? '').toString(),
          onProfileOpening: widget.onProfileOpening,
          onProfileReturned: widget.onProfileReturned,
          note: widget.note,
          active: widget.active,
          onPlayback: widget.onStoryPlayback,
        ),
      );
    }
    final card = CreatorViewTracker(
      postId: widget.postId,
      child: Card(
        color: AppColors.surfaceAlt,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _open,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.repostId != null && _sharedBy != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: ProfileNameLink(
                    userId: (_sharedBy!['userId'] ?? '').toString(),
                    compact: true,
                    onOpening: widget.onProfileOpening,
                    onReturned: widget.onProfileReturned,
                    child: Text(
                      '${_sharedBy!['name']} yeniden paylaştı',
                      style: const TextStyle(
                        color: Color(0xFF9FC7FF),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.person_outline),
                title: Text(
                  post['userName'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: const Text('Asıl gönderi'),
                onTap: () async {
                  widget.onProfileOpening?.call();
                  try {
                    unawaited(
                      CreatorService.instance
                          .publishing('profileVisit', widget.postId)
                          .catchError((_) => <String, dynamic>{}),
                    );
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(
                          userId: post['userId'].toString(),
                        ),
                      ),
                    );
                  } finally {
                    if (mounted) widget.onProfileReturned?.call();
                  }
                },
              ),
              if ((post['imageUrl'] ?? '').toString().isNotEmpty)
                AspectRatio(
                  aspectRatio: widget.compact ? 1.8 : 1.25,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FirebaseMediaImage(
                        imageUrl: post['imageUrl'].toString(),
                        fit: BoxFit.cover,
                      ),
                      if (post['mediaType'] == 'video')
                        const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            size: 52,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                )
              else if (post['mediaType'] == 'route')
                const Padding(
                  padding: EdgeInsets.all(22),
                  child: Icon(
                    Icons.route_rounded,
                    size: 42,
                    color: Color(0xFF9FC7FF),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  post['title'].toString(),
                  maxLines: widget.compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if ((post['guideNote'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: ProfileNameLink(
                    userId: (post['userId'] ?? '').toString(),
                    compact: true,
                    onOpening: widget.onProfileOpening,
                    onReturned: widget.onProfileReturned,
                    child: Text(
                      '“${post['guideNote']}” — ${post['userName']}',
                      maxLines: widget.compact ? 3 : 8,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Text(
                  'Gönderiyi aç',
                  style: TextStyle(
                    color: Color(0xFF9FC7FF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return widget.storyPresentation
        ? Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 140, 22, 140),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  card,
                  if (widget.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Text(widget.note, textAlign: TextAlign.center),
                    ),
                ],
              ),
            ),
          )
        : card;
  }
}
