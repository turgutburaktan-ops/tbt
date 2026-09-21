import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/video_audio_session.dart';
import '../services/creator_service.dart';
import '../services/content_engagement_service.dart';
import '../services/post_service.dart';
import '../screens/reels_screen.dart';
import '../screens/user_profile_screen.dart';
import 'tbt_dialog.dart';
import 'like_burst.dart';
import 'app_video_player.dart';
import 'expandable_caption.dart';
import 'external_source_button.dart';
import 'post_sound_chip.dart';
import 'content_engagement_bar.dart';
import 'firebase_media_image.dart';
import 'post_media_carousel.dart';

class FeedPostCard extends StatefulWidget {
  final String postId,
      userId,
      userName,
      userPhotoUrl,
      mediaType,
      imageUrl,
      storagePath,
      videoUrl,
      videoStoragePath,
      thumbnailUrl,
      thumbnailStoragePath,
      caption,
      spotName;
  final String externalSourceUrl;
  final List<String> mediaUrls, mediaStoragePaths;
  final dynamic createdAt;
  const FeedPostCard({
    super.key,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.mediaType,
    required this.imageUrl,
    required this.storagePath,
    required this.mediaUrls,
    required this.mediaStoragePaths,
    required this.videoUrl,
    required this.videoStoragePath,
    required this.thumbnailUrl,
    required this.thumbnailStoragePath,
    this.externalSourceUrl = '',
    required this.caption,
    required this.spotName,
    required this.createdAt,
  });
  /// Shared mapping keeps Home and Discover compatible with legacy posts.
  factory FeedPostCard.fromPost({
    Key? key,
    required String postId,
    required Map<String, dynamic> data,
  }) {
    List<String> strings(dynamic value) => value is Iterable
        ? value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final storagePath = (data['storagePath'] ?? '').toString();
    final videoUrl = (data['videoUrl'] ?? '').toString();
    final urls = strings(data['mediaUrls']);
    final paths = strings(data['mediaStoragePaths']);
    return FeedPostCard(
      key: key,
      postId: postId,
      userId: (data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? 'Topluluk üyesi').toString(),
      userPhotoUrl: (data['userPhotoUrl'] ?? data['photoUrl'] ?? '').toString(),
      mediaType: data['mediaType'] == 'video' || videoUrl.isNotEmpty
          ? 'video' : 'image',
      imageUrl: imageUrl,
      storagePath: storagePath,
      mediaUrls: urls.isEmpty && imageUrl.isNotEmpty ? [imageUrl] : urls,
      mediaStoragePaths: paths.isEmpty && storagePath.isNotEmpty ? [storagePath] : paths,
      videoUrl: videoUrl,
      videoStoragePath: (data['videoStoragePath'] ?? '').toString(),
      thumbnailUrl: (data['thumbnailUrl'] ?? data['imageUrl'] ?? '').toString(),
      thumbnailStoragePath: (data['thumbnailStoragePath'] ?? data['storagePath'] ?? '').toString(),
      externalSourceUrl: (data['externalSourceUrl'] ?? '').toString(),
      caption: (data['caption'] ?? '').toString(),
      spotName: (data['spotName'] ?? '').toString(),
      createdAt: data['createdAt'],
    );
  }

  @override
  State<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<FeedPostCard> {
  bool _hidden = false;
  bool get _isVideo =>
      widget.mediaType == 'video' && widget.videoUrl.isNotEmpty;
  String _timeLabel() {
    if (widget.createdAt is! Timestamp) return '';
    final date = (widget.createdAt as Timestamp).toDate(),
        diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${diff.inHours} sa';
    if (diff.inDays < 7) return '${diff.inDays} gün';
    return '${date.day}.${date.month}.${date.year}';
  }

  void _profile() {
    CreatorService.instance.recordProfileVisit(widget.postId);
    if (widget.userId.isNotEmpty)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: widget.userId),
        ),
      );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _rawMedia() {
    if (_isVideo)
      return AppVideoPlayer.network(
        url: widget.videoUrl,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReelsScreen(
              initialPost: {
                'id': widget.postId,
                'userId': widget.userId,
                'userName': widget.userName,
                'userPhotoUrl': widget.userPhotoUrl,
                'videoUrl': widget.videoUrl,
                'caption': widget.caption,
                'mediaType': 'video',
              },
            ),
          ),
        ),
        autoplay: true,
        muted: false,
        audioSession: VideoAudioSession.feed,
        loop: true,
        showControls: true,
        fit: BoxFit.cover,
        loading: FirebaseMediaImage(
          imageUrl: widget.thumbnailUrl,
          storagePath: widget.thumbnailStoragePath,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    return PostMediaCarousel(
      imageUrls: widget.mediaUrls.isEmpty
          ? <String>[widget.imageUrl]
          : widget.mediaUrls,
      storagePaths: widget.mediaStoragePaths.isEmpty
          ? <String>[widget.storagePath]
          : widget.mediaStoragePaths,
      fallbackStoragePaths: FirebaseMediaImage.postPaths(
        widget.userId,
        widget.postId,
      ),
      fit: BoxFit.contain,
      onDoubleTap: null,
    );
  }

  Widget _media() => LikeBurst(onLike: _doubleTapLike, child: _rawMedia());
  Future<void> _doubleTapLike() async {
    if (widget.postId.trim().isEmpty) return;
    try {
      final liked = await ContentEngagementService.instance
          .isLiked('posts', widget.postId)
          .first;
      if (!liked)
        await ContentEngagementService.instance.toggleLike(
          collection: 'posts',
          likeOnly: true,
          id: widget.postId,
          ownerId: widget.userId,
          title: widget.caption.trim().isEmpty
              ? (_isVideo ? 'Video paylaşımı' : 'Fotoğraf paylaşımı')
              : widget.caption,
          sourceType: 'post',
        );
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showTbtDialog<bool>(
      context: context,
      builder: (c) => TbtDialog(
        title: const Text('Gönderiyi sil'),
        content: const Text('Bu gönderi kalıcı olarak silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted)
      await PostService.instance.deletePost(
        postId: widget.postId,
        storagePath: widget.storagePath,
        videoStoragePath: widget.videoStoragePath,
        thumbnailStoragePath: widget.thumbnailStoragePath,
      );
  }

  Future<void> _notInterested() async {
    setState(() => _hidden = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('feed_preferences')
          .doc(widget.postId)
          .set({
            'postId': widget.postId,
            'ownerId': widget.userId,
            'type': 'not_interested',
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (_) {}
    _message('Bu gönderiyi daha az göstereceğiz.');
  }

  Future<void> _mute() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.userId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('muted_accounts')
          .doc(widget.userId)
          .set({
            'userId': widget.userId,
            'createdAt': FieldValue.serverTimestamp(),
          });
      setState(() => _hidden = true);
      _message('${widget.userName} sessize alındı.');
    } catch (e) {
      _message('Hesap sessize alınamadı.');
    }
  }

  Future<void> _report() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Gönderiyi şikayet et',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            for (final r in const [
              'Spam',
              'Uygunsuz içerik',
              'Taciz veya zorbalık',
              'Yanıltıcı içerik',
              'Diğer',
            ])
              ListTile(title: Text(r), onTap: () => Navigator.pop(c, r)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'reporterId': uid,
        'targetType': 'post',
        'targetId': widget.postId,
        'targetOwnerId': widget.userId,
        'reason': reason,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _message('Şikayetin alındı. Teşekkürler.');
    } catch (e) {
      _message('Şikayet gönderilemedi.');
    }
  }

  Future<void> _otherMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('İlgilenmiyorum'),
              onTap: () => Navigator.pop(c, 'not_interested'),
            ),
            ListTile(
              leading: const Icon(Icons.volume_off_outlined),
              title: const Text('Bu hesabı sessize al'),
              onTap: () => Navigator.pop(c, 'mute'),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Şikayet et'),
              onTap: () => Navigator.pop(c, 'report'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'not_interested') await _notInterested();
    if (action == 'mute') await _mute();
    if (action == 'report') await _report();
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final mine = FirebaseAuth.instance.currentUser?.uid == widget.userId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 4, 7),
          child: Row(
            children: [
              InkWell(
                onTap: _profile,
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: ClipOval(
                    child: FirebaseMediaImage(
                      imageUrl: widget.userPhotoUrl,
                      fallbackStoragePaths: FirebaseMediaImage.avatarPaths(
                        widget.userId,
                      ),
                      errorWidget: const ColoredBox(
                        color: AppColors.surface,
                        child: Icon(Icons.person_outline),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: InkWell(
                  onTap: _profile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      if (widget.spotName.isNotEmpty || _timeLabel().isNotEmpty)
                        Text(
                          [
                            if (widget.spotName.isNotEmpty) widget.spotName,
                            if (_timeLabel().isNotEmpty) _timeLabel(),
                          ].join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Colors.white54,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              mine
                  ? PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'delete') _delete();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Gönderiyi sil'),
                        ),
                      ],
                      icon: const Icon(Icons.more_horiz_rounded),
                    )
                  : IconButton(
                      tooltip: 'Gönderi seçenekleri',
                      onPressed: _otherMenu,
                      icon: const Icon(Icons.more_horiz_rounded, size: 21),
                    ),
            ],
          ),
        ),
        AspectRatio(aspectRatio: 4 / 5, child: _media()),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
          child: ContentEngagementBar(
            collection: 'posts',
            contentId: widget.postId,
            ownerId: widget.userId,
            title: widget.caption.trim().isEmpty
                ? (_isVideo ? 'Video paylaşımı' : 'Fotoğraf paylaşımı')
                : widget.caption,
            sourceType: 'post',
          ),
        ),
        if (widget.mediaType == 'video') PostSoundChip(postId: widget.postId),
        ExternalSourceButton(url: widget.externalSourceUrl),
        if (widget.caption.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: ExpandableCaption(
              text: widget.caption,
              style: const TextStyle(color: Colors.white70, height: 1.3),
            ),
          ),
        const Divider(height: 1, color: Color(0x1FFFFFFF)),
        const SizedBox(height: 6),
      ],
    );
  }
}

