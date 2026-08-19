import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/social_service.dart';
import '../widgets/content_engagement_bar.dart';
import 'user_profile_screen.dart';

enum FeedMode { forYou, following }

class FeedScreen extends StatelessWidget {
  final FeedMode mode;
  final bool embedded;

  const FeedScreen({
    super.key,
    this.mode = FeedMode.forYou,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final body = currentUser == null
        ? const _SignedOutFeed()
        : StreamBuilder<List<String>>(
            stream: SocialService.instance.followingIds(),
            builder: (context, followingSnapshot) {
              if (followingSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final followingIds = followingSnapshot.data ?? <String>[];
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .orderBy('createdAt', descending: true)
                    .limit(120)
                    .snapshots(),
                builder: (context, postsSnapshot) {
                  if (postsSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (postsSnapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Text(
                          'Akış yüklenemedi.\n${postsSnapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  }

                  final docs = postsSnapshot.data?.docs.toList() ?? [];
                  if (mode == FeedMode.following) {
                    docs.removeWhere((doc) {
                      final owner = (doc.data()['userId'] ?? '').toString();
                      return owner != currentUser.uid &&
                          !followingIds.contains(owner);
                    });
                  } else {
                    docs.sort((a, b) {
                      final aOwner = (a.data()['userId'] ?? '').toString();
                      final bOwner = (b.data()['userId'] ?? '').toString();
                      final aFollowing = followingIds.contains(aOwner) ? 1 : 0;
                      final bFollowing = followingIds.contains(bOwner) ? 1 : 0;
                      if (aFollowing != bFollowing) {
                        return bFollowing.compareTo(aFollowing);
                      }
                      final aTime = a.data()['createdAt'];
                      final bTime = b.data()['createdAt'];
                      if (aTime is Timestamp && bTime is Timestamp) {
                        return bTime.compareTo(aTime);
                      }
                      return 0;
                    });
                  }

                  if (docs.isEmpty) {
                    return _EmptyFeed(mode: mode);
                  }

                  return RefreshIndicator(
                    onRefresh: () async =>
                        Future<void>.delayed(const Duration(milliseconds: 450)),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 34),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final ownerId = (data['userId'] ?? '').toString();
                        return _FeedPostCard(
                          postId: doc.id,
                          userId: ownerId,
                          userName:
                              (data['userName'] ?? 'Topluluk üyesi').toString(),
                          userPhotoUrl:
                              (data['userPhotoUrl'] ?? data['photoUrl'] ?? '')
                                  .toString(),
                          imageUrl: (data['imageUrl'] ?? '').toString(),
                          caption: (data['caption'] ?? '').toString(),
                          spotName: (data['spotName'] ?? '').toString(),
                          createdAt: data['createdAt'],
                        );
                      },
                    ),
                  );
                },
              );
            },
          );

    if (embedded) return body;
    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A0C),
        title: Text(mode == FeedMode.following ? 'Takip' : 'Sana Özel'),
      ),
      body: body,
    );
  }
}

class _SignedOutFeed extends StatelessWidget {
  const _SignedOutFeed();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dynamic_feed_outlined, size: 62, color: Colors.white38),
              SizedBox(height: 14),
              Text(
                'Sosyal akış için giriş yap',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 7),
              Text(
                'Takip ettiğin kişilerin fotoğraflarını, keşiflerini ve etkinlik anılarını burada göreceksin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, height: 1.4),
              ),
            ],
          ),
        ),
      );
}

class _EmptyFeed extends StatelessWidget {
  final FeedMode mode;
  const _EmptyFeed({required this.mode});

  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(30),
        children: [
          const SizedBox(height: 70),
          Icon(
            mode == FeedMode.following
                ? Icons.people_outline_rounded
                : Icons.photo_library_outlined,
            size: 66,
            color: Colors.white30,
          ),
          const SizedBox(height: 16),
          Text(
            mode == FeedMode.following
                ? 'Takip akışın henüz sakin'
                : 'Henüz paylaşım yok',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            mode == FeedMode.following
                ? 'Yeni insanları takip ettikçe onların paylaşımları burada görünür.'
                : 'İlk fotoğraf ve etkinlik anıları geldikçe burası canlanacak.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, height: 1.4),
          ),
        ],
      );
}

class _FeedPostCard extends StatelessWidget {
  final String postId;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String imageUrl;
  final String caption;
  final String spotName;
  final dynamic createdAt;

  const _FeedPostCard({
    required this.postId,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.imageUrl,
    required this.caption,
    required this.spotName,
    required this.createdAt,
  });

  String _timeLabel() {
    if (createdAt is! Timestamp) return '';
    final date = (createdAt as Timestamp).toDate();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${diff.inHours} sa';
    if (diff.inDays < 7) return '${diff.inDays} gün';
    return '${date.day}.${date.month}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 5, 10, 13),
      decoration: BoxDecoration(
        color: const Color(0xFF111315),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF24282D)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: userId.isEmpty
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(userId: userId),
                      ),
                    ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 8, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF22262A),
                    backgroundImage:
                        userPhotoUrl.isEmpty ? null : NetworkImage(userPhotoUrl),
                    child: userPhotoUrl.isEmpty
                        ? const Icon(Icons.person_outline, color: Colors.white60)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        Row(
                          children: [
                            if (spotName.isNotEmpty) ...[
                              const Icon(Icons.location_on_outlined,
                                  size: 13, color: Colors.white46),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  spotName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white54),
                                ),
                              ),
                              const Text('  •  ',
                                  style: TextStyle(color: Colors.white30)),
                            ],
                            Text(_timeLabel(),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white38)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.more_horiz_rounded, color: Colors.white38),
                ],
              ),
            ),
          ),
          if (imageUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 4 / 5,
              child: Image.network(
                imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF1A1D20),
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined,
                      color: Colors.white30, size: 52),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: ContentEngagementBar(
              collection: 'posts',
              contentId: postId,
              ownerId: userId,
              title: caption.trim().isEmpty ? 'Fotoğraf paylaşımı' : caption,
              sourceType: 'post',
            ),
          ),
          if (caption.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 8),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$userName ',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    TextSpan(
                      text: caption,
                      style: const TextStyle(color: Colors.white78, height: 1.35),
                    ),
                  ],
                ),
              ),
            ),
          if (spotName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF191C1F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 17, color: Color(0xFFB7BCC2)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        spotName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const Text('Noktayı gör',
                        style: TextStyle(
                            color: Color(0xFFB7BCC2),
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
