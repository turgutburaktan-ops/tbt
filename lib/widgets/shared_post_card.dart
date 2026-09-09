import 'creator_view_tracker.dart';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/creator_service.dart';
import '../screens/post_deep_link_screen.dart';
import '../screens/user_profile_screen.dart';
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
  });
  final String postId;
  final String? repostId;
  final String? storyId;
  final bool compact;
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

  void _unavailable() {
    _debounce?.cancel();
    if (mounted)
      setState(() {
        _version++;
        _post = null;
        _loading = false;
      });
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
      if (widget.repostId != null) _watch('post_reposts/${widget.repostId}');
      if (widget.storyId != null) _watch('stories/${widget.storyId}');
      setState(() {
        _post = post;
        _sharedBy = actor;
        _loading = false;
      });
    } catch (_) {
      if (mounted && version == _version)
        setState(() {
          _post = null;
          _loading = false;
        });
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
    return CreatorViewTracker(
      postId: widget.postId,
      child: Card(
        color: const Color(0xFF142238),
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
                  child: Text(
                    '${_sharedBy!['name']} yeniden paylaştı',
                    style: const TextStyle(
                      color: Color(0xFF9FC7FF),
                      fontSize: 12,
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
                  unawaited(
                    CreatorService.instance
                        .publishing('profileVisit', widget.postId)
                        .catchError((_) => <String, dynamic>{}),
                  );
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          UserProfileScreen(userId: post['userId'].toString()),
                    ),
                  );
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
                  child: Text(
                    '“${post['guideNote']}” — ${post['userName']}',
                    maxLines: widget.compact ? 3 : 8,
                    overflow: TextOverflow.ellipsis,
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
  }
}
